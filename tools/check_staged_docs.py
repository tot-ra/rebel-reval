#!/usr/bin/env python3
"""Run documentation gates against the staged Git tree, not local worktree noise."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
DOC_TOOLS = {
    "active": (
        "tools/generate_active_docs_report.py",
        "tools/active_docs_report_common.py",
        "tools/active_docs_report_checks.py",
        "tools/active_docs_report_links.py",
        "tools/active_docs_report_fixtures.py",
    ),
    "index": ("tools/docs_index.py",),
}
MARKDOWN_LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HTML_LINK_RE = re.compile(r"<(?:a|img)\b[^>]*(?:href|src)=[\"']([^\"']+)[\"']", re.IGNORECASE)
GIT_ENV_KEYS = (
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_COMMON_DIR", "GIT_PREFIX",
)


def clean_git_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in GIT_ENV_KEYS:
        env.pop(key, None)
    return env


def run(command: list[str], *, cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=cwd, check=True, capture_output=True, env=env)


def linked_asset_paths(
    markdown: list[str], root: Path, tree: str, indexed_paths: set[str], head_paths: set[str]
) -> tuple[set[str], set[str]]:
    """Return referenced paths that need placeholders in the staged snapshot."""
    files: set[str] = set()
    directories: set[str] = set()
    for rel_path in markdown:
        text = run(["git", "show", f"{tree}:{rel_path}"], cwd=root).stdout.decode("utf-8", errors="replace")
        source = root / rel_path
        for line in text.splitlines():
            for destination in (*MARKDOWN_LINK_RE.findall(line), *HTML_LINK_RE.findall(line)):
                parsed = urlparse(destination)
                if parsed.scheme or parsed.netloc:
                    continue
                linked = unquote(parsed.path)
                if not linked:
                    continue
                target = (source.parent / linked).resolve() if not linked.startswith("/") else root / linked.lstrip("/")
                try:
                    rel_target = target.relative_to(root).as_posix()
                except ValueError:
                    continue
                # Materialize every staged local target from the index view,
                # even if the worktree file has been removed or modified.
                if rel_target in indexed_paths:
                    if target.suffix.lower() != ".md":
                        files.add(rel_target)
                elif any(path.startswith(rel_target + "/") for path in indexed_paths):
                    directories.add(rel_target)
                # Existing ignored evidence assets remain valid link targets,
                # but worktree-only files never override a staged deletion.
                elif (
                    target.exists()
                    and rel_target not in head_paths
                    and target.suffix.lower() not in {".md", ".py"}
                ):
                    if target.is_dir():
                        directories.add(rel_target)
                    else:
                        files.add(rel_target)
    return files, directories


def check_in_staged_tree(checks: list[str], root: Path) -> int:
    """Materialize the index's Markdown and validators in an isolated temp repo.

    Reading blobs by tree ID means staged content wins over unstaged edits and
    untracked Markdown never enters either documentation gate.
    """
    tree = run(["git", "write-tree"], cwd=root).stdout.decode("ascii").strip()
    paths = run(["git", "ls-tree", "-r", "--name-only", "-z", tree], cwd=root)
    indexed_paths = {os.fsdecode(path) for path in paths.stdout.split(b"\0") if path}
    docs = sorted(path for path in indexed_paths if path.endswith(".md"))
    required_tools = sorted({path for check in checks for path in DOC_TOOLS[check]})
    missing = sorted(set(required_tools) - indexed_paths)
    if missing:
        raise RuntimeError("documentation validator source missing from index: " + ", ".join(missing))
    head_result = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", "-z", "HEAD"],
        cwd=root,
        capture_output=True,
        check=False,
    )
    head_paths = {
        os.fsdecode(path)
        for path in head_result.stdout.split(b"\0")
        if path
    } if head_result.returncode == 0 else set()
    asset_files, asset_directories = linked_asset_paths(docs, root, tree, indexed_paths, head_paths)
    snapshot_env = clean_git_env()
    snapshot_env.pop("GIT_INDEX_FILE", None)

    with tempfile.TemporaryDirectory(prefix="rebel-staged-docs-") as temp_dir:
        snapshot = Path(temp_dir)
        for rel_path in docs + required_tools:
            destination = snapshot / rel_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(run(["git", "show", f"{tree}:{rel_path}"], cwd=root).stdout)
        for rel_path in sorted(asset_directories):
            (snapshot / rel_path).mkdir(parents=True, exist_ok=True)
        for rel_path in sorted(asset_files):
            target = snapshot / rel_path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.touch()

        run(["git", "init", "-q"], cwd=snapshot, env=snapshot_env)
        # The validators use git ls-files to discover docs; populate this
        # temporary index from staged snapshots, never from the live checkout.
        run(["git", "add", "--all", "--", "*.md"], cwd=snapshot, env=snapshot_env)

        result = 0
        for check in checks:
            script = "generate_active_docs_report.py" if check == "active" else "docs_index.py"
            completed = subprocess.run(
                [sys.executable, f"tools/{script}", "--check"],
                cwd=snapshot,
                env=snapshot_env,
                check=False,
                text=True,
                capture_output=True,
            )
            print(f"==> staged {check} documentation check")
            if completed.stdout:
                print(completed.stdout, end="")
            if completed.stderr:
                print(completed.stderr, end="", file=sys.stderr)
            if completed.returncode:
                result = completed.returncode
        return result


def check_worktree(checks: list[str], root: Path) -> int:
    """Retain the explicit `all` mode's historical live-tree semantics."""
    result = 0
    for check in checks:
        script = "generate_active_docs_report.py" if check == "active" else "docs_index.py"
        completed = subprocess.run(
            [sys.executable, f"tools/{script}", "--check"],
            cwd=root,
            check=False,
        )
        if completed.returncode:
            result = completed.returncode
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worktree", action="store_true", help="check the live worktree (for all mode)")
    parser.add_argument("--root", type=Path, default=ROOT, help=argparse.SUPPRESS)
    parser.add_argument("checks", nargs="+", choices=("active", "index"))
    args = parser.parse_args()
    try:
        if args.worktree:
            return check_worktree(args.checks, args.root)
        return check_in_staged_tree(args.checks, args.root)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Staged documentation check could not read the Git index: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
