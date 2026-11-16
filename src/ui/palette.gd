class_name Palette
extends RefCounted
## THE palette: the only file with a colour literal (scripts/check_palette.sh
## fails the gate on one anywhere else in src/ or tools/). Every colour is a
## frozen token of the shared design system (`kuhyx/utils` `unified-design-system/`,
## DOCS-tokens.md, the same hex in every repo) or a mix of two of them, found
## by search against the colours this game used before. GDScript cannot fold
## a mix into a constant, so the mixed values are written out and `MIXES`
## names each recipe; tests/test_palette.gd rebuilds every one from the
## tokens and fails on a drift. `WorldPalette` and `PictoInk` are names for
## these, nothing more. Every cue also has a shape, never colour alone.

# The tokens (hex as in DOCS-tokens.md).
const T_INK := Color("#211D1B")
const T_RAISED_1 := Color("#2B2624")
const T_RAISED_2 := Color("#38312E")
const T_LINE := Color("#463E3A")
const T_TEXT := Color("#ECEAE9")
const T_MUTED := Color("#AAA09A")
const T_PAPER := Color("#F6F4F3")
const T_ACCENT := Color("#B8862E")
const T_SUCCESS := Color("#8A9A3C")
const T_WARNING := Color("#E0A63C")
const T_DANGER := Color("#E2585F")
const T_CAT_1 := Color("#C57293")
const T_CAT_2 := Color("#398FC0")
const T_CAT_3 := Color("#C85A32")
const T_CAT_4 := Color("#228736")
const T_CAT_5 := Color("#8D58BB")
const T_CAT_6 := Color("#686D2C")

# The game's roles.
const PANEL := T_INK
const PANEL_HOVER := T_RAISED_2
const PANEL_PRESSED := T_LINE
const INK := T_TEXT
const DIM := T_MUTED
const COIN := T_WARNING
const ARMY := T_CAT_2
const VILLAGE := T_CAT_3
const GOOD := T_SUCCESS
const BAD := T_DANGER
const GROUND := Color(0.1633, 0.2061, 0.1518)  # RAISED_1 + CAT_4, 0.15
const COIN_SPENT := Color(0.3145, 0.2973, 0.2286)  # LINE + SUCCESS, 0.15
const VILLAGE_GROUND := Color(0.2839, 0.2745, 0.1914)  # RAISED_2 + SUCCESS, 0.20
const BUILDING := Color(0.4369, 0.4110, 0.2847)  # CAT_5 + CAT_6, 0.80

# The battle: people, gear, ground, effects.
const ARMY_DARK := Color(0.1953, 0.4267, 0.5588)  # INK + CAT_2, 0.70
const VILLAGE_DARK := Color(0.6902, 0.3716, 0.1902)  # CAT_3 + CAT_6, 0.25
const CLOTH := Color(0.9090, 0.8243, 0.6763)  # TEXT + WARNING, 0.35
const SKIN := Color(0.9020, 0.7843, 0.5745)  # TEXT + WARNING, 0.50
const HAIR := Color(0.2418, 0.1943, 0.1253)  # INK + WARNING, 0.15
const SOOT := Color(0.1392, 0.1225, 0.1147)  # INK + RAISED_1, 0.25
const WOOD := Color(0.4980, 0.3843, 0.2039)  # LINE + ACCENT, 0.50
const WOOD_DARK := Color(0.3541, 0.2749, 0.1447)  # INK + WARNING, 0.30
const STEEL := Color(0.7741, 0.7639, 0.7592)  # RAISED_1 + TEXT, 0.80
const STEEL_DARK := Color(0.4478, 0.4776, 0.5302)  # CAT_2 + CAT_3, 0.40
const CARDBOARD := Color(0.7620, 0.6380, 0.4380)  # MUTED + WARNING, 0.45
const TAPE := Color(0.5475, 0.4280, 0.3002)  # DANGER + CAT_4, 0.45
const MONSTER := Color(0.5067, 0.5980, 0.4863)  # MUTED + CAT_4, 0.30
const MONSTER_COAT := Color(0.2204, 0.2659, 0.2949)  # RAISED_2 + CAT_2, 0.20
const MOOSE := Color(0.4173, 0.3298, 0.1969)  # RAISED_2 + WARNING, 0.30
const MOOSE_DARK := Color(0.2918, 0.1898, 0.1522)  # RAISED_1 + CAT_3, 0.20
const ANTLER := Color(0.8235, 0.7216, 0.5471)  # TEXT + ACCENT, 0.50
const WING := Color(0.8906, 0.9173, 0.9329, 0.75)  # CAT_2 + PAPER, 0.90
const PUMPKIN := Color(0.8314, 0.5020, 0.2157)  # WARNING + CAT_3, 0.50
const STEM := Color(0.3686, 0.5278, 0.1992)  # ACCENT + CAT_4, 0.60
const HULL := Color(0.6724, 0.6618, 0.6565)  # INK + PAPER, 0.65
const GLASS := Color(0.5941, 0.7588, 0.8529)  # CAT_2 + PAPER, 0.50
const GRASS_LIGHT := Color(0.2067, 0.2427, 0.1851)  # RAISED_2 + CAT_4, 0.15
const FIELD_GOLD := Color(0.3420, 0.3451, 0.1753)  # RAISED_2 + CAT_6, 0.65
const FIELD_GREEN := Color(0.2735, 0.2853, 0.1512)  # INK + SUCCESS, 0.35
const FURROW := Color(T_INK, 0.16)
const PATH := Color(0.3651, 0.3043, 0.2286)  # LINE + WARNING, 0.15
const ROOF_SHADE := Color(0.3416, 0.2855, 0.2204)  # LINE + ACCENT, 0.15
const RIDGE := Color(0.5447, 0.5263, 0.3847)  # SUCCESS + CAT_5, 0.30
const STONE := Color(0.5549, 0.5363, 0.5280)  # RAISED_2 + PAPER, 0.45
const STONE_SHADE := Color(0.4218, 0.4088, 0.4024)  # INK + PAPER, 0.35
const TREE := Color(0.1894, 0.3102, 0.1914)  # RAISED_2 + CAT_4, 0.35
const TREE_LIGHT := Color(0.2039, 0.3863, 0.2196)  # LINE + CAT_4, 0.50
const TENT := Color(0.7420, 0.7451, 0.6408)  # CAT_6 + PAPER, 0.60
const FLAME_MID := Color(0.8784, 0.6510, 0.2353)  # INK + WARNING, 1.00
const FLAME_CORE := Color(0.9216, 0.8039, 0.5941)  # WARNING + PAPER, 0.50
const SMOKE := Color(0.6224, 0.6208, 0.6188, 0.55)  # MUTED + CAT_2, 0.10
const DUST := Color(0.6886, 0.5867, 0.4345, 0.60)  # MUTED + ACCENT, 0.40
const SPARK := Color(0.9388, 0.8651, 0.7376)  # WARNING + PAPER, 0.70
const NIGHT := Color(T_INK, 0.62)
const BEAM := Color(0.7153, 0.8286, 0.7306, 0.40)  # CAT_4 + PAPER, 0.70

# The pictograms' extra hues, and the menu screens' fills.
const PICTO_WOOD := Color(0.6878, 0.4894, 0.2910)  # ACCENT + CAT_5, 0.20
const VIOLET := Color(0.6971, 0.5592, 0.8102)  # CAT_5 + PAPER, 0.35
const DEEP_GOLD := Color(0.7373, 0.5380, 0.1859)  # ACCENT + WARNING, 0.10
const SLATE := Color(0.3431, 0.4373, 0.4725)  # CAT_4 + CAT_5, 0.50
const GO := Color(0.2292, 0.5171, 0.2665)  # CAT_1 + CAT_4, 0.85
const SHADE := Color(T_INK, 0.70)
const LOST := Color(0.3914, 0.2094, 0.1420)  # INK + CAT_3, 0.40
const SLING_STONE := Color(0.8220, 0.8196, 0.7655)  # TEXT + CAT_6, 0.20
const SKY := Color(0.1341, 0.1361, 0.1382)  # INK + CAT_2, 0.05
const WAITING := Color(0.1769, 0.2108, 0.2329)  # RAISED_1 + CAT_2, 0.15
const GLINT := Color(0.8535, 0.8975, 0.9229)  # CAT_2 + PAPER, 0.85
const CHAR := Color(0.3025, 0.2304, 0.2398)  # RAISED_2 + CAT_1, 0.15

# Not colours: "no tint" for icons and "nothing".
const NO_TINT := Color(1, 1, 1)
const CLEAR := Color(1, 1, 1, 0)

## Name -> [token, token, share of the second, alpha when not 1]. A role that is
## one token is [token, token, 0].
const MIXES := {
	"PANEL": ["INK", "INK", 0.0],
	"PANEL_HOVER": ["RAISED_2", "RAISED_2", 0.0],
	"PANEL_PRESSED": ["LINE", "LINE", 0.0],
	"INK": ["TEXT", "TEXT", 0.0],
	"DIM": ["MUTED", "MUTED", 0.0],
	"COIN": ["WARNING", "WARNING", 0.0],
	"ARMY": ["CAT_2", "CAT_2", 0.0],
	"VILLAGE": ["CAT_3", "CAT_3", 0.0],
	"GOOD": ["SUCCESS", "SUCCESS", 0.0],
	"BAD": ["DANGER", "DANGER", 0.0],
	"GROUND": ["RAISED_1", "CAT_4", 0.15],
	"COIN_SPENT": ["LINE", "SUCCESS", 0.15],
	"VILLAGE_GROUND": ["RAISED_2", "SUCCESS", 0.2],
	"BUILDING": ["CAT_5", "CAT_6", 0.8],
	"ARMY_DARK": ["INK", "CAT_2", 0.7],
	"VILLAGE_DARK": ["CAT_3", "CAT_6", 0.25],
	"CLOTH": ["TEXT", "WARNING", 0.35],
	"SKIN": ["TEXT", "WARNING", 0.5],
	"HAIR": ["INK", "WARNING", 0.15],
	"SOOT": ["INK", "RAISED_1", 0.25],
	"WOOD": ["LINE", "ACCENT", 0.5],
	"WOOD_DARK": ["INK", "WARNING", 0.3],
	"STEEL": ["RAISED_1", "TEXT", 0.8],
	"STEEL_DARK": ["CAT_2", "CAT_3", 0.4],
	"CARDBOARD": ["MUTED", "WARNING", 0.45],
	"TAPE": ["DANGER", "CAT_4", 0.45],
	"MONSTER": ["MUTED", "CAT_4", 0.3],
	"MONSTER_COAT": ["RAISED_2", "CAT_2", 0.2],
	"MOOSE": ["RAISED_2", "WARNING", 0.3],
	"MOOSE_DARK": ["RAISED_1", "CAT_3", 0.2],
	"ANTLER": ["TEXT", "ACCENT", 0.5],
	"WING": ["CAT_2", "PAPER", 0.9, 0.75],
	"PUMPKIN": ["WARNING", "CAT_3", 0.5],
	"STEM": ["ACCENT", "CAT_4", 0.6],
	"HULL": ["INK", "PAPER", 0.65],
	"GLASS": ["CAT_2", "PAPER", 0.5],
	"GRASS_LIGHT": ["RAISED_2", "CAT_4", 0.15],
	"FIELD_GOLD": ["RAISED_2", "CAT_6", 0.65],
	"FIELD_GREEN": ["INK", "SUCCESS", 0.35],
	"FURROW": ["INK", "INK", 0.0, 0.16],
	"PATH": ["LINE", "WARNING", 0.15],
	"ROOF_SHADE": ["LINE", "ACCENT", 0.15],
	"RIDGE": ["SUCCESS", "CAT_5", 0.3],
	"STONE": ["RAISED_2", "PAPER", 0.45],
	"STONE_SHADE": ["INK", "PAPER", 0.35],
	"TREE": ["RAISED_2", "CAT_4", 0.35],
	"TREE_LIGHT": ["LINE", "CAT_4", 0.5],
	"TENT": ["CAT_6", "PAPER", 0.6],
	"FLAME_MID": ["INK", "WARNING", 1.0],
	"FLAME_CORE": ["WARNING", "PAPER", 0.5],
	"SMOKE": ["MUTED", "CAT_2", 0.1, 0.55],
	"DUST": ["MUTED", "ACCENT", 0.4, 0.6],
	"SPARK": ["WARNING", "PAPER", 0.7],
	"NIGHT": ["INK", "INK", 0.0, 0.62],
	"BEAM": ["CAT_4", "PAPER", 0.7, 0.4],
	"PICTO_WOOD": ["ACCENT", "CAT_5", 0.2],
	"VIOLET": ["CAT_5", "PAPER", 0.35],
	"DEEP_GOLD": ["ACCENT", "WARNING", 0.1],
	"SLATE": ["CAT_4", "CAT_5", 0.5],
	"GO": ["CAT_1", "CAT_4", 0.85],
	"SHADE": ["INK", "INK", 0.0, 0.7],
	"LOST": ["INK", "CAT_3", 0.4],
	"SLING_STONE": ["TEXT", "CAT_6", 0.2],
	"SKY": ["INK", "CAT_2", 0.05],
	"WAITING": ["RAISED_1", "CAT_2", 0.15],
	"GLINT": ["CAT_2", "PAPER", 0.85],
	"CHAR": ["RAISED_2", "CAT_1", 0.15],
}
