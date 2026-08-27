import sys

out = """[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://src/systems/ecology_system.gd" id="1"]
[ext_resource type="Script" path="res://src/systems/soundscape_system.gd" id="2"]
[ext_resource type="Script" path="res://src/systems/audio_director.gd" id="3"]
[ext_resource type="Script" path="res://src/level/vertical_slice.gd" id="4"]
[ext_resource type="Script" path="res://src/systems/climb_system.gd" id="5"]
[ext_resource type="Script" path="res://src/systems/climb_camera.gd" id="6"]
[ext_resource type="PackedScene" path="res://src/level/greybox_wall.tscn" id="7"]

[node name="VerticalSlice" type="Node3D"]
script = ExtResource("4")

[node name="EcologySystem" type="Node" parent="."]
script = ExtResource("1")

[node name="SoundscapeSystem" type="Node" parent="."]
script = ExtResource("2")

[node name="AudioDirector" type="Node" parent="."]
script = ExtResource("3")

[node name="ClimbSystem" type="Node" parent="."]
script = ExtResource("5")

[node name="ClimbCamera" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 10)
script = ExtResource("6")
climb_system_path = NodePath("../ClimbSystem")
follow_speed = 5.0

[node name="GreyboxWall" parent="." instance=ExtResource("7")]

[node name="OnboardingInstruction" type="Label3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, -3)
text = "level_intro"
font_size = 64
outline_size = 8
"""

with open("src/level/vertical_slice.tscn", "w") as f:
    f.write(out)

