# MIT License
#
# Copyright (c) 2023 Mark McKay
# https://github.com/blackears/godotSolitaire
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



extends Node2D
class_name CardBody

signal drag_start
signal selected

@export var card_width:float = 120:
	get:
		return card_width
	set(value):
		card_width = value
		dirty = true

@export var card_height:float = 168:
	get:
		return card_height
	set(value):
		card_height = value
		dirty = true
		
@export var face_up:bool = true:
	get:
		return face_up
	set(value):
		face_up= value
		dirty = true

@export var card_back:Texture2D:
	get:
		return card_back
	set(value):
		card_back = value
		dirty = true

@export var card:Card:
	get:
		return card
	set(value):
		card = value
		dirty = true

@export var pickable:bool = true:
	get:
		return pickable
	set(value):
		pickable = value
		dirty = true


var dirty:bool = true
var mouse_down_pos:Vector2

enum State { IDLE, READY, DRAGGING }
var state = State.IDLE

func get_parent_stack()->CardStackBody:

	var node:Node = get_parent()
	while node:
		if node is CardStackBody:
			return node
		node = node.get_parent()
			
	return null

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(_delta):
	if dirty:
		var shape:RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(card_width, card_height)
		$Area2D/CollisionShape2D.shape = shape
		$Area2D/CollisionShape2D.position = Vector2(0, 0)
		$Area2D.input_pickable = pickable
		$pick_rect.width = card_width
		$pick_rect.height = card_height
		queue_redraw()
		dirty = false
		
func _draw():
	var image:Texture2D
	if face_up:
		if card:
			if GameState.cowboy_faces:
				image = GameState.cowboy_face(card.rank, card.suit)
			if image == null:
				image = card.image
	else:
		image = card_back

	if image:
		draw_texture_rect(image, Rect2(Vector2(0, 0), Vector2(card_width, card_height)), false)



func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		var e:InputEventMouseButton = event

		if e.is_pressed():
			if state == State.IDLE:
				state = State.READY
				mouse_down_pos = e.position
		else:
			if state == State.READY:
				state = State.IDLE
				selected.emit()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var e:InputEventMouseMotion = event

		if state == State.READY:
			if e.position.distance_to(mouse_down_pos) > 6:
				state = State.IDLE
				drag_start.emit()
		get_viewport().set_input_as_handled()
