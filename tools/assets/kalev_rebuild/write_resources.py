"""Write small resource wrappers using the existing wardrobe and equipment API."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'assets/characters/kalev_fresh';RES='res://assets/characters/kalev_fresh'
wearables={
 'linen_shirt':('torso',['Anatomy_Torso','Anatomy_Arms']),
 'wool_tunic':('torso',['Anatomy_Torso','Anatomy_Arms']),
 'mail_shirt':('torso',['Anatomy_Torso','Anatomy_Arms']),
 'smith_apron':('outerwear',[]),
 'hose':('legs',['Clothing_Braies','Anatomy_Legs','Anatomy_Calves']),
 'boots':('feet',['Anatomy_Feet','Anatomy_Calves']),
}
for name,(slot,coverage) in wearables.items():
    quoted=', '.join('&"'+p+'"' for p in coverage)
    (OUT/f'{name}.tres').write_text(f'''[gd_resource type="Resource" script_class="CharacterWearable" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/characters/character_wearable.gd" id="1"]
[ext_resource type="PackedScene" path="{RES}/{name}/{name}.glb" id="2"]

[resource]
script = ExtResource("1")
stable_id = &"wearable.kalev_fresh.{name}"
slot = "{slot}"
fitted_body = "kalev_fresh"
scene = ExtResource("2")
covered_meshes = Array[StringName]([{quoted}])
''')
(OUT/'kalev_fresh.tscn').write_text(f'''[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="{RES}/fresh_rig.gd" id="1"]
[ext_resource type="PackedScene" path="{RES}/kalev_fresh/kalev_fresh.glb" id="2"]
[ext_resource type="Script" path="res://assets/characters/shared/character_variant.gd" id="3"]

[sub_resource type="Resource" id="Variant"]
script = ExtResource("3")
stable_id = &"char.kalev"

[node name="KalevFresh" type="Node3D"]
script = ExtResource("1")
model_scale = Vector3(1.0989011, 1.0989011, 1.0989011)
use_anatomical_muscles = false
variant = SubResource("Variant")

[node name="Model" type="Node3D" parent="."]

[node name="Kalev" parent="Model" instance=ExtResource("2")]
''')
