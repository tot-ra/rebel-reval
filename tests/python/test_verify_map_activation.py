import unittest
import os
import tempfile
import json
import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../tools")))
from verify_map_activation import verify_activation, parse_catalog

class TestVerifyMapActivation(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        
        self.catalog_path = os.path.join(self.temp_dir.name, "map_catalog.gd")
        with open(self.catalog_path, 'w') as f:
            f.write('''
class_name MapCatalog
const MAPS: Dictionary = {
    "valid_prod": {
        "path": "res://valid.tscn",
        "scope": "production",
        "active": true
    },
    "archived_map": {
        "path": "res://archived.tscn",
        "scope": "archive",
        "active": false
    },
    "prototype_map": {
        "path": "res://prototype.tscn",
        "scope": "prototype",
        "active": false
    }
}
''')

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_parse_catalog(self):
        cat = parse_catalog(self.catalog_path)
        self.assertIn("valid_prod", cat)
        self.assertEqual(cat["archived_map"]["scope"], "archive")

    def test_valid_activation(self):
        dest_path = os.path.join(self.temp_dir.name, "dest.json")
        with open(dest_path, 'w') as f:
            json.dump({"scenes": [{"path": "res://valid.tscn", "active": True}]}, f)
            
        start_path = os.path.join(self.temp_dir.name, "start.gd")
        with open(start_path, 'w') as f:
            f.write('change_scene_to_file("res://valid.tscn")')
            
        errors = verify_activation(self.catalog_path, dest_path, start_path)
        self.assertEqual(len(errors), 0)

    def test_seeded_active_prototype_without_release_flag(self):
        dest_path = os.path.join(self.temp_dir.name, "dest.json")
        with open(dest_path, 'w') as f:
            json.dump({"scenes": [{"path": "res://prototype.tscn", "active": True}]}, f)
            
        start_path = os.path.join(self.temp_dir.name, "start.gd")
        with open(start_path, 'w') as f:
            f.write('change_scene_to_file("res://valid.tscn")')
            
        errors = verify_activation(self.catalog_path, dest_path, start_path)
        self.assertEqual(len(errors), 1)
        self.assertIn("scope prototype", errors[0])

    def test_dev_traversal_prototype_skips_release_guard(self):
        dest_path = os.path.join(self.temp_dir.name, "dest.json")
        with open(dest_path, 'w') as f:
            json.dump({"scenes": [{"path": "res://prototype.tscn", "active": True, "release": False}]}, f)

        start_path = os.path.join(self.temp_dir.name, "start.gd")
        with open(start_path, 'w') as f:
            f.write('change_scene_to_file("res://valid.tscn")')

        errors = verify_activation(self.catalog_path, dest_path, start_path)
        self.assertEqual(len(errors), 0)

    def test_seeded_archived_destination(self):
        dest_path = os.path.join(self.temp_dir.name, "dest.json")
        with open(dest_path, 'w') as f:
            json.dump({"scenes": [{"path": "res://valid.tscn", "active": True}]}, f)
            
        start_path = os.path.join(self.temp_dir.name, "start.gd")
        with open(start_path, 'w') as f:
            f.write('change_scene_to_file("res://archived.tscn")')
            
        errors = verify_activation(self.catalog_path, dest_path, start_path)
        self.assertEqual(len(errors), 1)
        self.assertIn("scope archive", errors[0])

if __name__ == '__main__':
    unittest.main()
