extends Label

var mytext = ""

func _on_button_pressed() -> void:
	send.rpc(WebrtcMultiplayer.manager.player_name, mytext)

@rpc("any_peer", "call_local", "reliable")
func send(namec, textf):
	
	text += namec + ": " + textf + "\n"

func _on_line_edit_text_changed(new_text: String) -> void:
	mytext = new_text
