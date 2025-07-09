extends TextureRect

func show_skill(skill :StudentSkill):
	texture = skill.skill_picture
	$AcceptDialog.title = skill.skill_name
	$AcceptDialog/RichTextLabel.text = skill.skill_desc


func _on_button_pressed() -> void:
	$AcceptDialog.popup()
