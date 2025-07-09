extends Label

func _ready() -> void:
	set_keyhints(KeyhintManager.keyhints)
	KeyhintManager.on_keyhints_changed.connect(on_keyhints_changed)

func on_keyhints_changed(keyhints :Array[String]) -> void:
	set_keyhints(keyhints)

func set_keyhints(keyhints :Array[String]) -> void:
	var txt = ""
	for kh in keyhints:
		txt += kh + "\n"
	
	text = txt.trim_suffix(" ")
