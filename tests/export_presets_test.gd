extends SceneTree


func _initialize() -> void:
	var config := ConfigFile.new()
	var error := config.load("res://export_presets.cfg")
	if error != OK:
		printerr("EXPORT_PRESETS: unable to load export_presets.cfg")
		quit(1)
		return
	var names: Array[String] = []
	for index in 2:
		names.append(str(config.get_value("preset.%d" % index, "name", "")))
	if names != ["Linux", "Windows"]:
		printerr("EXPORT_PRESETS: expected Linux and Windows, got %s" % names)
		quit(1)
		return
	print("EXPORT_PRESETS: PASS")
	quit(0)

