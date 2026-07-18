import json
import re
import sys
from pathlib import Path

RELEASE_SCENE_IDS = frozenset({"forge", "reval_east"})
RETIRED_SCENE_IDS = frozenset({"harbor_warehouse"})
ARCHIVE_GDIGNORE_PATHS = (
    "scenes/map/.gdignore",
)

def parse_catalog(catalog_path):
    catalog = {}
    try:
        with open(catalog_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        return catalog
        
    maps_block = re.search(r'const MAPS:\s*Dictionary\s*=\s*\{(.*)\}', content, re.DOTALL)
    if not maps_block:
        return catalog
        
    entries = re.finditer(r'"([^"]+)"\s*:\s*\{([^}]*)\}', maps_block.group(1))
    for entry in entries:
        map_id = entry.group(1)
        props_block = entry.group(2)
        
        path_match = re.search(r'"path"\s*:\s*"([^"]+)"', props_block)
        scope_match = re.search(r'"scope"\s*:\s*"([^"]+)"', props_block)
        active_match = re.search(r'"active"\s*:\s*(true|false)', props_block)
        
        if path_match and scope_match and active_match:
            catalog[map_id] = {
                "path": path_match.group(1),
                "scope": scope_match.group(1),
                "active": active_match.group(1) == "true"
            }
            
    return catalog

def verify_release_scope(destinations_path, root):
    errors = []
    root_path = Path(root)

    for relative_path in ARCHIVE_GDIGNORE_PATHS:
        if not (root_path / relative_path).is_file():
            errors.append(f"Missing archive import exclusion: {relative_path}")

    try:
        with open(destinations_path, 'r') as f:
            dests = json.load(f)
    except FileNotFoundError:
        return errors

    release_scene_ids = set()
    for scene in dests.get("scenes", []):
        scene_id = scene.get("id", "")
        if not scene.get("active", False):
            continue
        if scene_id in RETIRED_SCENE_IDS:
            errors.append(f"Retired transition scene id remains active: {scene_id}")
            continue
        if scene.get("release", True):
            release_scene_ids.add(scene_id)
        if scene_id == "reval_harbor" and scene.get("release", True) is not False:
            errors.append("reval_harbor must remain release=false and developer-only")

    if release_scene_ids != RELEASE_SCENE_IDS:
        errors.append(
            "Release destinations must be exactly forge and reval_east; found: "
            + ", ".join(sorted(release_scene_ids))
        )

    return errors

def verify_activation(catalog_path, destinations_path, start_label_path):
    catalog = parse_catalog(catalog_path)
    
    path_to_map = {m["path"]: m for m in catalog.values()}
    
    errors = []
    
    try:
        with open(destinations_path, 'r') as f:
            dests = json.load(f)
            
        for scene in dests.get("scenes", []):
            if not scene.get("active", False):
                continue
            # Dev-traversal prototypes may register in the manifest while release
            # stays limited to the approved slice set.
            if scene.get("release", True) is False:
                continue
            path = scene.get("path")
            map_info = path_to_map.get(path)

            if map_info and map_info["scope"] in ["archive", "prototype"]:
                errors.append(f"Scene {path} is active in destinations but has scope {map_info['scope']}")
    except FileNotFoundError:
        pass
        
    try:
        with open(start_label_path, 'r') as f:
            content = f.read()
            
        matches = re.finditer(r'change_scene_to_file\("([^"]+)"\)', content)
        for match in matches:
            path = match.group(1)
            map_info = path_to_map.get(path)
            if map_info and map_info["scope"] in ["archive", "prototype"]:
                errors.append(f"Start flow points to {path} which has scope {map_info['scope']}")
    except FileNotFoundError:
        pass
        
    return errors

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="scripts/map/map_catalog.gd")
    parser.add_argument("--destinations", default="content/transitions/active_destinations.json")
    parser.add_argument("--start", default="scenes/intro/start_label.gd")
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    
    errors = verify_activation(args.catalog, args.destinations, args.start)
    errors.extend(verify_release_scope(args.destinations, args.root))
    if errors:
        for e in errors:
            print("ERROR:", e)
        sys.exit(1)
    
    print("Map activation guard passed.")
    sys.exit(0)
