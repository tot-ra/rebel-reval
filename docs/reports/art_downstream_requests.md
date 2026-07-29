# Art downstream requests (legacy redirect)

This shared table is retired. It could serialize unrelated Art discoveries into one hot file and did
not provide the context needed for safe Producer triage.

Create each new cross-role discovery as a unique card under [`work_requests/`](./work_requests/) using
[`work_requests/TEMPLATE.md`](./work_requests/TEMPLATE.md). The Producer records acceptance, rejection,
or deduplication on that card. Existing links may continue to point here during migration, but no new
requests belong in this file.

See [`agents/WORK_PROTOCOL.md`](../../agents/WORK_PROTOCOL.md) and the
[Art work loop](../../agents/rebel-art/skills/work-loop/SKILL.md).
