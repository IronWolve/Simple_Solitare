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


extends CardStackBody
class_name ColumnUpStack

const FACE_DOWN_OFFSET = 30.0

func _process(delta):
	super._process(delta)
	var col_down_name = name.replace("col_up_", "col_down_")
	var col_down = get_parent().get_node_or_null(col_down_name)
	if col_down:
		position.y = col_down.position.y + col_down.cards.size() * FACE_DOWN_OFFSET

func _can_drop(drop_cards:Array[Card])->bool:
	if drop_cards.is_empty():
		return false

	if cards.is_empty():
		if drop_cards[0].rank == Card.Rank.KING:
			return true
	else:
		var last_card:Card = cards.back()
		var col0:Card.CardColor = Card.get_card_color(last_card.suit)
		var col1:Card.CardColor = Card.get_card_color(drop_cards[0].suit)
		
		if col0 == col1:
			return false
	
		if drop_cards[0].rank + 1 == last_card.rank:
			return true
	
	return false
	

func _drop(drop_stack:CardStackBody):
	var new_stack:Array[Card] = cards.duplicate()
	new_stack.append_array(drop_stack.cards)
	
	var e:Array[Card] = []
	drop_stack.cards = e
	
	cards = new_stack


func _effective_pickable() -> bool:
	return !cards.is_empty()


func _on_selected(card_idx):
	if cards.is_empty() or card_idx != cards.size() - 1:
		return
	var card_table = get_parent()
	if card_table is CardTable:
		card_table.try_auto_move_to_goal(self)


func _on_drag_started(card_idx):
	var card_table:CardTable = get_parent()
	var drag_col:CardStackBody = card_table.get_node("drag_column")

	var remain:Array[Card] = cards.slice(0, card_idx)
	var drag_part:Array[Card] = cards.slice(card_idx)

	drag_col.cards = drag_part
	cards = remain
	
