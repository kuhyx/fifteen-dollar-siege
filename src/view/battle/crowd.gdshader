shader_type canvas_item;
render_mode unshaded;

// One squad or special of the siege. Every instance is one individual: it
// stands at anchor + home * spread (home = its own place in the unit disc,
// INSTANCE_CUSTOM.xy) and moves by the squad's pose with its own phase
// (INSTANCE_CUSTOM.z). A fallen individual (INSTANCE_CUSTOM.w = 1) lies where
// its instance transform put it and no longer follows the anchor.
// Mesh: metres, feet at the origin, up is -y, facing +x. UV.x = 1 marks the
// weapon arm, which swings about `pivot` in a fight.

uniform vec2 anchor = vec2(0.0);
uniform float spread = 1.0;
// Stretches home and buzz: a swarm of wasps grows with the far-zoom boost.
uniform float grow = 1.0;
// Metres a figure with phase 1 trails behind a moving anchor.
uniform vec2 lag = vec2(0.0);
// SiegeSnapshot.State: 0 idle, 1 move, 2 fight, 3 flee, 4 down, 5 hidden.
uniform float pose = 0.0;
// Animation seconds, set once a frame for every squad; stands still on pause.
global uniform float siege_clock;
// Times life size at a far zoom (a man never shrinks to a speck), about the feet.
global uniform float figure_boost;
uniform float flip = 1.0;
// Amplitudes: bob (walk), shake (fight), lean (flee), swing (weapon arm).
uniform vec4 motion = vec4(0.38, 0.09, 0.42, 0.9);
uniform vec2 pivot = vec2(0.5, -1.92);
uniform float buzz = 0.0;
uniform float hover = 0.0;
uniform float down_turn = 1.5;
// Booze: 1 sways the figures and lets them drift.
uniform float wobble = 0.0;
uniform float fade = 1.0;
// 1 = an army squad the village cannot see: a faint glint for the player.
uniform float shimmer = 0.0;
// 0..1 chars the figure (the lose payoff).
uniform float burn = 0.0;
// Above 0 the mesh is a flame of that size on each figure.
uniform float flame = 0.0;
// Metres of jumping for joy (the pep talk).
uniform float cheer = 0.0;

// The buildings (x, y, w, h in metres, one texel each): nobody stands on a roof.
// The same sums as CrowdScatter.clear_of.
global uniform sampler2D blocks : filter_nearest;
global uniform int block_count;
const float MARGIN = 0.8;

vec2 cleared(vec2 spot) {
	for (int round_no = 0; round_no < 3; round_no++) {
		for (int i = 0; i < block_count; i++) {
			vec4 block = texelFetch(blocks, ivec2(i, 0), 0);
			vec2 low = block.xy - vec2(MARGIN);
			vec2 high = block.xy + block.zw + vec2(MARGIN);
			if (spot.x <= low.x || spot.x >= high.x || spot.y <= low.y || spot.y >= high.y) {
				continue;
			}
			vec4 gap = vec4(spot.x - low.x, high.x - spot.x, spot.y - low.y, high.y - spot.y);
			float least = min(min(gap.x, gap.y), min(gap.z, gap.w));
			if (least == gap.x) {
				spot.x = low.x;
			} else if (least == gap.y) {
				spot.x = high.x;
			} else if (least == gap.z) {
				spot.y = low.y;
			} else {
				spot.y = high.y;
			}
		}
	}
	return spot;
}

vec2 turned(vec2 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void vertex() {
	vec2 home = INSTANCE_CUSTOM.xy;
	float phase = INSTANCE_CUSTOM.z;
	float fallen = step(0.5, INSTANCE_CUSTOM.w);
	float t = siege_clock + phase * 6.2831853;
	float state = mix(pose, 4.0, fallen);
	float side = phase > 0.5 ? 1.0 : -1.0;
	vec2 v = VERTEX * figure_boost;
	vec2 shift = vec2(0.0);
	float tilt = 0.0;
	if (flame > 0.0) {
		v.x += sin(t * 9.0 + v.y * 2.0) * 0.14 * -v.y;
		v *= flame * (1.25 + 0.4 * sin(t * 13.0 + phase * 40.0));
		shift.y -= 0.4 * (1.0 - fallen);
	} else {
		v.x *= flip;
		vec2 hinge = vec2(pivot.x * flip, pivot.y);
		if (state < 0.5 || state > 4.5) {
			v.y *= 1.0 + 0.03 * sin(t * 2.0);
		} else if (state < 1.5) {
			shift.y -= abs(sin(t * 4.5)) * motion.x;
			tilt = sin(t * 4.5) * 0.07;
		} else if (state < 2.5) {
			shift.x += sin(t * 23.0) * motion.y + max(sin(t * 6.0), 0.0) * 0.4 * flip;
			vec2 swung = hinge + turned(v - hinge, sin(t * 6.0) * motion.w * flip);
			v = mix(v, swung, UV.x);
		} else if (state < 3.5) {
			v.x -= v.y * motion.z * flip;
			shift.y -= abs(sin(t * 7.5)) * motion.x * 1.2;
		} else {
			v = turned(v, down_turn * side);
			COLOR.rgb *= 0.6;
		}
		if (state < 3.5 || state > 4.5) {
			shift.y -= abs(sin(t * 9.0)) * cheer + sin(t * 1.5) * hover;
			shift += vec2(sin(t * 17.0 + phase * 50.0), cos(t * 13.0 + phase * 31.0)) * buzz * grow;
			tilt += sin(t * 1.7) * 0.22 * wobble;
			home += vec2(sin(t * 0.9 + phase * 20.0), cos(t * 0.7)) * 0.12 * wobble;
		}
		v = turned(v, tilt);
		COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * vec3(0.3, 0.24, 0.24), burn * 0.8);
		COLOR.rgb = mix(COLOR.rgb, vec3(0.8, 0.95, 1.0), shimmer * 0.45);
	}
	float glint = 0.3 + 0.18 * sin(t * 3.0);
	COLOR.a *= fade * mix(1.0, glint, shimmer);
	vec2 spot = anchor + home * spread * grow - lag * phase;
	VERTEX = v + shift + (1.0 - fallen) * cleared(spot);
}
