extends RefCounted

## ADR 0057 (task R-2152): where a cloud-to-ground stroke lands when it falls near
## the hero. The sky (SkyWeather3D) still decides when and under which storm cell a
## stroke falls; this only snaps its ground point onto something that sticks up -
## a tower, a tree, a roof, a person standing in the open - the way a real leader
## is caught by the tallest object within its striking distance. Pure and
## deterministic: the caller passes one roll from the lightning RNG, so a save
## reproduces the same target.
##
## Candidates are dictionaries in world units (the seamless city's XZ plane):
## {kind: StringName, id: String, position: Vector2, base_y: float, height: float}
## where `height` is in metres above `base_y`. The resolver adds the hero itself
## unless he is sheltered.

const KIND_GROUND := &"ground"
const KIND_TOWER := &"tower"
const KIND_TREE := &"tree"
const KIND_BUILDING := &"building"
const KIND_PERSON := &"person"
const KIND_HERO := &"hero"

## Strokes farther than this from the hero stay presentation only: nobody there
## can see what was hit, and the world near the hero is the only one loaded.
const GAMEPLAY_RADIUS_M := 600.0
## Striking distance of an object grows with its height (the rolling-sphere idea
## behind lightning-rod design): a 1.8 m person catches a leader from about 11 m,
## a 12 m tree from about 42 m, a 40 m spire from about 126 m.
const ATTRACT_BASE_M := 6.0
const ATTRACT_PER_HEIGHT := 3.0
## Bare ground competes like a 2 m object, so a field strike still happens when
## only low things stand near the stroke.
const GROUND_HEIGHT_M := 2.0
## Kalev's height (docs/SYSTEMS/COMBAT.md body scale).
const HERO_HEIGHT_M := 1.83
## Ground current and side flash: within this distance of the struck point a
## person is hurt even when the bolt hits something else.
const NEAR_HURT_M := 10.0
## Providers only need to report objects this close to the stroke: the tallest
## object in the plan (a 40 m spire) cannot attract from farther.
const CANDIDATE_RADIUS_M := 130.0


## Resolves one ground stroke. `ground` and `hero` are world XZ; `metres_per_unit`
## converts world units to metres (CityPlan.metres_per_unit). `roll` is 0..1 from
## the lightning RNG. Returns {} for a stroke beyond GAMEPLAY_RADIUS_M, otherwise
## {kind, id, position: Vector3 (struck top), ground: Vector2, distance_to_hero_m,
## hits_hero: bool}.
static func resolve(
	ground: Vector2,
	hero: Vector2,
	hero_base_y: float,
	hero_sheltered: bool,
	candidates: Array,
	metres_per_unit: float,
	roll: float
) -> Dictionary:
	var mpu := maxf(metres_per_unit, 0.001)
	if ground.distance_to(hero) * mpu > GAMEPLAY_RADIUS_M:
		return {}
	var pool: Array = candidates.duplicate()
	if not hero_sheltered:
		pool.append({
			"kind": KIND_HERO, "id": "hero", "position": hero,
			"base_y": hero_base_y, "height": HERO_HEIGHT_M,
		})
	# Weight by height squared: a leader is far more likely to connect with a tall
	# object than with a short one inside the same striking distance.
	var chosen: Dictionary = {}
	var weights: Array[float] = [GROUND_HEIGHT_M * GROUND_HEIGHT_M]
	var reachable: Array = [{}]
	for candidate: Dictionary in pool:
		var height := float(candidate.get("height", 0.0))
		var reach_m := ATTRACT_BASE_M + ATTRACT_PER_HEIGHT * height
		var at: Vector2 = candidate.get("position", Vector2.ZERO)
		if at.distance_to(ground) * mpu > reach_m:
			continue
		weights.append(height * height)
		reachable.append(candidate)
	var total := 0.0
	for w: float in weights:
		total += w
	var pick := clampf(roll, 0.0, 0.999999) * total
	for i in weights.size():
		pick -= weights[i]
		if pick < 0.0:
			chosen = reachable[i]
			break
	var kind: StringName = KIND_GROUND
	var id := ""
	var point := ground
	var top_y := hero_base_y
	if not chosen.is_empty():
		kind = chosen.get("kind", KIND_GROUND)
		id = String(chosen.get("id", ""))
		point = chosen.get("position", ground)
		top_y = float(chosen.get("base_y", 0.0)) + float(chosen.get("height", 0.0)) / mpu
	return {
		"kind": kind,
		"id": id,
		"position": Vector3(point.x, top_y, point.y),
		"ground": point,
		"distance_to_hero_m": point.distance_to(hero) * mpu,
		"hits_hero": kind == KIND_HERO,
	}


## Damage (0..1 of max health) a person takes from a stroke `distance_m` away that
## did not hit them directly: ground current and side flash fade over NEAR_HURT_M.
## 0 beyond it. A sheltered person takes nothing.
static func near_hurt_fraction(distance_m: float, sheltered: bool) -> float:
	if sheltered or distance_m > NEAR_HURT_M:
		return 0.0
	return lerpf(0.45, 0.15, clampf(distance_m / NEAR_HURT_M, 0.0, 1.0))


## Deterministic 0..1 roll for one person (`salt`) and one strike: the strike comes
## from the lightning RNG, so a save replays the same outcome without a new stream.
static func strike_roll(strike: Dictionary, salt: String) -> float:
	var at: Vector3 = strike.get("position", Vector3.ZERO)
	var key := "%d:%d:%s" % [roundi(at.x * 10.0), roundi(at.z * 10.0), salt]
	return float(hash(key) & 0xFFFFFF) / 16777216.0
