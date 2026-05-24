extends Node2D
class_name SpiderTable

enum State { IDLE, READY, DRAGGING }
var state = State.IDLE

var mouse_down_pos:Vector2
var chosen_card_stack:CardStackBody
var chosen_card_idx:int = -1

var undo_stack: Array = []
var completed_runs: int = 0

var panning: bool = false
var game_time: float = 0.0
var timer_running: bool = false
var current_seed: int = 0
var _status_token: int = 0
var tip_index: int = -1

const BACK_BLUE = "res://art/svg_playing_cards/backs/blue-card-background.jpg"
const BACK_RED  = "res://art/svg_playing_cards/backs/red-card-background.jpg"
const BACK_COWBOY = "res://art/cowboy/cowboy-back.png"

var current_back: String = BACK_BLUE

@onready var columns_down = [$col_down_0, $col_down_1, $col_down_2, $col_down_3, $col_down_4,
	$col_down_5, $col_down_6, $col_down_7, $col_down_8, $col_down_9]
@onready var columns_up = [$col_up_0, $col_up_1, $col_up_2, $col_up_3, $col_up_4,
	$col_up_5, $col_up_6, $col_up_7, $col_up_8, $col_up_9]
@onready var foundations = [$found_0, $found_1, $found_2, $found_3,
	$found_4, $found_5, $found_6, $found_7]


func _ready():
	randomize()
	_apply_deck()
	RenderingServer.set_default_clear_color(Color(0.05, 0.22, 0.05))
	$UI/lbl_title.text = "Simple Solitaire - " + GameState.variant_name() + " v. 9"
	get_viewport().size_changed.connect(_update_camera_y)
	_update_camera_y()
	_new_game(false)


func _process(_delta):
	if timer_running:
		game_time += _delta
		$UI/lbl_timer.text = "Time: " + _format_time(game_time)


func _format_time(t: float) -> String:
	var s = int(t)
	return "%02d:%02d" % [s / 60, s % 60]


func _update_camera_y():
	# Keep world y=400 (foundation row) at screen y=80, accounting for camera zoom
	var viewport_h = get_viewport().get_visible_rect().size.y
	var z = $Camera2D.zoom.y
	$Camera2D.position.y = 400 - (80 - viewport_h / 2.0) / z


func _all_stacks() -> Array:
	var a := [$stock, $drag_column]
	a.append_array(foundations)
	a.append_array(columns_down)
	a.append_array(columns_up)
	return a

func _set_card_back(path: String):
	var tex: Texture2D = load(path)
	for s in _all_stacks():
		s.card_back = tex

func _apply_deck():
	_set_card_back(current_back)


func _build_deck() -> Array[Card]:
	var suits:Array
	match GameState.spider_suits():
		1:
			suits = ["spade"]
		2:
			suits = ["spade", "heart"]
		_:
			suits = ["club", "diamond", "heart", "spade"]
	var ranks = ["a", "2", "3", "4", "5", "6", "7", "8", "9", "10", "j", "q", "k"]
	var copies = 104 / (suits.size() * 13)
	var deck:Array[Card] = []
	for c in copies:
		for s in suits:
			for r in ranks:
				deck.append(load("res://data/card_%s_%s.tres" % [s, r]))
	return deck


func _new_game(same: bool = false):
	if not same:
		current_seed = randi()
	seed(current_seed)
	game_time = 0.0
	timer_running = true
	tip_index = -1
	$TipArrow.clear()
	$UI/lbl_win.visible = false
	undo_stack.clear()
	completed_runs = 0

	var cs := CardStack.new()
	cs.cards = _build_deck()
	cs.shuffle()

	for i in 10:
		var down_count = 5 if i < 4 else 4
		columns_down[i].cards = cs.draw_cards(down_count)
		columns_up[i].cards = cs.draw_cards(1)

	var empty:Array[Card] = []
	for f in foundations:
		f.cards = empty.duplicate()
	$drag_column.cards = empty.duplicate()
	$stock.cards = cs.draw_cards(50)


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
						_check_all_runs()
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
					if $drag_column.cards.is_empty():
						undo_stack.pop_back()
						state = State.IDLE
						if chosen_card_stack is SpiderColumnUp and not chosen_card_stack.cards.is_empty():
							_show_status("Only same-suit runs can be moved together")
					else:
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


func _on_stock_selected(_card_idx):
	if $stock.cards.is_empty():
		return
	for i in 10:
		if columns_down[i].cards.is_empty() and columns_up[i].cards.is_empty():
			_show_status("Fill every column before dealing")
			return

	save_state()
	var stock_cards:Array[Card] = $stock.cards.duplicate()
	for i in 10:
		var card:Card = stock_cards.pop_back()
		var up:Array[Card] = columns_up[i].cards.duplicate()
		up.append(card)
		columns_up[i].cards = up
	$stock.cards = stock_cards

	_check_all_runs()
	check_win()


func _flip_col_down_if_needed(stack: CardStackBody):
	if not stack is SpiderColumnUp:
		return
	if not stack.cards.is_empty():
		return
	var col_down_name = stack.name.replace("col_up_", "col_down_")
	var col_down = get_node_or_null(col_down_name)
	if col_down and not col_down.cards.is_empty():
		var down_cards: Array[Card] = col_down.cards.duplicate()
		var flipped: Card = down_cards.pop_back()
		col_down.cards = down_cards
		var flipped_arr: Array[Card] = []
		flipped_arr.append(flipped)
		stack.cards = flipped_arr


func _is_full_run(seq:Array[Card]) -> bool:
	if seq.size() != 13:
		return false
	if seq[0].rank != Card.Rank.KING:
		return false
	for i in range(1, 13):
		if seq[i].suit != seq[0].suit:
			return false
		if seq[i].rank != seq[i - 1].rank - 1:
			return false
	return true


func _check_runs_on(stack):
	if not stack is SpiderColumnUp:
		return
	while stack.cards.size() >= 13:
		var c:Array[Card] = stack.cards
		var top13:Array[Card] = c.slice(c.size() - 13)
		if _is_full_run(top13):
			stack.cards = c.slice(0, c.size() - 13)
			if completed_runs < foundations.size():
				top13.reverse()
				foundations[completed_runs].cards = top13
			completed_runs += 1
			_flip_col_down_if_needed(stack)
		else:
			break


func _check_all_runs():
	for col in columns_up:
		_check_runs_on(col)


func check_win():
	if completed_runs >= 8:
		timer_running = false
		$UI/lbl_win.text = "You Win!"
		$UI/lbl_win.visible = true


func _show_status(msg: String):
	$UI/lbl_status.text = msg
	$UI/lbl_status.visible = true
	_status_token += 1
	var my := _status_token
	await get_tree().create_timer(2.5).timeout
	if my == _status_token and is_inside_tree():
		$UI/lbl_status.visible = false


func save_state():
	var s = {
		"stock": $stock.cards.duplicate(),
		"completed_runs": completed_runs,
	}
	for i in 10:
		s["cd" + str(i)] = columns_down[i].cards.duplicate()
		s["cu" + str(i)] = columns_up[i].cards.duplicate()
	for i in 8:
		s["f" + str(i)] = foundations[i].cards.duplicate()
	undo_stack.append(s)


func restore_state(s: Dictionary):
	$stock.cards = s["stock"]
	completed_runs = s["completed_runs"]
	for i in 10:
		columns_down[i].cards = s["cd" + str(i)]
		columns_up[i].cards = s["cu" + str(i)]
	for i in 8:
		foundations[i].cards = s["f" + str(i)]
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


func _on_bn_new_game_pressed():
	_new_game(false)


func _on_bn_restart_pressed():
	$UI/popup_restart.popup_centered()


func _on_bn_help_pressed():
	$UI/popup_help.popup_centered()


func _find_moves() -> Array:
	var moves := []
	for src in columns_up:
		var n = src.cards.size()
		for i in n:
			var cand: Array[Card] = src.cards.slice(i)
			if not SpiderColumnUp.is_run(cand):
				continue
			for j in 10:
				if columns_up[j] != src and columns_up[j]._can_drop(cand):
					moves.append({"from": src, "from_idx": i, "to": columns_up[j]})
				if columns_down[j]._can_drop(cand):
					moves.append({"from": src, "from_idx": i, "to": columns_down[j]})
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
	_new_game(false)


func _on_restart_same_pressed():
	$UI/popup_restart.hide()
	_new_game(true)


func _on_bn_undo_pressed():
	if undo_stack.is_empty():
		return
	restore_state(undo_stack.pop_back())


func _on_bn_background_pressed():
	$UI/popup_background.popup_centered()


func _on_cpb_background_color_changed(color: Color):
	RenderingServer.set_default_clear_color(color)


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
