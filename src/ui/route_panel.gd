class_name RoutePanel
extends CanvasLayer

signal route_selected(zone: int)

const ZONES := ["近地轨道平台", "日冕能源环", "量子交叉港", "冷星观测站", "失重航站", "星云补给带", "月面通信阵", "深空采矿区", "红移中继站", "极光防卫塔", "磁暴前哨", "天穹研究站", "星环货运港", "彗尾观测站", "静海浮岛", "银河栖息区", "虚空接驳站", "蓝移船坞", "极夜补给站", "天琴防御链", "裂隙巡航区", "曙光通讯塔", "星尘反应堆", "终焉守望台"]

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
		9: return "极光塔防  ·  折线防区，掩体更集中"
		10: return "磁暴前哨  ·  镜像战区，火力更密集"
		11: return "天穹研究  ·  长轴甲板，保持机动"
		12: return "星环货运  ·  旋转货舱，注意侧翼"
		13: return "彗尾观测  ·  稀疏掩体，优先远程火力"
		14: return "静海浮岛  ·  开阔防线，补给更分散"
		15: return "银河栖息  ·  环形通道，适合反弹武器"
		16: return "虚空接驳  ·  狭长接驳桥，谨防包围"
		17: return "蓝移船坞  ·  旋转船坞，目标更难预测"
		18: return "极夜补给  ·  高密度掩体，补给更珍贵"
		19: return "天琴防线  ·  星门阵列，强化射程优势"
		20: return "裂隙巡航  ·  断裂甲板，持续保持移动"
		21: return "曙光通讯  ·  宽阔扇区，敌军从多方接近"
		22: return "星尘反应  ·  核心防区，精英敌军更多"
		_: return "终焉守望  ·  最终防线，完成二十四区战役"
