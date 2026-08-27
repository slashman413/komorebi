import sys

def main():
    holds = [
        # Segment 1 (easy)
        {"y": -4, "rest": True},
        {"y": -2, "rest": False},
        {"y": 0, "rest": True},
        # Segment 2 (medium)
        {"y": 2, "rest": False},
        {"y": 4, "rest": False},
        {"y": 6, "rest": True},
        # Segment 3 (harder)
        {"y": 8, "rest": False},
        {"y": 10, "rest": False},
        {"y": 12, "rest": False},
        {"y": 14, "rest": True},
        # Segment 4 (final push)
        {"y": 16, "rest": False},
        {"y": 18, "rest": False},
        {"y": 20, "rest": False},
        {"y": 22, "rest": False},
        {"y": 24, "rest": True}, # Ending hold
    ]
    
    out = [
        '[gd_scene load_steps=3 format=3]',
        '',
        '[ext_resource type="Script" path="res://src/nodes/climb_hold.gd" id="1"]',
        '',
        '[sub_resource type="BoxMesh" id="1"]',
        'size = Vector3(10, 30, 1)',
        '',
        '[node name="GreyboxWall" type="Node3D"]',
        '',
        '[node name="WallMesh" type="MeshInstance3D" parent="."]',
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 10, 0)',
        'mesh = SubResource("1")',
        ''
    ]
    
    for i, h in enumerate(holds):
        idx = i + 1
        out.append(f'[node name="Hold{idx}" type="Node3D" parent="."]')
        out.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {h["y"]}, 0.5)')
        out.append(f'script = ExtResource("1")')
        if h["rest"]:
            out.append('is_rest_point = true')
        if i < len(holds) - 1:
            out.append(f'connected_holds = [NodePath("../Hold{idx+1}")]')
        else:
            out.append('connected_holds = []')
        out.append('')
        
    with open("src/level/greybox_wall.tscn", "w") as f:
        f.write("\n".join(out))

if __name__ == "__main__":
    main()
