extends Node

var last_survival_time: float = 0.0
var last_kills: int = 0
var runs_started: int = 0


func begin_run() -> void:
	runs_started += 1
	last_survival_time = 0.0
	last_kills = 0


func finish_run(survival_time: float, kills: int) -> void:
	last_survival_time = survival_time
	last_kills = kills

