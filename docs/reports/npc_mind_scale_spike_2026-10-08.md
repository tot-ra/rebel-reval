# NPC mind: scale benchmark and local-LLM research (spike)

Date: 2026-10-08. Feeds [ADR 0036](../adr/0036-layered-npc-mind-with-local-llm.md) (proposed) and [`SYSTEMS/NPC_MIND.md`](../SYSTEMS/NPC_MIND.md). Status: evidence only; no runtime code changed.

## What was run

| Check | Command | Result |
|---|---|---|
| Layer 0/1 scale spike (GDScript, Godot 4.7.1, headless, one thread, 4-core cloud VM) | `godot --headless --path . --script tools/benchmarks/npc_mind_scale_benchmark.gd -- --sizes=4247,20000,100000` | numbers below; 3 self-checks pass |
| LLM latency harness | `python3 tools/benchmarks/llm_npc_latency.py --url http://127.0.0.1:8080` | **not run against a model** (see Gaps); harness unit-tested with a mock server |
| Harness tests | `python3 -m unittest tests.python.test_llm_npc_latency -v` | 9 tests OK |

Numbers are host-specific. Use ratios and budgets; re-run on the minimum-hardware profile before deciding.

## Layer 0/1 results

The spike models the *abstract tier* of ADR 0036: a packed struct-of-arrays store, a 1,440-slot minute timing wheel for state-change events, a 128 m grid for perception, and a utility scorer (16 goals x 5 considerations) run on about 1 event in 16. Positions jump to the leg's place; real route interpolation is not modelled.

| Residents | Manager tick, 24-min game day at 60 Hz (mean / p99 / max) | Max events in one game minute | Fast-forward day, 1 h per s (mean / max per step) | 8 h catch-up of everyone | Alarm query (60 m) | Save: overrides only vs full rows |
|---:|---|---:|---|---:|---:|---|
| 4,247 | 0.002 / 0.078 / 0.335 ms | 52 | 0.092 / 0.259 ms | 45 ms | 18 us | 17 KB vs 85 KB |
| 20,000 | 0.007 / 0.394 / 0.944 ms | 201 | 0.438 / 0.959 ms | 219 ms | 63 us | 80 KB vs 400 KB |
| 100,000 | 0.039 / 2.148 / 5.391 ms | 874 | 2.35 / 4.99 ms | 1,088 ms | 284 us | 400 KB vs 2 MB |

Other figures:

- Utility decision: 20.7 us in GDScript. The live tier (30 NPCs at 1 Hz) costs 0.62 ms per second of play, but 30 decisions in one frame is 0.6 ms, so stagger them.
- Promotion/demotion (copy a row to and from an actor record): 0.6 us.
- Row memory: 0.11 MB at 4,247; 2.7 MB at 100,000.
- Naive baseline, one script object per resident updated every frame with a trivial state machine: **0.75 ms per frame at 4,247 residents.** Real steering and animation would cost several times that. The abstract tier at the same size has a mean of 0.002 ms.
- Self-checks: batch catch-up equals minute-by-minute stepping; every resident is in exactly one wheel bucket and one grid cell.

### Reading

- At the current census (4,247) and at 20,000, the abstract tier is far below a 1 ms budget. The design holds for this city plus a large hinterland.
- Spikes come from many events in one minute (church bells, curfew). At 100,000 the worst minute costs 5 ms, so the manager needs a per-frame event budget that carries overflow to the next frame. Not needed at 20,000.
- **Catch-up is the expensive operation** (219 ms at 20,000 for 8 h). Wake dormant groups region by region, spread over frames or on a worker thread, never all at once.
- The grid is updated only at events, so perception sees a resident's last event position, not the mid-route one. Acceptable for alarms and rumours; the live tier uses true positions.
- Deviations from the plan (the override store) keep saves at about 17 KB for 4,247 residents.

## Local-LLM research (secondary sources unless marked)

Full agent report summarised; re-verify licences and sizes on primary pages before choosing.

- **Embedding.** NobodyWho (EUPL-1.2, commercial use free, Godot 4.5+, Metal and Vulkan, grammar support, 12.0.0 on 5 Oct was a breaking rewrite, so pin versions); godot-llm (MIT, GBNF and JSON-schema output, maintenance unclear); own thin llama.cpp GDExtension (most control, build and notarisation work on us); sidecar `llama-server` (crash isolation, but a second signed binary and a localhost port). Godot 4.7 compatibility is **unverified for all of them**.
- **Constrained output.** llama.cpp supports GBNF and JSON-schema-to-grammar, so replies can be limited to our closed vocabulary. This is also the strongest guardrail story for the Steam live-generated disclosure.
- **Models.** Prefer Apache-2.0 or MIT: Qwen3 small sizes (Qwen3-1.7B Q4_K_M about 1.3 GB, licence per a GGUF mirror tag, upstream card not retrieved), Phi-3.5-mini (MIT, about 2.2 GB). Llama 3.2 and Gemma add pass-through obligations (notice file, acceptable-use policy, enforceable downstream terms) that the game EULA must carry. Avoid Qwen2.5-3B (research licence).
- **Speed.** No primary or x86 numbers found. Community figures: Llama 3.2 3B Q4_K_M about 41 tok/s on a base M4 Mac mini; about 20 tok/s for a 3B Q4 on a DDR4 laptop. Time to first token matters more than tokens per second for short replies.
- **Games.** inZOI "Smart Zoi" (small on-device model, RTX-only) drew complaints from excluded players; Mantella (Skyrim) notes noticeable latency and stuck multi-NPC scenes; Whispers from the Star is cloud-based. Lesson: do not tie the feature to one GPU vendor, keep it optional, keep multi-NPC scenes off the LLM path.
- **Architecture references.** Unreal Mass separates representation, simulation and replication LOD; Radiant AI used schedules, with known odd-behaviour cases; Kenshi simulates only near the player; utility AI (Dave Mark, IAUS, GDC 2015) scales to large casts; F.E.A.R. used a tiny FSM with an A* planner (good for a few NPCs, costly for thousands). This matches the layered design.

## Gaps (not measured)

1. **No model latency or memory numbers.** The sandbox cannot reach Hugging Face (HTTP 403 from the proxy), so no GGUF file could be obtained. Run `llm_npc_latency.py` on the target machines (see Next steps).
2. No Godot 4.7 compatibility test of any LLM addon.
3. The spike is a toy for the abstract tier: no real routes, no live-tier steering, no worker thread, no Steam-disclosure review. A GDScript implementation may be slower than a native one; a native core is an option if 100,000-scale ever matters.
4. Scale figures assume the timetable-shaped workload of the current census, not combat or crowd panic.

## Next steps

1. Pick a model and runtime and run on the minimum-spec Windows, Linux, Intel Mac and Apple Silicon machines:
   `llama-server -m <pinned.gguf> --port 8080 -c 2048` then
   `python3 tools/benchmarks/llm_npc_latency.py --url http://127.0.0.1:8080 --runs 30 --out build/benchmarks/llm_npc_latency.json`.
   Acceptance (proposed): median full reply within 2.5 s, valid-reply rate at or above 0.99, resident memory under an agreed cap. Thresholds are proposals for the maintainer to set.
2. If the maintainer wants this environment to run it, allow `huggingface.co` in the environment network policy (see Claude Code on the web settings) and a model file can be fetched.
3. Turn the ADR into an implementation spec (options in the PR discussion), then file phase 0.
