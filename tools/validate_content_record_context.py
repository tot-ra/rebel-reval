"""Shared context for per-record content validation."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from validate_content_common import (
    Diagnostic,
    check_local_duplicates,
    diag,
    local_ids,
    require_record_ref,
)

Record = dict[str, Any]
RecordIndex = dict[str, tuple[str, Path, Record]]


@dataclass(frozen=True)
class RecordValidationContext:
    """Bundle the corpus state and common operations used by record validators."""

    diagnostics: list[Diagnostic]
    path: Path
    record: Record
    index: RecordIndex
    project_root: Path
    root: Path

    def diagnose(self, code: str, pointer: str, message: str) -> None:
        self.diagnostics.append(diag(code, self.path, pointer, message, root=self.root))

    def require_ref(self, pointer: str, content_id: Any, expected_type: str) -> None:
        require_record_ref(
            self.diagnostics,
            path=self.path,
            pointer=pointer,
            content_id=content_id,
            expected_type=expected_type,
            index=self.index,
            root=self.root,
        )

    def require_field_ref(self, field: str, expected_type: str) -> None:
        self.require_ref(f"$.{field}", self.record.get(field), expected_type)

    def check_duplicates(self, pointer: str, ids: list[str]) -> None:
        check_local_duplicates(
            self.diagnostics,
            path=self.path,
            pointer=pointer,
            ids=ids,
            root=self.root,
        )

    def check_record_duplicates(self, field: str) -> None:
        self.check_duplicates(f"$.{field}", local_ids(self.record.get(field)))
