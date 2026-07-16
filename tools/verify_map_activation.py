import json
import re
import sys

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

def verify_activation(catalog_path, destinations_path, start_label_path):
    catalog = parse_catalog(catalog_path)
    
    path_to_map = {m["path"]: m for m in catalog.values()}
    
    errors = []
    
    try:
        with open(destinations_path, 'r') as f:
            dests = json.load(f)
            
        for scene in dests.get("scenes", []):
            if scene.get("active", False):
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
    args = parser.parse_args()
    
    errors = verify_activation(args.catalog, args.destinations, args.start)
    if errors:
        for e in errors:
            print("ERROR:", e)
        sys.exit(1)
    
    print("Map activation guard passed.")
    sys.exit(0)
