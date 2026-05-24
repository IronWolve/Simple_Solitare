extends CardStackBody
class_name SpiderColumnUp

const FACE_DOWN_OFFSET = 30.0

func _process(delta):
	super._process(delta)
	var col_down_name = name.replace("col_up_", "col_down_")
	var col_down = get_parent().get_node_or_null(col_down_name)
	if col_down:
		position.y = col_down.position.y + col_down.cards.size() * FACE_DOWN_OFFSET

func _effective_pickable() -> bool:
	return !cards.is_empty()

static func is_run(seq:Array[Card]) -> bool:
	if seq.is_empty():
		return false
	for i in range(1, seq.size()):
		if seq[i].suit != seq[0].suit:
			return false
		if seq[i].rank != seq[i - 1].rank - 1:
			return false
	return true

func _can_drop(drop_cards:Array[Card]) -> bool:
	if drop_cards.is_empty():
		return false
	if cards.is_empty():
		return true
	var last_card:Card = cards.back()
	return last_card.rank == drop_cards[0].rank + 1

func _drop(drop_stack:CardStackBody):
	var new_stack:Array[Card] = cards.duplicate()
	new_stack.append_array(drop_stack.cards)
	var e:Array[Card] = []
	drop_stack.cards = e
	cards = new_stack

func _on_selected(_card_idx):
	pass

func _on_drag_started(card_idx):
	var candidate:Array[Card] = cards.slice(card_idx)
	if not is_run(candidate):
		return
	var drag_col:CardStackBody = get_parent().get_node("drag_column")
	drag_col.cards = candidate
	cards = cards.slice(0, card_idx)
