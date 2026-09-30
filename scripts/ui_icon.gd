extends Control
## Tiny vector icons drawn with shapes (no image files needed):
## "bread", "flower", "fish", "crab", "jelly", "carrot", "wheat", "pumpkin", "coin",
## "firefly", "drop", "hat", "note", "flag", "star".

var kind := "star"
var color := Color.WHITE        # main color (used by flower / fish / jelly)


func _init(k := "star", c := Color.WHITE, s := 40.0) -> void:
	kind = k
	color = c
	custom_minimum_size = Vector2(s, s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var c := size / 2
	var u := w / 40.0   # drawing unit: icons are designed on a 40x40 grid
	match kind:
		"bread":
			_ellipse(c + Vector2(0, 3) * u, Vector2(16, 10) * u, Color(0.78, 0.5, 0.22))
			_ellipse(c + Vector2(0, 0) * u, Vector2(15, 9) * u, Color(0.9, 0.62, 0.3))
			for i in 3:
				var x := (-7 + i * 7) * u
				draw_line(c + Vector2(x - 2 * u, -3 * u), c + Vector2(x + 2 * u, 3 * u), Color(0.98, 0.85, 0.6), 2.0 * u)
		"flower":
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2
				draw_circle(c + Vector2(cos(a), sin(a)) * 9 * u, 7 * u, color)
			draw_circle(c, 6 * u, Color(1, 0.85, 0.25))
		"fish":
			_ellipse(c + Vector2(-2, 0) * u, Vector2(13, 8) * u, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(9, 0) * u, c + Vector2(18, -8) * u, c + Vector2(18, 8) * u]), color.darkened(0.15))
			draw_circle(c + Vector2(-8, -2) * u, 2 * u, Color(0.1, 0.1, 0.1))
		"crab":
			var red := Color(0.9, 0.3, 0.2)
			for side in [-1, 1]:
				for k in 3:
					draw_line(c + Vector2(side * 8, 2 + k * 3) * u, c + Vector2(side * 16, 6 + k * 4) * u, red.darkened(0.2), 2.0 * u)
				draw_circle(c + Vector2(side * 14, -8) * u, 5 * u, red)
				draw_line(c + Vector2(side * 8, -2) * u, c + Vector2(side * 13, -6) * u, red, 3.0 * u)
			_ellipse(c + Vector2(0, 2) * u, Vector2(11, 8) * u, red)
			for side in [-1, 1]:
				draw_line(c + Vector2(side * 3, -4) * u, c + Vector2(side * 4, -10) * u, red.darkened(0.3), 1.5 * u)
				draw_circle(c + Vector2(side * 4, -11) * u, 2.2 * u, Color.WHITE)
				draw_circle(c + Vector2(side * 4, -11) * u, 1.1 * u, Color.BLACK)
		"jelly":
			draw_circle(c + Vector2(0, -3) * u, 11 * u, color)
			draw_rect(Rect2(c + Vector2(-11, -3) * u, Vector2(22, 4) * u), color)
			for i in 4:
				var x := (-7.5 + i * 5) * u
				draw_line(c + Vector2(x, 1 * u), c + Vector2(x + sin(i) * 2 * u, 15 * u), color.lightened(0.2), 2.0 * u)
			draw_circle(c + Vector2(-4, -4) * u, 1.8 * u, Color(0.2, 0.1, 0.25))
			draw_circle(c + Vector2(4, -4) * u, 1.8 * u, Color(0.2, 0.1, 0.25))
		"carrot":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -6) * u, c + Vector2(6, -6) * u, c + Vector2(0, 16) * u]), Color(1, 0.55, 0.15))
			for i in 3:
				draw_line(c + Vector2(0, -6) * u, c + Vector2(-6 + i * 6, -17) * u, Color(0.3, 0.7, 0.25), 3.0 * u)
		"wheat":
			draw_line(c + Vector2(0, 17) * u, c + Vector2(0, -12) * u, Color(0.75, 0.6, 0.25), 2.5 * u)
			for i in 5:
				var y := (-12 + i * 5) * u
				_ellipse(c + Vector2(-4 * u, y), Vector2(4, 2.5) * u, Color(0.95, 0.78, 0.3))
				_ellipse(c + Vector2(4 * u, y + 2 * u), Vector2(4, 2.5) * u, Color(0.95, 0.78, 0.3))
			_ellipse(c + Vector2(0, -15) * u, Vector2(2.5, 4) * u, Color(0.95, 0.78, 0.3))
		"pumpkin":
			for dx in [-7, 7, 0]:
				_ellipse(c + Vector2(dx, 3) * u, Vector2(9, 12) * u, Color(1, 0.55, 0.1) if dx != 0 else Color(1, 0.62, 0.15))
			draw_rect(Rect2(c + Vector2(-1.5, -14) * u, Vector2(3, 6) * u), Color(0.35, 0.5, 0.2))
		"coin":
			draw_circle(c, 15 * u, Color(0.95, 0.72, 0.15))
			draw_circle(c, 11 * u, Color(1, 0.84, 0.3))
			draw_rect(Rect2(c + Vector2(-2, -7) * u, Vector2(4, 14) * u), Color(0.9, 0.65, 0.15))
		"firefly":
			draw_circle(c, 14 * u, Color(1, 0.95, 0.4, 0.25))
			draw_circle(c, 8 * u, Color(1, 0.95, 0.5, 0.6))
			draw_circle(c, 4 * u, Color(1, 1, 0.8))
		"heart":
			draw_circle(c + Vector2(-6, -4) * u, 8 * u, color)
			draw_circle(c + Vector2(6, -4) * u, 8 * u, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-13.5, -1) * u, c + Vector2(13.5, -1) * u, c + Vector2(0, 15) * u]), color)
		"paw":
			_ellipse(c + Vector2(0, 6) * u, Vector2(9, 7) * u, color)
			for p in [Vector2(-10, -4), Vector2(-4, -11), Vector2(4, -11), Vector2(10, -4)]:
				_ellipse(c + p * u, Vector2(3.5, 4.5) * u, color)
		"bone":
			draw_rect(Rect2(c + Vector2(-10, -3) * u, Vector2(20, 6) * u), Color(0.95, 0.9, 0.8))
			for p in [Vector2(-11, -4), Vector2(-11, 4), Vector2(11, -4), Vector2(11, 4)]:
				draw_circle(c + p * u, 4.5 * u, Color(0.95, 0.9, 0.8))
		"berries":
			for p in [Vector2(-6, 2), Vector2(5, 3), Vector2(0, -5), Vector2(-1, 9), Vector2(8, -5)]:
				draw_circle(c + p * u, 6 * u, Color(0.45, 0.25, 0.75))
				draw_circle(c + p * u + Vector2(-2, -2) * u, 1.5 * u, Color(0.8, 0.7, 1))
			draw_line(c + Vector2(0, -10) * u, c + Vector2(4, -17) * u, Color(0.3, 0.55, 0.25), 2.5 * u)
		"mushroom":
			draw_rect(Rect2(c + Vector2(-4, -1) * u, Vector2(8, 15) * u), Color(0.95, 0.92, 0.85))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-15, 1) * u, c + Vector2(15, 1) * u, c + Vector2(9, -10) * u, c + Vector2(0, -14) * u, c + Vector2(-9, -10) * u]), Color(0.85, 0.3, 0.25))
			for p in [Vector2(-6, -6), Vector2(4, -9), Vector2(8, -3)]:
				draw_circle(c + p * u, 2 * u, Color(1, 0.95, 0.9))
		"herb":
			for i in 3:
				var x := (-6 + i * 6) * u
				draw_line(c + Vector2(x, 15 * u), c + Vector2(x * 0.6, -12 * u), Color(0.3, 0.6, 0.25), 2.0 * u)
				for k in 3:
					_ellipse(c + Vector2(x * 0.7 + (3 if k % 2 == 0 else -3) * u, (-8 + k * 7) * u), Vector2(3.5, 2) * u, Color(0.4, 0.75, 0.3))
		"shell":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 12) * u, c + Vector2(-15, -4) * u, c + Vector2(-8, -12) * u, c + Vector2(0, -14) * u, c + Vector2(8, -12) * u, c + Vector2(15, -4) * u]), Color(1, 0.8, 0.7))
			for i in 5:
				draw_line(c + Vector2(0, 12) * u, c + Vector2(-12 + i * 6, -10) * u, Color(0.9, 0.6, 0.5), 1.5 * u)
		"pearl":
			draw_circle(c, 11 * u, Color(0.95, 0.93, 0.98))
			draw_circle(c + Vector2(-4, -4) * u, 3.5 * u, Color.WHITE)
		"truffle":
			draw_circle(c + Vector2(0, 2) * u, 12 * u, Color(0.35, 0.25, 0.18))
			for p in [Vector2(-5, -3), Vector2(4, 0), Vector2(-1, 7)]:
				draw_circle(c + p * u, 2 * u, Color(0.5, 0.38, 0.28))
		"gem":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -4) * u, c + Vector2(-6, -12) * u, c + Vector2(6, -12) * u, c + Vector2(12, -4) * u, c + Vector2(0, 14) * u]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -12) * u, c + Vector2(6, -12) * u, c + Vector2(3, -4) * u, c + Vector2(-3, -4) * u]), color.lightened(0.4))
		"relic":
			draw_rect(Rect2(c + Vector2(-9, -13) * u, Vector2(18, 26) * u), Color(0.65, 0.5, 0.3))
			draw_rect(Rect2(c + Vector2(-6, -10) * u, Vector2(12, 20) * u), Color(0.8, 0.65, 0.35))
			draw_circle(c, 4 * u, Color(0.3, 0.7, 0.8))
		"bottle":
			draw_rect(Rect2(c + Vector2(-7, -4) * u, Vector2(14, 18) * u), Color(0.5, 0.8, 0.6, 0.85))
			draw_rect(Rect2(c + Vector2(-3, -14) * u, Vector2(6, 10) * u), Color(0.5, 0.8, 0.6, 0.85))
			draw_rect(Rect2(c + Vector2(-3.5, -17) * u, Vector2(7, 4) * u), Color(0.6, 0.45, 0.3))
			draw_rect(Rect2(c + Vector2(-4, 0) * u, Vector2(8, 10) * u), Color(0.95, 0.9, 0.75))
		"map":
			draw_rect(Rect2(c + Vector2(-14, -11) * u, Vector2(28, 22) * u), Color(0.93, 0.85, 0.65))
			draw_line(c + Vector2(-10, 6) * u, c + Vector2(-2, -2) * u, Color(0.6, 0.45, 0.3), 1.5 * u)
			draw_line(c + Vector2(-2, -2) * u, c + Vector2(6, 2) * u, Color(0.6, 0.45, 0.3), 1.5 * u)
			draw_line(c + Vector2(5, -6) * u, c + Vector2(11, 0) * u, Color(0.85, 0.2, 0.15), 2.5 * u)
			draw_line(c + Vector2(11, -6) * u, c + Vector2(5, 0) * u, Color(0.85, 0.2, 0.15), 2.5 * u)
		"piano":
			draw_rect(Rect2(c + Vector2(-15, -8) * u, Vector2(30, 18) * u), Color(0.95, 0.95, 0.95))
			for i in 6:
				draw_line(c + Vector2(-15 + i * 5, -8) * u, c + Vector2(-15 + i * 5, 10) * u, Color(0.3, 0.3, 0.3), 1.0 * u)
			for i in [0, 1, 3, 4]:
				draw_rect(Rect2(c + Vector2(-12 + i * 5, -8) * u, Vector2(3, 10) * u), Color(0.1, 0.1, 0.1))
		"guitar":
			draw_circle(c + Vector2(-3, 6) * u, 9 * u, Color(0.8, 0.5, 0.25))
			draw_circle(c + Vector2(2, -1) * u, 6.5 * u, Color(0.8, 0.5, 0.25))
			draw_circle(c + Vector2(-3, 6) * u, 3 * u, Color(0.3, 0.2, 0.1))
			draw_line(c + Vector2(0, 2) * u, c + Vector2(13, -15) * u, Color(0.4, 0.28, 0.15), 3.5 * u)
		"flute":
			draw_line(c + Vector2(-15, 10) * u, c + Vector2(15, -10) * u, Color(0.75, 0.55, 0.3), 5.0 * u)
			for i in 4:
				draw_circle(c + Vector2(-6 + i * 5, 4 - i * 3.3) * u, 1.3 * u, Color(0.3, 0.2, 0.1))
		"telescope":
			draw_line(c + Vector2(-12, 5) * u, c + Vector2(12, -9) * u, Color(0.55, 0.45, 0.7), 7.0 * u)
			draw_line(c + Vector2(0, 0) * u, c + Vector2(-7, 15) * u, Color(0.4, 0.3, 0.2), 2.0 * u)
			draw_line(c + Vector2(0, 0) * u, c + Vector2(7, 15) * u, Color(0.4, 0.3, 0.2), 2.0 * u)
			draw_circle(c + Vector2(13, -12) * u, 2 * u, Color(1, 0.95, 0.6))
		"wood_log":
			for k in 3:
				var off := Vector2([-7, 7, 0][k], [6, 6, -5][k])
				_ellipse(c + off * u, Vector2(8, 5.5) * u, Color(0.6, 0.42, 0.25))
				_ellipse(c + off * u + Vector2(5, 0) * u, Vector2(3.5, 5) * u, Color(0.85, 0.7, 0.45))
				draw_circle(c + off * u + Vector2(5, 0) * u, 1.4 * u, Color(0.6, 0.42, 0.25))
		"stone":
			_ellipse(c + Vector2(0, 2) * u, Vector2(13, 6) * u, Color(0.55, 0.57, 0.6))
			_ellipse(c + Vector2(-2, 0) * u, Vector2(9, 3) * u, Color(0.68, 0.7, 0.72))
		"tomato":
			draw_circle(c + Vector2(0, 3) * u, 13 * u, Color(0.9, 0.18, 0.12))
			draw_circle(c + Vector2(-5, -2) * u, 3.5 * u, Color(1, 0.5, 0.45))
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2
				draw_line(c + Vector2(0, -9) * u, c + Vector2(0, -9) * u + Vector2(cos(a), sin(a) * 0.5) * 7 * u, Color(0.25, 0.6, 0.2), 2.5 * u)
		"strawberry":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -6) * u, c + Vector2(12, -6) * u, c + Vector2(0, 16) * u]), Color(0.92, 0.2, 0.28))
			draw_circle(c + Vector2(-6, -5) * u, 6 * u, Color(0.92, 0.2, 0.28))
			draw_circle(c + Vector2(6, -5) * u, 6 * u, Color(0.92, 0.2, 0.28))
			for p in [Vector2(-5, 0), Vector2(4, 1), Vector2(0, 6), Vector2(-2, -4), Vector2(6, -5), Vector2(-7, -6)]:
				draw_circle(c + p * u, 1.1 * u, Color(1, 0.9, 0.5))
			for i in 4:
				draw_line(c + Vector2(0, -10) * u, c + Vector2(-9 + i * 6, -15) * u, Color(0.25, 0.6, 0.2), 3.0 * u)
		"corn":
			_ellipse(c + Vector2(0, 1) * u, Vector2(7, 14) * u, Color(1, 0.85, 0.25))
			for row in 5:
				for col in 2:
					draw_circle(c + Vector2(-2.5 + col * 5, -9 + row * 4.5) * u, 1.6 * u, Color(0.95, 0.72, 0.15))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 16) * u, c + Vector2(-13, -6) * u, c + Vector2(-4, 4) * u]), Color(0.35, 0.65, 0.25))
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, 16) * u, c + Vector2(13, -6) * u, c + Vector2(4, 4) * u]), Color(0.35, 0.65, 0.25))
		"pot":
			draw_rect(Rect2(c + Vector2(-13, -4) * u, Vector2(26, 16) * u), Color(0.35, 0.35, 0.4))
			_ellipse(c + Vector2(0, -4) * u, Vector2(13, 4) * u, color)
			draw_rect(Rect2(c + Vector2(-17, -3) * u, Vector2(4, 3) * u), Color(0.25, 0.25, 0.3))
			draw_rect(Rect2(c + Vector2(13, -3) * u, Vector2(4, 3) * u), Color(0.25, 0.25, 0.3))
			for i in 3:
				var x := (-6 + i * 6) * u
				draw_arc(c + Vector2(x, -12 * u), 3 * u, PI * 0.5, PI * 1.5, 6, Color(1, 1, 1, 0.6), 1.5 * u)
		"pie":
			_ellipse(c + Vector2(0, 5) * u, Vector2(16, 7) * u, Color(0.8, 0.55, 0.25))
			_ellipse(c + Vector2(0, 1) * u, Vector2(15, 6) * u, color)
			for i in 5:
				var x := (-10 + i * 5) * u
				draw_line(c + Vector2(x, -3 * u), c + Vector2(x + 2 * u, 5 * u), Color(0.95, 0.8, 0.5), 2.0 * u)
		"cake":
			draw_rect(Rect2(c + Vector2(-13, -4) * u, Vector2(26, 16) * u), Color(1, 0.92, 0.85))
			draw_rect(Rect2(c + Vector2(-13, 3) * u, Vector2(26, 3) * u), color)
			_ellipse(c + Vector2(0, -4) * u, Vector2(13, 4) * u, Color(1, 0.97, 0.95))
			draw_circle(c + Vector2(0, -9) * u, 3.5 * u, Color(0.92, 0.2, 0.28))
		"boot":
			draw_rect(Rect2(c + Vector2(-7, -15) * u, Vector2(10, 22) * u), Color(0.4, 0.3, 0.2))
			draw_rect(Rect2(c + Vector2(-7, 5) * u, Vector2(20, 9) * u), Color(0.4, 0.3, 0.2))
			draw_rect(Rect2(c + Vector2(-8, 12) * u, Vector2(22, 3) * u), Color(0.2, 0.15, 0.1))
		"can":
			draw_rect(Rect2(c + Vector2(-8, -12) * u, Vector2(16, 24) * u), Color(0.7, 0.72, 0.75))
			draw_rect(Rect2(c + Vector2(-8, -4) * u, Vector2(16, 8) * u), Color(0.85, 0.25, 0.2))
		"block":
			draw_rect(Rect2(c + Vector2(-13, -13) * u, Vector2(26, 26) * u), color)
			draw_rect(Rect2(c + Vector2(-13, -13) * u, Vector2(26, 5) * u), color.lightened(0.3))
			draw_circle(c, 5 * u, color.lightened(0.45))
		"drop":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -17) * u, c + Vector2(-9, 2) * u, c + Vector2(9, 2) * u]), color)
			draw_circle(c + Vector2(0, 5) * u, 10 * u, color)
			draw_circle(c + Vector2(-4, 4) * u, 3 * u, color.lightened(0.5))
		"hat":
			_ellipse(c + Vector2(0, 9) * u, Vector2(17, 5) * u, color.darkened(0.15))
			draw_rect(Rect2(c + Vector2(-9, -9) * u, Vector2(18, 18) * u), color)
			_ellipse(c + Vector2(0, -9) * u, Vector2(9, 3) * u, color.lightened(0.15))
			draw_rect(Rect2(c + Vector2(-9, 3) * u, Vector2(18, 4) * u), Color(0.85, 0.25, 0.25))
		"note":
			for dx in [-7, 7]:
				_ellipse(c + Vector2(dx - 3, 10) * u, Vector2(5, 4) * u, color)
				draw_line(c + Vector2(dx + 1.5, 10) * u, c + Vector2(dx + 1.5, -12) * u, color, 2.5 * u)
			draw_line(c + Vector2(-5.5, -12) * u, c + Vector2(8.5, -14) * u, color, 5.0 * u)
		"flag":
			draw_line(c + Vector2(-8, 16) * u, c + Vector2(-8, -16) * u, Color(0.9, 0.9, 0.9), 3.0 * u)
			for row in 3:
				for col in 4:
					var col_c := Color.WHITE if (row + col) % 2 == 0 else Color(0.1, 0.1, 0.1)
					draw_rect(Rect2(c + Vector2(-7 + col * 5, -16 + row * 5) * u, Vector2(5, 5) * u), col_c)
		_:
			var pts := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0 - PI / 2
				var r := (16 if i % 2 == 0 else 7) * u
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(1, 0.85, 0.3))


func _ellipse(center: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
