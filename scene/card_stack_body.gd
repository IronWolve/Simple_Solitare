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
class_name CardStackBody

# -1 if selection when stack is empty
signal selected(card_idx:int)
signal drag_started(card_idx:int)
#signal drop()


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

@export var cards:Array[Card]:
	get:
		return cards
	set(value):
		cards = value
		dirty = true

@export var card_back:Texture2D:
	get:
		return card_back
	set(value):
		card_back = value
		dirty = true
		
@export var card_offset:Vector2 = Vector2(16, 0):
	get:
		return card_offset
	set(value):
		card_offset = value
		dirty = true

@export var face_up:bool = true:
	get:
		return face_up
	set(value):
		face_up = value
		dirty = true

@export var pickable:bool = true:
	get:
		return pickable
	set(value):
		pickable = value
		dirty = true

@export var display_count: int = -1:
	get:
		return display_count
	set(value):
		display_count = value
		dirty = true

@export var face_up_top_only: bool = false:
	get:
		return face_up_top_only
	set(value):
		face_up_top_only = value
		dirty = true

var dirty:bool = true
var mouse_down_pos:Vector2
var drag_start_pos:Vector2

enum State { IDLE, READY, DRAGGING }
var state = State.IDLE

func _can_drop(drop_cards:Array[Card])->bool:
	return false

func _drop(drop_stack:CardStackBody):
	pass

func _effective_pickable() -> bool:
	return pickable

func _process(_delta):
	if dirty:
		dirty = false
		for child in $cards.get_children():
			child.queue_free()

		queue_redraw()
		$pick_rect.width = card_width
		$pick_rect.height = card_height
		$pick_rect.pickable = _effective_pickable()

		var start_idx: int = 0
		if display_count > 0:
			start_idx = max(0, cards.size() - display_count)

		for c_idx in range(start_idx, cards.size()):
			var card:Card = cards[c_idx]
			if card:
				var card_body:CardBody = preload("res://scene/card_body.tscn").instantiate()
				var disp_idx: int = c_idx - start_idx

				$cards.add_child(card_body)
				card_body.card = card
				card_body.card_width = card_width
				card_body.card_height = card_height
				card_body.card_back = card_back
				card_body.face_up = (c_idx == cards.size() - 1) if face_up_top_only else face_up
				card_body.pickable = pickable
				card_body.name = str(Card.to_string_suit(card.suit)) + "_" + str(Card.to_string_rank(card.rank)) + "_" + str(c_idx)

				card_body.get_node("Area2D").z_index = c_idx
				card_body.position = card_offset * disp_idx

				card_body.selected.connect(func(): on_card_selected(c_idx))
				card_body.drag_start.connect(func(): on_card_drag_started(c_idx))

	

func notify_card_selected_by_idx(idx:int):
	selected.emit(idx)

func on_card_selected(_index:int):
	pass

func on_card_drag_started(_index:int):
	pass

