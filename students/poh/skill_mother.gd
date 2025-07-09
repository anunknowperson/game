extends StudentSkill
class_name StudentSkillMother


func _init() -> void:
	skill_name = "Оскорбить мать"
	skill_desc = "Ваня Пох оскорбляет мать выбранного существа, что наносит ему большой урон"
	skill_picture = load("res://students/poh/mat.png")
	skill_directed = true
