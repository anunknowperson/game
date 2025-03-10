import os
import re
import glob

def extract_uid_from_scene(scene_path):
    """Extract the UID from a given scene file."""
    with open(scene_path, 'r') as f:
        content = f.read()
        uid_match = re.search(r'uid="([^"]+)"', content)
        if uid_match:
            return uid_match.group(1)
    return None

def find_scene_for_model(model_path):
    """Find corresponding scene file for a model file."""
    model_filename = os.path.basename(model_path)
    model_name = os.path.splitext(model_filename)[0]
    
    # Search for matching scene file
    scene_pattern = f"../scenes/{model_name}.tscn"
    matching_scenes = glob.glob(scene_pattern)
    
    if matching_scenes:
        return matching_scenes[0]
    return None

def process_level_scene(level_path):
    """Process the level scene file to replace model paths with scene paths."""
    with open(level_path, 'r') as f:
        content = f.read()
    
    # Find all model references
    model_refs = re.findall(r'\[ext_resource type="PackedScene" uid="([^"]+)" path="res://models/([^"]+)"\s+id="([^"]+)"\]', content)
    
    replacements = []
    for uid, model_path, id_value in model_refs:
        # Skip if not a .glb or .fbx file
        if not (model_path.endswith('.glb') or model_path.endswith('.fbx')):
            continue
        
        # Find corresponding scene
        full_model_path = f"res://models/{model_path}"
        scene_path = find_scene_for_model(full_model_path)
        
        if scene_path:
            # Extract UID from scene
            scene_uid = extract_uid_from_scene(scene_path)
            
            if scene_uid:
                # Create replacement pattern
                old_pattern = f'[ext_resource type="PackedScene" uid="{uid}" path="res://models/{model_path}" id="{id_value}"]'
                new_pattern = f'[ext_resource type="PackedScene" uid="{scene_uid}" path="res://scenes/{os.path.basename(model_path).split(".")[0]}.tscn" id="{id_value}"]'
                
                replacements.append((old_pattern, new_pattern))
                print(f"Replacing: {model_path} -> {os.path.basename(scene_path)}")
                print(f"UID change: {uid} -> {scene_uid}")
    
    # Apply all replacements
    new_content = content
    for old, new in replacements:
        new_content = new_content.replace(old, new)
    
    # Write updated content back to file
    with open(level_path, 'w') as f:
        f.write(new_content)
    
    print(f"Processed {len(replacements)} model references in {level_path}")

if __name__ == "__main__":
    level_file = "Level3.tscn"
    
    if not os.path.exists(level_file):
        print(f"Error: {level_file} not found in current directory")
    else:
        process_level_scene(level_file)
        print(f"Successfully updated {level_file}")