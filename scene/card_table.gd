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
class_name CardTable

enum State { IDLE, READY, DRAGGING }
var state = State.IDLE

var mouse_down_pos:Vector2
var chosen_card_stack:CardStackBody
var chosen_card_idx:int = -1

var undo_stack: Array = []
var draw_count: int = 3

var panning: bool = false
var game_time: float = 0.0
var timer_running: bool = false
var current_seed: int = 0
var tip_index: int = -1
var _status_token: int = 0

const BACK_BLUE = "res://art/svg_playing_cards/backs/blue-card-background.jpg"
const BACK_RED  = "res://art/svg_playing_cards/backs/red-card-background.jpg"
const BACK_COWBOY = "res://art/cowboy/cowboy-back.png"

var current_back: String = BACK_BLUE

func _ready():
	randomize()
	_apply_deck()
	RenderingServer.set_default_clear_color(Color(0.05, 0.22, 0.05))
	$UI/lbl_title.text = "Simple Solitaire - " + GameState.variant_name() + " v. 9"
	$hand.face_up_top_only = true
	$hand.display_count = draw_count
	$hand.card_offset = Vector2(15, 0)
	get_viewport().size_changed.connect(_update_camera_y)
	_update_camera_y()
	_deal(false)


func _process(_delta):
	if timer_running:
		game_time += _delta
		$UI/lbl_timer.text = "Time: " + _format_time(game_time)


func _format_time(t: float) -> String:
	var s = int(t)
	return "%02d:%02d" % [s / 60, s % 60]

func _update_camera_y():
	# Keep world y=400 (top card row) at screen y=80 (just below UI bar)
	var viewport_h = get_viewport().get_visible_rect().size.y
	$Camera2D.position.y = 400 - 80 + viewport_h / 2.0

func _all_stacks() -> Array:
	return [$draw_pile, $hand, $drag_column,
		$goal_0, $goal_1, $goal_2, $goal_3,
		$col_down_0, $col_down_1, $col_down_2, $col_down_3, $col_down_4, $col_down_5, $col_down_6,
		$col_up_0, $col_up_1, $col_up_2, $col_up_3, $col_up_4, $col_up_5, $col_up_6]

func _set_card_back(path: String):
	var tex: Texture2D = load(path)
	for s in _all_stacks():
		s.card_back = tex

func _apply_deck():
	_set_card_back(current_back)

func _on_bn_deck_pressed():
	$UI/popup_deck.popup_centered()

func _on_deck_blue_pressed():
	current_back = BACK_BLUE
	_apply_deck()
	$UI/popup_deck.hide()

func _on_deck_red_pressed():
	current_back = BACK_RED
	_apply_deck()
	$UI/popup_deck.hide()


func _on_deck_cowboy_back_pressed():
	current_back = BACK_COWBOY
	_apply_deck()
	$UI/popup_deck.hide()


func _on_deck_normal_pressed():
	GameState.cowboy_faces = false
	_apply_deck()
	$UI/popup_deck.hide()


func _on_deck_cowboy_pressed():
	GameState.cowboy_faces = true
	_apply_deck()
	$UI/popup_deck.hide()

func pick_card_or_pile(pos_world:Vector2)->Node:
	var picked_obj:PickRect = GeneralUtil.node_depth_search_first(self, func(node:Node):
			if node is PickRect:
				var pr:PickRect = node
				var pos_local:Vector2 = pr.global_transform.affine_inverse() * pos_world
				return pr.can_pick(pos_local)
			return false,
		func (node:Node) :
			if !node.visible:
				return false
			if node == $drag_column:
				return false
			return true,
		true)
		
	return picked_obj.get_parent() if picked_obj else null


func _unhandled_input(event):
	if event is InputEventMouseButton:
		var e:InputEventMouseButton = event

		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.is_pressed():
			_zoom_camera(1.1, get_viewport().get_mouse_position())
			get_viewport().set_input_as_handled()
			return
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.is_pressed():
			_zoom_camera(1.0 / 1.1, get_viewport().get_mouse_position())
			get_viewport().set_input_as_handled()
			return

		if e.button_index == MOUSE_BUTTON_RIGHT:
			panning = e.is_pressed()
			get_viewport().set_input_as_handled()
			return

		if e.button_index != MOUSE_BUTTON_LEFT:
			return

		if e.is_pressed():
			$TipArrow.clear()
			var chosen_obj = pick_card_or_pile(get_global_mouse_position())
			if chosen_obj is CardStackBody:
				chosen_card_stack = chosen_obj
				chosen_card_idx = -1
				state = State.READY
				mouse_down_pos = e.position
			elif chosen_obj is CardBody:
				var card_body := chosen_obj as CardBody
				chosen_card_stack = card_body.get_parent_stack()
				var cards_node = chosen_card_stack.get_node_or_null("cards")
				var disp_idx = cards_node.get_children().find(card_body) if cards_node else -1
				if disp_idx >= 0:
					var dc = chosen_card_stack.display_count
					var start = max(0, chosen_card_stack.cards.size() - dc) if dc > 0 else 0
					chosen_card_idx = disp_idx + start
				else:
					chosen_card_idx = -1
				state = State.READY
				mouse_down_pos = e.position

		else:
			if state == State.READY:
				state = State.IDLE
				if chosen_card_stack:
					chosen_card_stack.notify_card_selected_by_idx(chosen_card_idx)

			elif state == State.DRAGGING:
				var drop_obj = pick_card_or_pile(get_global_mouse_position())
				var stack:CardStackBody

				if drop_obj is CardStackBody:
					stack = drop_obj
				elif drop_obj is CardBody:
					stack = (drop_obj as CardBody).get_parent_stack()

				if stack:
					var drag_cards:Array[Card] = $drag_column.cards
					if stack._can_drop(drag_cards):
						stack._drop($drag_column)
						_flip_col_down_if_needed(chosen_card_stack)
						check_win()
					else:
						cancel_drop()
				else:
					cancel_drop()

				state = State.IDLE

		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var e:InputEventMouseMotion = event

		if panning:
			$Camera2D.position -= e.relative / $Camera2D.zoom
			get_viewport().set_input_as_handled()
			return

		if state == State.READY:
			if e.position.distance_to(mouse_down_pos) > 6:
				state = State.DRAGGING
				if chosen_card_stack:
					save_state()
					chosen_card_stack.drag_started.emit(chosen_card_idx)
					$drag_column.position = get_global_mouse_position() - Vector2($drag_column.card_width / 2.0, $drag_column.card_height / 4.0)
		elif state == State.DRAGGING:
			$drag_column.position = get_global_mouse_position() - Vector2($drag_column.card_width / 2.0, $drag_column.card_height / 4.0)

		get_viewport().set_input_as_handled()


func cancel_drop():
	var col_cards:Array[Card] = $drag_column.cards
	
	if !col_cards.is_empty():
		
		var source_cards:Array[Card] = chosen_card_stack.cards
		source_cards.append_array(col_cards)
		chosen_card_stack.cards = source_cards
		
		col_cards.clear()
		$drag_column.cards = col_cards
		

func _on_draw_pile_selected(card_idx):
	save_state()
	var draw_cards:Array[Card] = $draw_pile.cards
	if draw_cards.is_empty():
		$draw_pile.cards = $hand.cards.duplicate()
		var e:Array[Card] = []
		$hand.cards = e
	else:
		var n = min(draw_count, draw_cards.size())
		var new_hand:Array[Card] = $hand.cards.duplicate()
		new_hand.append_array(draw_cards.slice(0, n))
		$hand.cards = new_hand
		$draw_pile.cards = draw_cards.slice(n)


func _on_draw_pile_drag_started(_card_idx):
	pass


func _on_hand_drag_started(_card_idx):
	var cur_hand:Array[Card] = $hand.cards.duplicate()
	if not cur_hand.is_empty():
		var drag_card:Card = cur_hand.pop_back()
		$hand.cards = cur_hand
		var drag_arr:Array[Card] = []
		drag_arr.append(drag_card)
		$drag_column.cards = drag_arr


func _on_hand_selected(card_idx):
	var cur_hand:Array[Card] = $hand.cards
	if not cur_hand.is_empty() and card_idx == cur_hand.size() - 1:
		try_auto_move_to_goal($hand)


func _on_bn_new_game_pressed():
	_deal(false)


func _deal(same: bool):
	if not same:
		current_seed = randi()
	seed(current_seed)
	game_time = 0.0
	timer_running = true
	tip_index = -1
	$TipArrow.clear()
	$UI/lbl_win.visible = false
	undo_stack.clear()
	var deck:CardStack = preload("res://data/standard_deck.tres")

	var local_deck:CardStack = deck.duplicate(true)
	local_deck.shuffle()

	$col_down_0.cards = local_deck.draw_cards(0)
	$col_down_1.cards = local_deck.draw_cards(1)
	$col_down_2.cards = local_deck.draw_cards(2)
	$col_down_3.cards = local_deck.draw_cards(3)
	$col_down_4.cards = local_deck.draw_cards(4)
	$col_down_5.cards = local_deck.draw_cards(5)
	$col_down_6.cards = local_deck.draw_cards(6)

	$col_up_0.cards = local_deck.draw_cards(1)
	$col_up_1.cards = local_deck.draw_cards(1)
	$col_up_2.cards = local_deck.draw_cards(1)
	$col_up_3.cards = local_deck.draw_cards(1)
	$col_up_4.cards = local_deck.draw_cards(1)
	$col_up_5.cards = local_deck.draw_cards(1)
	$col_up_6.cards = local_deck.draw_cards(1)

	var e:Array[Card] = []
	$goal_0.cards = e.duplicate()
	$goal_1.cards = e.duplicate()
	$goal_2.cards = e.duplicate()
	$goal_3.cards = e.duplicate()
	$hand.cards = e.duplicate()
	$drag_column.cards = e.duplicate()

	$draw_pile.cards = local_deck.cards


func try_auto_move_to_goal(source_stack:CardStackBody):
	if source_stack.cards.is_empty():
		return
	var top_card:Card = source_stack.cards.back()
	var top_arr:Array[Card] = []
	top_arr.append(top_card)
	for goal in [$goal_0, $goal_1, $goal_2, $goal_3]:
		if goal._can_drop(top_arr):
			save_state()
			var src:Array[Card] = source_stack.cards.duplicate()
			src.pop_back()
			source_stack.cards = src
			var goal_cards:Array[Card] = goal.cards.duplicate()
			goal_cards.append(top_card)
			goal.cards = goal_cards
			_flip_col_down_if_needed(source_stack)
			check_win()
			return


func check_win():
	if $goal_0.cards.size() == 13 and $goal_1.cards.size() == 13 \
			and $goal_2.cards.size() == 13 and $goal_3.cards.size() == 13:
		timer_running = false
		$UI/lbl_win.text = "You Win!"
		$UI/lbl_win.visible = true


func _flip_col_down_if_needed(stack: CardStackBody):
	if not stack is ColumnUpStack:
		return
	if not stack.cards.is_empty():
		return
	var col_down_name = stack.name.replace("col_up_", "col_down_")
	var col_down = get_node_or_null(col_down_name)
	if col_down is ColumnDownStack and not col_down.cards.is_empty():
		var down_cards: Array[Card] = col_down.cards.duplicate()
		var flipped: Card = down_cards.pop_back()
		col_down.cards = down_cards
		var flipped_arr: Array[Card] = []
		flipped_arr.append(flipped)
		stack.cards = flipped_arr


func _on_bn_draw_toggle_pressed():
	if draw_count == 3:
		draw_count = 1
		$UI/bn_draw_toggle.text = "Draw: 1"
	else:
		draw_count = 3
		$UI/bn_draw_toggle.text = "Draw: 3"
	$hand.display_count = draw_count



func _on_bn_undo_pressed():
	if undo_stack.is_empty():
		return
	restore_state(undo_stack.pop_back())


func _on_bn_background_pressed():
	$UI/popup_background.popup_centered()


func _on_cpb_background_color_changed(color: Color):
	RenderingServer.set_default_clear_color(color)


func _on_bn_restart_pressed():
	$UI/popup_restart.popup_centered()


func _on_bn_help_pressed():
	$UI/popup_help.popup_centered()


func _show_status(msg: String):
	$UI/lbl_status.text = msg
	$UI/lbl_status.visible = true
	_status_token += 1
	var my := _status_token
	await get_tree().create_timer(2.5).timeout
	if my == _status_token and is_inside_tree():
		$UI/lbl_status.visible = false


func _find_moves() -> Array:
	var moves := []
	var sources := [$hand, $col_up_0, $col_up_1, $col_up_2, $col_up_3, $col_up_4, $col_up_5, $col_up_6]
	var dests := [$goal_0, $goal_1, $goal_2, $goal_3,
		$col_up_0, $col_up_1, $col_up_2, $col_up_3, $col_up_4, $col_up_5, $col_up_6,
		$col_down_0, $col_down_1, $col_down_2, $col_down_3, $col_down_4, $col_down_5, $col_down_6]
	for src in sources:
		var n = src.cards.size()
		if n == 0:
			continue
		var idx_list := []
		if src == $hand:
			idx_list = [n - 1]
		else:
			for i in n:
				idx_list.append(i)
		for idx in idx_list:
			var cand: Array[Card] = src.cards.slice(idx)
			for dst in dests:
				if dst == src:
					continue
				if dst._can_drop(cand):
					moves.append({"from": src, "from_idx": idx, "to": dst})
	return moves


func _card_center(stack, idx: int) -> Vector2:
	var dc = stack.display_count
	var start = max(0, stack.cards.size() - dc) if dc > 0 else 0
	var disp = max(0, idx - start)
	return stack.position + stack.card_offset * disp + Vector2(stack.card_width, stack.card_height) / 2.0


func _dest_center(stack) -> Vector2:
	if stack.cards.is_empty():
		return stack.position + Vector2(stack.card_width, stack.card_height) / 2.0
	return _card_center(stack, stack.cards.size() - 1)


func _on_bn_tip_pressed():
	var moves := _find_moves()
	if moves.is_empty():
		$TipArrow.clear()
		_show_status("No card moves available")
		return
	tip_index = (tip_index + 1) % moves.size()
	var m = moves[tip_index]
	$TipArrow.show_arrow(_card_center(m["from"], m["from_idx"]), _dest_center(m["to"]))


func _on_restart_new_pressed():
	$UI/popup_restart.hide()
	_deal(false)


func _on_restart_same_pressed():
	$UI/popup_restart.hide()
	_deal(true)


func _on_bn_style_pressed():
	$UI/popup_style.popup_centered()


func _switch_variant(v):
	GameState.variant = v
	if v == GameState.Variant.KLONDIKE:
		get_tree().change_scene_to_file("res://scene/card_table.tscn")
	else:
		get_tree().change_scene_to_file("res://scene/spider_table.tscn")


func _on_style_klondike_pressed():
	_switch_variant(GameState.Variant.KLONDIKE)


func _on_style_spider1_pressed():
	_switch_variant(GameState.Variant.SPIDER_1)


func _on_style_spider2_pressed():
	_switch_variant(GameState.Variant.SPIDER_2)


func _on_style_spider4_pressed():
	_switch_variant(GameState.Variant.SPIDER_4)


func save_state():
	var s = {
		"draw_pile": $draw_pile.cards.duplicate(),
		"hand": $hand.cards.duplicate(),
		"goal_0": $goal_0.cards.duplicate(),
		"goal_1": $goal_1.cards.duplicate(),
		"goal_2": $goal_2.cards.duplicate(),
		"goal_3": $goal_3.cards.duplicate(),
		"col_down_0": $col_down_0.cards.duplicate(),
		"col_down_1": $col_down_1.cards.duplicate(),
		"col_down_2": $col_down_2.cards.duplicate(),
		"col_down_3": $col_down_3.cards.duplicate(),
		"col_down_4": $col_down_4.cards.duplicate(),
		"col_down_5": $col_down_5.cards.duplicate(),
		"col_down_6": $col_down_6.cards.duplicate(),
		"col_up_0": $col_up_0.cards.duplicate(),
		"col_up_1": $col_up_1.cards.duplicate(),
		"col_up_2": $col_up_2.cards.duplicate(),
		"col_up_3": $col_up_3.cards.duplicate(),
		"col_up_4": $col_up_4.cards.duplicate(),
		"col_up_5": $col_up_5.cards.duplicate(),
		"col_up_6": $col_up_6.cards.duplicate(),
	}
	undo_stack.append(s)


func restore_state(s: Dictionary):
	$draw_pile.cards = s["draw_pile"]
	$hand.cards = s["hand"]
	$goal_0.cards = s["goal_0"]
	$goal_1.cards = s["goal_1"]
	$goal_2.cards = s["goal_2"]
	$goal_3.cards = s["goal_3"]
	$col_down_0.cards = s["col_down_0"]
	$col_down_1.cards = s["col_down_1"]
	$col_down_2.cards = s["col_down_2"]
	$col_down_3.cards = s["col_down_3"]
	$col_down_4.cards = s["col_down_4"]
	$col_down_5.cards = s["col_down_5"]
	$col_down_6.cards = s["col_down_6"]
	$col_up_0.cards = s["col_up_0"]
	$col_up_1.cards = s["col_up_1"]
	$col_up_2.cards = s["col_up_2"]
	$col_up_3.cards = s["col_up_3"]
	$col_up_4.cards = s["col_up_4"]
	$col_up_5.cards = s["col_up_5"]
	$col_up_6.cards = s["col_up_6"]
	var empty: Array[Card] = []
	$drag_column.cards = empty


func _zoom_camera(factor: float, screen_pos: Vector2):
	var old_zoom = $Camera2D.zoom
	var new_zoom = (old_zoom * factor).clamp(Vector2(0.5, 0.5), Vector2(4.0, 4.0))
	if new_zoom == old_zoom:
		return
	var viewport_center = get_viewport_rect().size / 2.0
	var world_at_cursor = $Camera2D.position + (screen_pos - viewport_center) / old_zoom
	$Camera2D.zoom = new_zoom
	$Camera2D.position = world_at_cursor - (screen_pos - viewport_center) / new_zoom

