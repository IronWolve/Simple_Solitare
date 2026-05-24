extends Node2D

var active: bool = false
var from_pos: Vector2
var to_pos: Vector2


func show_arrow(f: Vector2, t: Vector2):
	from_pos = f
	to_pos = t
	active = true
	queue_redraw()


func clear():
	if active:
		active = false
		queue_redraw()


func _draw():
	if not active:
		return
	var yellow := Color(1.0, 0.9, 0.1)
	var black := Color(0.0, 0.0, 0.0)
	var diff := to_pos - from_pos
	if diff.length() < 1.0:
		return
	var dir := diff.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var head := 28.0
	var base := to_pos - dir * head
	var p0 := to_pos
	var p1 := base + perp * head * 0.5
	var p2 := base - perp * head * 0.5
	var centroid := (p0 + p1 + p2) / 3.0
	var k := 1.4
	# black outline
	draw_line(from_pos, base, black, 11.0)
	draw_colored_polygon(PackedVector2Array([
		centroid + (p0 - centroid) * k,
		centroid + (p1 - centroid) * k,
		centroid + (p2 - centroid) * k,
	]), black)
	# yellow fill on top
	draw_line(from_pos, base, yellow, 6.0)
	draw_colored_polygon(PackedVector2Array([p0, p1, p2]), yellow)
