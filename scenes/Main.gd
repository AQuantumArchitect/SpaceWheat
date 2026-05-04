extends Control

const AppRootClass = preload("res://scenes/AppRoot.gd")

var app_root = null


func _ready() -> void:
	name = "Main"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	app_root = AppRootClass.new()
	app_root.name = "AppRoot"
	add_child(app_root)
