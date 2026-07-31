class_name RoutePanel
extends CanvasLayer

signal route_selected(zone: int)

const ZONES := ["断裂装配线", "熔炉回廊", "电容十字", "冷却井阵", "坠落航站", "风蚀营地", "盐碱坟场", "深井泵站"]

@onready var overlay: Control = $Overlay
@onready var buttons: Array[Button] = [
	$Overlay/Panel/Content/Routes/Route1,
	$Overlay/Panel/Content/Routes/Route2,
	$Overlay/Panel/Content/Routes/Route3,
]


func _ready() -> void:
	overlay.visible = false
	for index in buttons.size():
		buttons[index].pressed.connect(_choose.bind(index))


func show_routes(current_zone: int) -> void:
	for index in buttons.size():
		var zone := posmod(current_zone + index + 1, ZONES.size())
		buttons[index].set_meta("zone", zone)
		buttons[index].text = "%d  %s\n%s" % [index + 1, ZONES[zone], _route_detail(zone)]
	overlay.visible = true
	buttons[0].grab_focus()


func _choose(index: int) -> void:
	if index < 0 or index >= buttons.size():
		return
	overlay.visible = false
	route_selected.emit(int(buttons[index].get_meta("zone", 0)))


func _route_detail(zone: int) -> String:
	match zone:
		0: return "打捞特许  ·  回收箱废料 +1"
		1: return "熔炉危机  ·  敌军推进更快"
		2: return "高压试验  ·  强化更快  敌群更多"
		3: return "冷却庇护  ·  生命与机动能力提升"
		4: return "坠落打捞  ·  回收箱出现更频繁"
		5: return "风蚀机动  ·  地形开阔，移动强化"
		6: return "盐碱围猎  ·  敌群更密集，收益更高"
		_: return "深井庇护  ·  重装补给与稳定防线"
