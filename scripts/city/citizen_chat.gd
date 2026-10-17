extends RefCounted

## Neighbours chat while they wait (docs/SYSTEMS/CITIZENS.md "Neighbours chat").
## WHY: a resident who has arrived at their door, the well or a market spot holds
## that place for up to two hours of the timetable, and alone they only play
## `idle`; streets and farmyards read as people frozen in place. Two residents
## waiting within CHAT_RADIUS of each other now turn to one another and take turns
## talking. Presentation only: the timetable, positions and saves are unchanged.

## Metres between two waiting residents that still reads as one conversation.
const CHAT_RADIUS := 2.6
## Seconds one side speaks before the other answers. `talk_gesture` does not
## loop, so each turn replays it from the start.
const TURN_SECONDS := 3.2
## Share of residents (in tenths) who strike up a chat at all: a forum where every
## waiting body pairs off reads as staged; some keep to themselves.
const TALKATIVE_TENTHS := 6


## Greedy nearest-first pairing of the waiting residents at `points` (world xz,
## metres): each joins at most one pair. Returns flat pairs [a0, b0, a1, b1, ...]
## of indices into `points`, closest pair first.
static func pairs(points: PackedVector2Array, radius: float = CHAT_RADIUS) -> PackedInt32Array:
	var close: Array = []
	var limit := radius * radius
	for a in points.size():
		for b in range(a + 1, points.size()):
			var d := points[a].distance_squared_to(points[b])
			if d <= limit:
				close.append([d, a, b])
	close.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var taken := {}
	var out := PackedInt32Array()
	for entry: Array in close:
		var a: int = entry[1]
		var b: int = entry[2]
		if taken.has(a) or taken.has(b):
			continue
		taken[a] = true
		taken[b] = true
		out.append(a)
		out.append(b)
	return out


## True when the first resident of a pair speaks at `seconds`; the second speaks
## otherwise. `pair_seed` staggers pairs so a street does not gesture in unison.
static func first_speaks(seconds: float, pair_seed: int) -> bool:
	return posmod(int(floor(seconds / TURN_SECONDS)) + pair_seed, 2) == 0


## Stable per resident: whether `resident` (census index) chats with neighbours.
static func is_talkative(resident: int) -> bool:
	return posmod(hash(resident), 10) < TALKATIVE_TENTHS
