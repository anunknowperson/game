extends Node

var keyhints :Array[String] = []

signal on_keyhints_changed(keyhints :Array[String])

func add_keyhint(hint :String):
	keyhints.push_back(hint)
	on_keyhints_changed.emit(keyhints)

func remove_keyhint(hint :String):
	keyhints.erase(hint)
	on_keyhints_changed.emit(keyhints)
