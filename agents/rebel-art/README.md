# Rebel Art runtime

`rebel-art` stays Docker-isolated but uses a specialized Brute-derived image with
Blender, Blender's Python runtime, NumPy, and Pillow. This supports the existing
deterministic generators and `tools/verify_asset_lint.py` without granting the
agent general access to the macOS host.

## Build

Build the base Brute image first, then the art image:

```bash
cd ~/git/a2gent/brute
docker build -t a2gent-brute:latest .

cd /path/to/rebel-reval
agents/rebel-art/build-image.sh
```

The definition references `a2gent-rebel-art:blender-4.3`. Re-import or save the
definition after changing the image so Brute removes its previous warm container.
The next start/delegation creates a new container from the art image.

## Verify

```bash
docker run --rm --entrypoint sh a2gent-rebel-art:blender-4.3 -lc \
  'blender --version | head -1; python3 --version; python3 -c "import numpy, PIL"'
```

For an end-to-end project check, start `rebel-art` from Caesar and ask it to run:

```bash
blender --background --factory-startup --python-expr \
  'import bpy; print("BLENDER_OK", bpy.app.version_string)' --log-level 0
python3 tools/verify_asset_lint.py
```

## Why not host runtime?

Reusable definitions intentionally run in Docker so workspace mounts, credentials,
networking, and resource limits remain explicit. A general host runtime would make
`workspace.mount: ro` unenforceable for shell-capable agents and would allow an
imported definition to execute with the full permissions of the Brute process.
Native desktop capabilities should be exposed through narrowly scoped host tools
or integrations instead. The Blender integration can coexist with this image and
provide a higher-level API, while the image remains the deterministic fallback for
repository Blender scripts.
