# ÜRETİLİR: tools/blender/sy_spec.py -> elle düzenleme (build_all.sh yeniden yazar).
class_name ArtDims
extends RefCounted

## Sanat kitinin ölçüleri (1 birim = 1 hücre = 1 m). Ray üstü y = 0.

const GAUGE: float = 0.26000
const RAIL_H: float = 0.04000
const RAIL_HEAD_W: float = 0.02600
const RAIL_FOOT_W: float = 0.05000
const SLEEPER_L: float = 0.46000
const SLEEPER_W: float = 0.06600
const SLEEPER_H: float = 0.02400
const SLEEPER_STEP: float = 0.16500
const SLEEPER_TOP: float = -0.04000
const BALLAST_TOP: float = -0.05320
const BALLAST_TOP_W: float = 0.56000
const BALLAST_BOTTOM_W: float = 0.76000
const GROUND_Y: float = -0.08520
const APRON_Y: float = -0.08120
const VEHICLE_W: float = 0.48000
const HEADSTOCK_LEN: float = 0.74000
const OVER_BUFFERS: float = 0.86000
const BUFFER_Y: float = 0.12500
const BUFFER_SPACING: float = 0.30000
const WHEEL_R: float = 0.06800
const FRAME_Y: float = 0.10500
const COUPLER_Z: float = 0.43000

const COLOR_NAMES: PackedStringArray = ["red", "blue", "yellow", "green", "purple", "orange"]
const COLORS: Dictionary[String, Color] = {
	"red": Color(0.8510, 0.2706, 0.2314),
	"blue": Color(0.2275, 0.4706, 0.8157),
	"yellow": Color(0.9412, 0.7059, 0.1647),
	"green": Color(0.2431, 0.6196, 0.3451),
	"purple": Color(0.5412, 0.3451, 0.7686),
	"orange": Color(0.9333, 0.4980, 0.1725),
}
const SYMBOLS: Dictionary[String, String] = {
	"red": "circle",
	"blue": "triangle",
	"yellow": "star",
	"green": "cross",
	"purple": "diamond",
	"orange": "square",
	"loco": "loco",
}
const SYMBOL_COLOR: Color = Color(1.0000, 0.9843, 0.9490)
const LOCO_TARGET_COLOR: Color = Color(0.9569, 0.9412, 0.8941)
