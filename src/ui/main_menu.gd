extends Control


func _ready() -> void:
	$Layout/Panel/Buttons/StartButton.grab_focus()


func _on_start_pressed() -> void:
	GameState.start_campaign()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
