extends Node

var last_survival_time: float = 0.0
var last_kills: int = 0
var runs_started: int = 0
var current_stage: int = 1
var carried_skill_levels: Dictionary = {}


func start_campaign() -> void:
	current_stage = 1
	carried_skill_levels.clear()


func advance_stage() -> void:
	current_stage += 1


func record_skill(skill_id: StringName, level: int) -> void:
	carried_skill_levels[skill_id] = level


func begin_run() -> void:
	runs_started += 1
	last_survival_time = 0.0
	last_kills = 0


func finish_run(survival_time: float, kills: int) -> void:
	last_survival_time = survival_time
	last_kills = kills
