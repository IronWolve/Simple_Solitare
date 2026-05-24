extends CardStackBody
class_name SpiderColumnDown

@export var up_stack:NodePath

func _can_drop(drop_cards:Array[Card]) -> bool:
	if drop_cards.is_empty():
		return false
	if !cards.is_empty():
		return false
	var up:CardStackBody = get_node(up_stack)
	return up.cards.is_empty()

func _drop(drop_stack:CardStackBody):
	var up:CardStackBody = get_node(up_stack)
	var moved:Array[Card] = drop_stack.cards
	var e:Array[Card] = []
	drop_stack.cards = e
	up.cards = moved

func _on_selected(_card_idx):
	pass

func _on_drag_started(_card_idx):
	pass
