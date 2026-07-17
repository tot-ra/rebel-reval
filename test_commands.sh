godot --headless --editor --quit
godot --headless --check-only
mkdir -p build && godot --headless --export-release "rr" build/rr.dmg
python3 tools/generate_active_docs_report.py
python3 tools/generate_active_docs_report.py --check
godot --headless -s tools/verify_transitions.gd
godot --headless --path . --script tools/validate_map_blueprints.gd
