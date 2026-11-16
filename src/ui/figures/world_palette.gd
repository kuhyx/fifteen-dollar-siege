class_name WorldPalette
extends RefCounted
## The battle's colours beside the shared `Palette` (team, good, bad and coin
## colours come from there, so the whole game keeps one palette). Warm, muted
## ground; saturated figures on top, so the eye goes to the people first.

const ARMY := Palette.ARMY
const ARMY_DARK := Color(0.2, 0.36, 0.62)
const VILLAGE := Palette.VILLAGE
const VILLAGE_DARK := Color(0.68, 0.36, 0.18)
const CLOTH := Color(0.9, 0.82, 0.66)
const SKIN := Color(0.93, 0.76, 0.6)
const HAIR := Color(0.24, 0.18, 0.13)
const SOOT := Color(0.13, 0.12, 0.13)
const WHITE := Palette.INK
const WOOD := Color(0.52, 0.37, 0.22)
const WOOD_DARK := Color(0.36, 0.25, 0.15)
const STEEL := Color(0.74, 0.77, 0.8)
const STEEL_DARK := Color(0.48, 0.51, 0.56)
const CARDBOARD := Color(0.74, 0.6, 0.42)
const TAPE := Color(0.55, 0.43, 0.28)
const BRASS := Palette.COIN
const MONSTER := Color(0.52, 0.64, 0.45)
const MONSTER_COAT := Color(0.22, 0.24, 0.3)
const MOOSE := Color(0.44, 0.31, 0.2)
const MOOSE_DARK := Color(0.3, 0.21, 0.14)
const ANTLER := Color(0.82, 0.74, 0.56)
const WING := Color(0.86, 0.92, 0.96, 0.75)
const PUMPKIN := Color(0.96, 0.48, 0.1)
const STEM := Color(0.36, 0.52, 0.22)
const HULL := Color(0.62, 0.66, 0.72)
const GLASS := Color(0.5, 0.9, 0.86)
const GUITAR := Palette.BAD

const GRASS := Palette.GROUND
const GRASS_LIGHT := Color(0.2, 0.25, 0.17)
const FIELD_GOLD := Color(0.36, 0.33, 0.17)
const FIELD_GREEN := Color(0.25, 0.3, 0.16)
const FURROW := Color(0.0, 0.0, 0.0, 0.16)
const PATH := Color(0.37, 0.32, 0.24)
const YARD := Palette.VILLAGE_GROUND
const ROOF := Palette.BUILDING
const ROOF_SHADE := Color(0.35, 0.29, 0.21)
const RIDGE := Color(0.58, 0.5, 0.38)
const STONE := Color(0.56, 0.55, 0.52)
const STONE_SHADE := Color(0.42, 0.41, 0.39)
const TREE := Color(0.19, 0.31, 0.18)
const TREE_LIGHT := Color(0.27, 0.41, 0.22)
const TENT := Color(0.78, 0.74, 0.64)

const FLAME := Palette.BAD
const FLAME_MID := Color(1.0, 0.62, 0.15)
const FLAME_CORE := Color(1.0, 0.92, 0.55)
const SMOKE := Color(0.62, 0.61, 0.63, 0.55)
const DUST := Color(0.66, 0.57, 0.43, 0.6)
const SPARK := Color(1.0, 0.95, 0.7)
const NIGHT := Color(0.04, 0.05, 0.14, 0.62)
const BEAM := Color(0.6, 1.0, 0.8, 0.4)
