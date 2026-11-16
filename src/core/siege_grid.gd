class_name SiegeGrid
extends RefCounted
## A uniform grid over the map for "who is near me": every decision step the
## entities an enemy can aim at are sorted into cells (one linked list per cell
## and team), and a query reads the 3x3 cells around a point, so it finds
## everything within CELL_M metres without visiting the whole field.

const CELL_M := 50.0
const INV := 1.0 / CELL_M
const COLS := 12
const ROWS := 8

## First entity of each cell (-1: empty), per team; `next` chains the rest.
var army := PackedInt32Array()
var village := PackedInt32Array()
var next := PackedInt32Array()


func rebuild(s: SiegeState) -> void:
	army.resize(COLS * ROWS)
	village.resize(COLS * ROWS)
	army.fill(-1)
	village.fill(-1)
	var n := s.pos.size()
	next.resize(n)
	var pos := s.pos
	var team := s.team
	var count := s.count
	var flag := s.flag
	var state := s.state
	var listed := SiegeState.F_TARGET
	var out := SiegeState.F_GONE
	for i in n:
		var f := flag[i]
		if count[i] <= 0 or f & listed == 0 or f & out != 0:
			continue
		if state[i] == SiegeSnapshot.State.HIDDEN:
			continue
		var p := pos[i]
		var cell := mini(int(p.x * INV), COLS - 1) + mini(int(p.y * INV), ROWS - 1) * COLS
		if team[i] == SiegeSnapshot.Team.ARMY:
			next[i] = army[cell]
			army[cell] = i
		else:
			next[i] = village[cell]
			village[cell] = i


## The listed entity of `heads` (this.army or this.village) nearest to `p`
## within `reach` metres (<= CELL_M), -1 for none. A standing entity wins over a
## fleeing one; a fleeing one counts only within `chase` metres. `skip` is
## never returned.
func nearest(
	s: SiegeState, heads: PackedInt32Array, p: Vector2, reach: float, chase: float, skip := -1
) -> int:
	var cx := mini(int(p.x * INV), COLS - 1)
	var cy := mini(int(p.y * INV), ROWS - 1)
	var best := -1
	var best_d := reach * reach
	var runner := -1
	var runner_d := chase * chase
	var pos := s.pos
	var state := s.state
	for y in range(maxi(cy - 1, 0), mini(cy + 2, ROWS)):
		var row := y * COLS
		for x in range(maxi(cx - 1, 0), mini(cx + 2, COLS)):
			var i := heads[row + x]
			while i != -1:
				var d := p.distance_squared_to(pos[i])
				if i == skip:
					pass
				elif state[i] == SiegeSnapshot.State.FLEE:
					if d < runner_d:
						runner_d = d
						runner = i
				elif d < best_d:
					best_d = d
					best = i
				i = next[i]
	return best if best != -1 else runner
