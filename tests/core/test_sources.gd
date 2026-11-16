extends GutTest
## build-game R6: every tuning constant has a row in a Sources table, with the
## value the code has now. The tables: DOCS-design-sources.md (SiegeTuning)
## and DOCS-design-buff-sources.md (BuffTuning). A row reads
## "| `Class.NAME` | value | source |".

const TABLES := {
	"SiegeTuning": ["res://src/core/siege_tuning.gd", "res://DOCS-design-sources.md"],
	"BuffTuning": ["res://src/core/buff_tuning.gd", "res://DOCS-design-buff-sources.md"],
}


## name -> value text of every `const NAME := value` line of a script.
func _constants(path: String) -> Dictionary:
	var out := {}
	var pattern := RegEx.create_from_string("^const ([A-Z_0-9]+)(?:: \\w+)? :?= (.+)$")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var found := pattern.search(line)
		if found != null and not found.get_string(2).begins_with("preload"):
			out[found.get_string(1)] = found.get_string(2).strip_edges()
	return out


func test_every_tuning_constant_has_a_sourced_row_with_its_value() -> void:
	for cls: String in TABLES:
		var constants := _constants(TABLES[cls][0])
		var doc := FileAccess.get_file_as_string(TABLES[cls][1])
		assert_gt(constants.size(), 50, "%s has its constants" % cls)
		var missing: Array[String] = []
		for constant: String in constants:
			var row := "| `%s.%s` | %s | " % [cls, constant, constants[constant]]
			if not doc.contains(row):
				missing.append(constant)
		assert_eq(missing, [] as Array[String], "%s rows missing or stale" % TABLES[cls][1])


func test_no_source_cell_is_empty() -> void:
	for cls: String in TABLES:
		for line in FileAccess.get_file_as_string(TABLES[cls][1]).split("\n"):
			if not line.begins_with("| `%s." % cls):
				continue
			var cells := line.split("|")
			assert_eq(cells.size(), 5, line)
			assert_gt(cells[3].strip_edges().length(), 8, "a source or a reasoned guess: %s" % line)
