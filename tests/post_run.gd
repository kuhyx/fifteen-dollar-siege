extends GutHookScript
## GUT post-run hook: removes this run's throwaway folder (tests/run_tmp.gd).

const RunTmp := preload("res://tests/run_tmp.gd")


func run() -> void:
	RunTmp.cleanup()
