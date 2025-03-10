import re
import os
import glob
import uuid
from pathlib import Path

def process_godot_scene(scene_file_path):
    print(f"Processing scene: {scene_file_path}")
    
    # Read the original scene file
    with open(scene_file_path, 'r') as file:
        scene_content = file.read()
    
    # Extract the format version from the original scene
    format_match = re.search(r'\[gd_scene load_steps=\d+ format=(\d+)', scene_content)
    format_version = format_match.group(1) if format_match else "3"
    
    # Extract the scene UID if available
    uid_match = re.search(r'\[gd_scene load_steps=\d+ format=\d+ uid="([^"]+)"', scene_content)
    scene_uid = uid_match.group(1) if uid_match else ""
    
    # Find all model resources with path="res://models/..."
    model_pattern = r'\[ext_resource type="PackedScene" uid="([^"]*)" path="(res://models/[^"]*)"[^\]]*\]'
    
    model_resources = []
    for match in re.finditer(model_pattern, scene_content):
        uid = match.group(1)
        path = match.group(2)
        model_resources.append({
            'uid': uid,
            'path': path,
            'original_ref': match.group(0)
        })
    
    print(f"Found {len(model_resources)} model resources")
    
    # Track replaced resource nodes
    replaced_models = {}
    
    # Process each model resource
    for res in model_resources:
        # Extract model name without extension
        model_name = os.path.basename(res['path'])
        model_name_no_ext = os.path.splitext(model_name)[0]
        
        # Use scenes subdirectory if working with a scenes directory
        if os.path.dirname(scene_file_path).endswith("scenes"):
            new_scene_path = os.path.join(os.path.dirname(scene_file_path), f"{model_name_no_ext}.tscn")
        else:
            new_scene_path = f"{model_name_no_ext}.tscn"
        
        # Generate a new UID for the scene reference
        new_uid = "uid://" + "b" + uuid.uuid4().hex[:12]
        
        # Create new .tscn file if it doesn't exist
        create_new_scene_file(new_scene_path, res, format_version)
        
        # Remember the mapping for replacement
        replaced_models[res['uid']] = {
            'new_uid': new_uid,
            'new_path': os.path.basename(new_scene_path)
        }
    
    # Replace instances in the original scene
    for original_uid, replacement in replaced_models.items():
        new_uid = replacement['new_uid']
        new_path = replacement['new_path']
        
        # Add new resource reference
        if scene_uid:
            new_resource_line = f'[ext_resource type="PackedScene" uid="{new_uid}" path="res://{new_path}"]'
        else:
            # For older Godot versions that use IDs instead of UIDs
            new_id = str(uuid.uuid4().int)[:8]  # Generate a numeric ID
            new_resource_line = f'[ext_resource type="PackedScene" path="res://{new_path}" id="{new_id}"]'
            new_uid = new_id  # Use the ID for instance references
        
        # Add the resource line after the [gd_scene] line
        scene_content = re.sub(r'(\[gd_scene[^\]]*\])', f'\\1\n{new_resource_line}', scene_content, count=1)
        
        # Update load_steps count
        load_steps_match = re.search(r'load_steps=(\d+)', scene_content)
        if load_steps_match:
            current_steps = int(load_steps_match.group(1))
            scene_content = re.sub(r'load_steps=\d+', f'load_steps={current_steps + 1}', scene_content, count=1)
        
        # Replace instance references
        if scene_uid:  # Godot 4.x style with UIDs
            scene_content = re.sub(
                r'\[node name="([^"]*)" parent="([^"]*)" instance=ExtResource\("' + re.escape(original_uid) + r'"\)\]',
                f'[node name="\\1" parent="\\2" instance=ExtResource("{new_uid}")]',
                scene_content
            )
        else:  # Godot 3.x style with IDs
            scene_content = re.sub(
                r'\[node name="([^"]*)" parent="([^"]*)" instance=ExtResource\( *' + re.escape(original_uid) + r' *\)\]',
                f'[node name="\\1" parent="\\2" instance=ExtResource( {new_uid} )]',
                scene_content
            )
    
    # Write the modified scene back to disk
    with open(scene_file_path, 'w') as file:
        file.write(scene_content)
    
    print(f"Processing complete. Original scene updated: {scene_file_path}")

def create_new_scene_file(new_scene_path, resource, format_version):
    # If the file already exists, don't overwrite it
    if os.path.exists(new_scene_path):
        print(f"Scene file already exists, skipping: {new_scene_path}")
        return
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(new_scene_path), exist_ok=True)
    
    # Get model name without extension for node name
    model_name = os.path.basename(resource['path'])
    model_name_no_ext = os.path.splitext(model_name)[0]
    
    # Format the scene based on Godot version
    if format_version == "3":
        # Godot 3.x format
        new_scene_content = f"""[gd_scene load_steps=2 format=3]

[ext_resource path="{resource['path']}" type="PackedScene" id=1]

[node name="Spatial" type="Spatial"]
transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0 )

[node name="{model_name_no_ext}" parent="." instance=ExtResource( 1 )]
"""
    else:
        # Godot 4.x format
        new_scene_content = f"""[gd_scene load_steps=2 format={format_version}]

[ext_resource type="PackedScene" uid="{resource['uid']}" path="{resource['path']}"]

[node name="Spatial" type="Node3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)

[node name="{model_name_no_ext}" parent="." instance=ExtResource("{resource['uid']}")]
"""
    
    # Write the new scene file
    with open(new_scene_path, 'w') as file:
        file.write(new_scene_content)
    
    print(f"Created new scene: {new_scene_path}")

def main():
    # Get the current directory
    current_dir = os.getcwd()
    
    # Check if there's a scenes directory
    scenes_dir = os.path.join(current_dir, "scenes")
    if os.path.isdir(scenes_dir):
        scene_files = glob.glob(os.path.join(scenes_dir, "*.tscn"))
        if scene_files:
            print(f"Found {len(scene_files)} scene files in the scenes directory")
            for scene_file in scene_files:
                process_godot_scene(scene_file)
            return
    
    # If no scenes directory or no files there, check the current directory
    scene_files = glob.glob(os.path.join(current_dir, "*.tscn"))
    
    if not scene_files:
        print("No .tscn files found in the current directory or scenes directory")
        scene_file = input("Please enter the path to your .tscn file: ")
        if os.path.exists(scene_file) and scene_file.endswith('.tscn'):
            process_godot_scene(scene_file)
        else:
            print("Invalid file path or not a .tscn file")
    else:
        print(f"Found {len(scene_files)} scene files in the current directory")
        for scene_file in scene_files:
            process_godot_scene(scene_file)

if __name__ == "__main__":
    main()