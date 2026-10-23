class_name Battle
extends RefCounted
## Seedable turn resolver. UI consumes event strings; no scene nodes are required.

const DB = preload("res://scripts/creature_db.gd")
const CHALLENGES = preload("res://scripts/challenge_db.gd")
const STRIKE_POWER: int = 12

var state: GameState
var enemies: Array[Dictionary] = []
var enemy: Dictionary = {}
var kind: String = "wild"
var challenge_id: String = ""
var active_index: int = 0
var finished: bool = false
var outcome: String = ""
var log: Array[String] = []
var turn: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _enemy_index: int = 0
var _events: Array[String] = []


func begin(game: GameState, battle_kind: String, opponents: Array[Dictionary], seed_value: int = -1) -> void:
	state = game
	kind = battle_kind
	challenge_id = ""
	enemies.clear()
	enemy = {}
	log.clear()
	_events.clear()
	active_index = 0
	_enemy_index = 0
	finished = false
	outcome = ""
	turn = 0
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	for opponent: Dictionary in opponents:
		if opponent.has_all(["id", "level"]):
			var copy: Dictionary = DB.make_creature(int(opponent.id), int(opponent.level))
			if not copy.is_empty():
				copy.hp = clampi(int(opponent.get("hp", copy.max_hp)), 1, int(copy.max_hp))
				enemies.append(copy)
	if state == null or state.party.is_empty() or enemies.is_empty():
		finished = true
		outcome = "invalid"
		_say("No companions are ready for this encounter.")
		return
	active_index = _first_healthy_index()
	if active_index < 0:
		state.heal_all()
		active_index = 0
	enemy = enemies[0]
	if kind == "wild":
		_say("A wild %s appeared!" % _name(enemy))
	elif kind == "gym":
		_say("The Lantern Trial begins! %s enters." % _name(enemy))
	else:
		_say("Ivo sends out %s!" % _name(enemy))
	_say("Go, %s!" % _name(player()))


func begin_challenge(game: GameState, id: String, seed_value: int = -1) -> bool:
	var challenge: Dictionary = CHALLENGES.data(id)
	if not CHALLENGES.can_start(game, id):
		# Reset any earlier battle before showing the refusal; input must stay inert.
		begin(game, "trainer", [], seed_value)
		log.clear()
		_events.clear()
		if game != null and not challenge.is_empty() and bool(game.flags.get(str(challenge.flag), false)):
			_say("This challenge is already complete.")
		else:
			_say("This challenge is not available yet. Check your route and milestones.")
		return false
	begin(game, str(challenge.kind), CHALLENGES.opponents(id), seed_value)
	if finished:
		return false
	challenge_id = id
	log.clear()
	_events.clear()
	_say(str(challenge.opening) % _name(enemy))
	_say("Go, %s!" % _name(player()))
	return true


func player() -> Dictionary:
	if state == null or active_index < 0 or active_index >= state.party.size():
		return {}
	return state.party[active_index]


func act(action: String, index: int = 0) -> Array[String]:
	_events = []
	if finished:
		return _events
	if not _can_act(action, index):
		return _events
	turn += 1
	match action:
		"flee":
			finished = true
			outcome = "fled"
			_say("You returned safely to the path.")
		"capture":
			_capture()
			if not finished:
				_enemy_attack(false)
		"switch":
			active_index = index
			_say("Go, %s!" % _name(player()))
			_enemy_attack(false)
		"tonic":
			state.tonics -= 1
			var restored: int = _restore(player(), maxi(26, int(float(player().max_hp) * 0.65)))
			_say("Tonic restored %d HP to %s." % [restored, _name(player())])
			_enemy_attack(false)
		"guard":
			var restored: int = _restore(player(), maxi(6, int(float(player().max_hp) * 0.12)))
			_say("%s guards and recovers %d HP." % [_name(player()), restored])
			_enemy_attack(true)
		"strike", "skill":
			var actor_index: int = active_index
			var enemy_first: bool = _speed(enemy) > _speed(player())
			if enemy_first:
				_enemy_attack(false)
				if finished or active_index != actor_index:
					return _events
			var enemy_fainted: bool = _player_attack(action == "skill")
			if not finished and not enemy_fainted and not enemy_first:
				_enemy_attack(false)
	return _events


func _can_act(action: String, index: int) -> bool:
	match action:
		"strike", "skill", "guard":
			return true
		"flee":
			if kind != "wild":
				_say("Finish this challenge. You can recover at the village.")
				return false
			return true
		"capture":
			if kind != "wild":
				_say("A trainer's companion cannot be captured.")
				return false
			if state.party.size() >= GameState.PARTY_LIMIT:
				_say("Your party is full. Six companions travel together.")
				return false
			if state.orbs <= 0:
				_say("No orbs left. Win a wild encounter to earn another.")
				return false
			return true
		"tonic":
			if state.tonics <= 0:
				_say("No tonics left. Guard to recover a little HP.")
				return false
			if int(player().hp) >= int(player().max_hp):
				_say("%s already has full HP." % _name(player()))
				return false
			return true
		"switch":
			if index < 0 or index >= state.party.size() or index == active_index:
				_say("Choose another companion from your party.")
				return false
			if int(state.party[index].hp) <= 0:
				_say("That companion needs to rest first.")
				return false
			return true
		_:
			_say("Choose a battle action.")
			return false


func _player_attack(use_skill: bool) -> bool:
	var attacker: Dictionary = player()
	var info: Dictionary = DB.species(int(attacker.id))
	var move_name: String = str(info.move) if use_skill else "Strike"
	var attacking_element: String = str(info.element) if use_skill else "normal"
	var power: int = int(info.power) if use_skill else STRIKE_POWER
	var multiplier: float = DB.effectiveness(attacking_element, str(DB.species(int(enemy.id)).element))
	var damage: int = _damage(attacker, enemy, power, multiplier, false)
	enemy.hp = maxi(0, int(enemy.hp) - damage)
	_say("%s uses %s! %d damage." % [_name(attacker), move_name, damage])
	_effect_message(multiplier)
	if int(enemy.hp) <= 0:
		_say("%s is out of energy." % _name(enemy))
		_award_xp(22 + int(enemy.level) * 12)
		_enemy_index += 1
		if _enemy_index >= enemies.size():
			_win()
		else:
			enemy = enemies[_enemy_index]
			_say("The challenger sends out %s!" % _name(enemy))
		return true
	return false


func _enemy_attack(guarded: bool) -> void:
	if finished:
		return
	var defender: Dictionary = player()
	var info: Dictionary = DB.species(int(enemy.id))
	# Opponents alternate skills and strikes so every matchup has a safe opening.
	var use_skill: bool = turn % 2 == 0
	var element: String = str(info.element) if use_skill else "normal"
	var move_name: String = str(info.move) if use_skill else "Strike"
	var power: int = int(info.power) if use_skill else STRIKE_POWER
	var multiplier: float = DB.effectiveness(element, str(DB.species(int(defender.id)).element))
	var damage: int = _damage(enemy, defender, power, multiplier, true)
	if guarded:
		damage = maxi(1, int(roundf(float(damage) * 0.35)))
	defender.hp = maxi(0, int(defender.hp) - damage)
	_say("%s uses %s. %d damage." % [_name(enemy), move_name, damage])
	if int(defender.hp) <= 0:
		_say("%s needs a rest." % _name(defender))
		active_index = _first_healthy_index()
		if active_index < 0:
			_lose()
		else:
			_say("%s steps forward!" % _name(player()))


func _damage(attacker: Dictionary, defender: Dictionary, power: int, multiplier: float, is_enemy: bool) -> int:
	var attack_info: Dictionary = DB.species(int(attacker.id))
	var defense_info: Dictionary = DB.species(int(defender.id))
	var attack_value: float = float(attack_info.attack) + float(attacker.level) * 2.0
	var defense_value: float = float(defense_info.defense) + float(defender.level) * 1.6
	var base: float = float(power) + float(attacker.level) * 1.7 + attack_value * 0.4 - defense_value * 0.45
	var difficulty: float = 0.78 if is_enemy else 1.0
	return maxi(2, int(roundf(base * multiplier * difficulty * rng.randf_range(0.94, 1.06))))


func _capture() -> void:
	state.orbs -= 1
	var health_ratio: float = float(enemy.hp) / float(enemy.max_hp)
	var first_capture: bool = not bool(state.flags.captured)
	var guaranteed: bool = health_ratio <= 0.25 or (first_capture and health_ratio <= 0.5)
	var chance: float = clampf(0.22 + (1.0 - health_ratio) * 0.70 + float(int(player().level) - int(enemy.level)) * 0.025, 0.15, 0.92)
	if guaranteed or rng.randf() < chance:
		if state.add_creature(int(enemy.id), int(enemy.level)):
			state.flags.captured = true
			finished = true
			outcome = "captured"
			_say("The orb shines! %s joined your party." % _name(enemy))
			_award_xp(10 + int(enemy.level) * 5)
		else:
			state.orbs += 1
			_say("Your party is full. The orb returns to your bag.")
	else:
		_say("%s slipped free! Lower its HP and try again." % _name(enemy))


func _award_xp(amount: int) -> void:
	for i: int in range(state.party.size()):
		var creature: Dictionary = state.party[i]
		if int(creature.level) >= DB.LEVEL_CAP:
			creature.xp = 0
			continue
		var gained: int = amount if i == active_index else maxi(1, int(float(amount) * 0.5))
		creature.xp = int(creature.xp) + gained
		if i == active_index:
			_say("%s gained %d experience." % [_name(creature), gained])
		while int(creature.level) < DB.LEVEL_CAP and int(creature.xp) >= DB.xp_to_next(int(creature.level)):
			creature.xp = int(creature.xp) - DB.xp_to_next(int(creature.level))
			creature.level = int(creature.level) + 1
			creature.max_hp = int(DB.make_creature(int(creature.id), int(creature.level)).max_hp)
			if int(creature.hp) > 0:
				creature.hp = mini(int(creature.max_hp), int(creature.hp) + 17)
			_say("%s reached level %d!" % [_name(creature), int(creature.level)])
		if int(creature.level) >= DB.LEVEL_CAP:
			creature.xp = 0


func _win() -> void:
	finished = true
	outcome = "won"
	if not challenge_id.is_empty():
		_win_challenge()
		return
	if kind == "gym":
		state.flags.gym = true
		state.orbs = mini(999, state.orbs + 6)
		state.tonics = mini(999, state.tonics + 3)
		_say("Trial complete! You earned the Lantern Sigil.")
		_say("The valley glows again. Your journey has only begun.")
	elif kind == "trainer" or kind == "rival":
		state.flags.rival = true
		state.orbs = mini(999, state.orbs + 4)
		state.tonics = mini(999, state.tonics + 2)
		_say("Victory! Ivo gives you 4 orbs and 2 tonics.")
	else:
		state.orbs = mini(999, state.orbs + 1)
		_say("Victory! You found a spare capture orb.")


func _win_challenge() -> void:
	var challenge: Dictionary = CHALLENGES.data(challenge_id)
	var flag: String = str(challenge.flag)
	if bool(state.flags.get(flag, false)):
		_say("This challenge is already complete.")
		return
	state.flags[flag] = true
	var added_orbs: int = mini(int(challenge.reward_orbs), 999 - state.orbs)
	var added_tonics: int = mini(int(challenge.reward_tonics), 999 - state.tonics)
	state.orbs += added_orbs
	state.tonics += added_tonics
	for line: String in challenge.victory_lines:
		_say(line)
	_say("%s gives you %d orbs and %d tonics." % [str(challenge.trainer), added_orbs, added_tonics])


func _lose() -> void:
	finished = true
	outcome = "lost"
	state.heal_all()
	state.position = state.recovery_position()
	state.orbs = maxi(state.orbs, 3)
	state.tonics = maxi(state.tonics, 2)
	active_index = 0
	if state.island_id == "rainstep":
		_say("Your companions need rest. Orla brings you to the landing.")
	else:
		_say("Your companions need rest. The Keeper brings you home.")
	_say("Everyone is healed. Your progress is safe; try again.")


func _first_healthy_index() -> int:
	for i: int in range(state.party.size()):
		if int(state.party[i].hp) > 0:
			return i
	return -1


func _restore(creature: Dictionary, amount: int) -> int:
	var previous_hp: int = int(creature.hp)
	creature.hp = mini(int(creature.max_hp), previous_hp + amount)
	return int(creature.hp) - previous_hp


func _speed(creature: Dictionary) -> int:
	return int(DB.species(int(creature.id)).speed) + int(creature.level)


func _name(creature: Dictionary) -> String:
	return str(DB.species(int(creature.id)).name)


func _effect_message(multiplier: float) -> void:
	if multiplier > 1.0:
		_say("Elemental advantage!")
	elif multiplier < 1.0:
		_say("Resisted. A plain strike may work better.")


func _say(message: String) -> void:
	_events.append(message)
	log.append(message)
