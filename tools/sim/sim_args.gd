extends RefCounted
## Command line of the headless sim tools: `--key=value` and bare `--flag`
## after the `--` of `godot --headless -s tools/sim/<tool>.gd -- ...`.


## {key: value} of every `--key=value` (a bare `--flag` maps to "1").
static func parse() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var cut := arg.find("=")
		if cut < 0:
			out[arg.substr(2)] = "1"
		else:
			out[arg.substr(2, cut - 2)] = arg.substr(cut + 1)
	return out


## The loadout of a comma separated id list ("" or "none": nothing bought).
static func loadout(text: String) -> Loadout:
	var ids: Array[String] = []
	for id in text.split(",", false):
		if id != "none":
			ids.append(id.strip_edges())
	return Loadout.of(ids)


## A loadout as text: its ids joined by commas, "none" when empty.
static func text(loadout_ids: Array) -> String:
	if loadout_ids.is_empty():
		return "none"
	return ",".join(loadout_ids.map(func(id: Variant) -> String: return str(id)))
