class_name RoutePanel
extends CanvasLayer

signal route_selected(zone: int)

const ZONES := ["近地轨道平台", "日冕能源环", "量子交叉港", "冷星观测站", "失重航站", "星云补给带", "月面通信阵", "深空采矿区", "红移中继站", "极光防卫塔"]

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
		0: return "轨道打捞  ·  回收箱合金 +1"
		1: return "日冕过载  ·  敌军推进更快"
		2: return "高压试验  ·  强化更快  敌群更多"
		3: return "冷却庇护  ·  生命与机动能力提升"
		4: return "坠落打捞  ·  回收箱出现更频繁"
		5: return "星云机动  ·  开阔甲板，移动强化"
		6: return "月面围猎  ·  敌群更密集，收益更高"
		7: return "深空矿区  ·  重装补给与稳定防线"
		8: return "红移中继  ·  武器模块更易出现"
		_: return "极光塔防  ·  维持星港防线"
