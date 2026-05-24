extends Node

enum Variant { KLONDIKE, SPIDER_1, SPIDER_2, SPIDER_4 }

var variant: Variant = Variant.KLONDIKE

var cowboy_faces: bool = false
var _cowboy_cache: Dictionary = {}

func cowboy_face(rank, suit) -> Texture2D:
	var rn := ""
	match rank:
		Card.Rank.ACE:
			rn = "ace"
		Card.Rank.TEN:
			rn = "10"
		Card.Rank.JACK:
			rn = "jack"
		Card.Rank.QUEEN:
			rn = "queen"
		Card.Rank.KING:
			rn = "king"
		_:
			return null
	var sn := ""
	match suit:
		Card.Suit.SPADE:
			sn = "spade"
		Card.Suit.HEART:
			sn = "heart"
		Card.Suit.DIAMOND:
			sn = "diamond"
		Card.Suit.CLUB:
			sn = "club"
	var key := rn + "_" + sn
	if not _cowboy_cache.has(key):
		_cowboy_cache[key] = load("res://art/cowboy/" + key + ".jpg")
	return _cowboy_cache[key]

func variant_name() -> String:
	match variant:
		Variant.KLONDIKE:
			return "Klondike"
		Variant.SPIDER_1:
			return "Spider (1 Suit)"
		Variant.SPIDER_2:
			return "Spider (2 Suit)"
		Variant.SPIDER_4:
			return "Spider (4 Suit)"
	return "Klondike"

func spider_suits() -> int:
	match variant:
		Variant.SPIDER_1:
			return 1
		Variant.SPIDER_2:
			return 2
		Variant.SPIDER_4:
			return 4
	return 0
