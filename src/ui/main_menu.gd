extends Control


func _ready() -> void:
	$Layout/Panel/Buttons/StartButton.grab_focus()
	var continue_button: Button = $Layout/Panel/Buttons/ContinueButton
	continue_button.disabled = not SaveManager.has_campaign()
	continue_button.text = "继续战役  第 %d 关" % _saved_stage() if not continue_button.disabled else "继续战役  暂无存档"


func _on_start_pressed() -> void:
	GameState.start_campaign()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_continue_pressed() -> void:
	if GameState.continue_campaign():
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _saved_stage() -> int:
	return int(SaveManager.load_campaign().get("stage", 1))


func _on_quit_pressed() -> void:
	get_tree().quit()
