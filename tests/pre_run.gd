extends GutHookScript
## GUT pre-run hook (R11): every test runs with the save root pointed at a
## throwaway folder of this run (tests/run_tmp.gd), so no test can touch
## kuhy's real save. scripts/test.sh also moves user:// itself (XDG_DATA_HOME),
## and SaveStore refuses the real save under GUT even if this hook is skipped.
## tests/test_save_guard.gd is RED when the redirect below is removed.

const RunTmp := preload("res://tests/run_tmp.gd")


func run() -> void:
	RunTmp.sweep_stale()
	SaveStore.root = RunTmp.path("save")
