godot --headless --editor --quit
godot --headless --check-only
mkdir -p build && godot --headless --export-release "rr" build/rr.dmg
python3 tools/generate_active_docs_report.py
python3 tools/generate_active_docs_report.py --check
godot --headless -s tools/verify_transitions.gd
godot --headless --path . --script tools/validate_map_blueprints.gd

# Compact/chunked map production gates (run individually or use `all`).
tools/run_map_pipeline_ci.sh parser
tools/run_map_pipeline_ci.sh compiler
tools/run_map_pipeline_ci.sh audit
tools/run_map_pipeline_ci.sh persistence
tools/run_map_pipeline_ci.sh parity
tools/run_map_pipeline_ci.sh routes
tools/run_map_pipeline_ci.sh benchmark-smoke
