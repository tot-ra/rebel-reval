# Agent work requests

This directory is the non-blocking inbox between specialist discovery and Producer planning. It prevents idle specialists from inventing executable scope or waiting for direct assignment.

- Every specialist may create a uniquely named card from `TEMPLATE.md` after a bounded current-slice audit.
- A specialist creates no more cards while two of its `status: open` cards remain untriaged.
- Requests are evidence-backed proposals, not permission to implement.
- The Producer is the only role that changes `status`, fills `## Producer decision`, and creates or re-scopes the corresponding `TODO.md` row. Triage atomically changes `open` to the matching terminal status: `accepted`, `rejected`, or `merged`.
- Before accepting a request, the Producer searches both this directory and `TODO.md` for duplicate deliverables and overlapping allowed paths.
- Keep accepted and rejected cards as decision history through the current milestone; archive older cards only during Producer reconciliation.

See [`agents/WORK_PROTOCOL.md`](../../../agents/WORK_PROTOCOL.md) and [`docs/AGENT_LOOPS.md`](../../AGENT_LOOPS.md).
