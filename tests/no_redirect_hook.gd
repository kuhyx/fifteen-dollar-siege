extends GutHookScript
## A pre-run hook that does NOT move the save root. Only
## scripts/test_save_guard.sh uses it (-gpre_run_script=), to prove the game
## itself keeps a GUT run out of the real save when tests/pre_run.gd is skipped.


func run() -> void:
	pass
