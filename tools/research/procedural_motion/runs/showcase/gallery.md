### People: walking, running, terrain, obstacles (one planner, gait from the Froude number)

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/walk_run.gif" width="100%"><br><b>walk_run</b> <i>(emergent)</i><br>stand, walk, fast walk, run, back to walk, stop</td><td width="50%" valign="top"><img src="showcase/sim/stairs_up_down.gif" width="100%"><br><b>stairs_up_down</b> <i>(emergent)</i><br>stairs are just terrain (the steps span the whole width: the only way is over)</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/slope_up_down.gif" width="100%"><br><b>slope_up_down</b> <i>(emergent)</i><br>slopes: trunk pitch and foot rotation follow the ground</td><td width="50%" valign="top"><img src="showcase/sim/step_over_log.gif" width="100%"><br><b>step_over_log</b> <i>(emergent)</i><br>step over a log</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/duck_under_beam.gif" width="100%"><br><b>duck_under_beam</b> <i>(emergent)</i><br>auto-duck below a ceiling</td><td width="50%" valign="top"><img src="showcase/sim/obstacle_course.gif" width="100%"><br><b>obstacle_course</b> <i>(emergent)</i><br>uneven ground, a log, pits (jumped with the run-up the body needs), a low wall, a waist-high wall (vaulted), a wall that is too high (gone round), a pit that is too wide (stops, afraid)</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/around_obstacles.gif" width="100%"><br><b>around_obstacles</b> <i>(emergent)</i><br>A* around walls</td><td width="50%" valign="top"><img src="showcase/sim/run_forest.gif" width="100%"><br><b>run_forest</b> <i>(emergent)</i><br>run through a forest, duck under branches</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/run_crowd.gif" width="100%"><br><b>run_crowd</b> <i>(emergent)</i><br>run through a crowd</td><td width="50%" valign="top"><img src="showcase/sim/crowd.gif" width="100%"><br><b>crowd</b> <i>(emergent)</i><br>14 people cross a plaza</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/crowd_squeeze.gif" width="100%"><br><b>crowd_squeeze</b> <i>(emergent)</i><br>squeeze through people: shoulders turn, hands go up</td><td width="50%" valign="top"><img src="showcase/sim/run_into_wall.gif" width="100%"><br><b>run_into_wall</b> <i>(emergent)</i><br>run into a wall: seen early, late, not at all</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/start_from_squat.gif" width="100%"><br><b>start_from_squat</b> <i>(emergent)</i><br>from a squat to a run: stand first, drive out, or a sprinter&#x27;s start</td><td width="50%" valign="top"><img src="showcase/sim/joystick_control.gif" width="100%"><br><b>joystick_control</b> <i>(emergent)</i><br>stick input with inertia: brake, pivot, corner, accelerate</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/push_recovery.gif" width="100%"><br><b>push_recovery</b> <i>(emergent)</i><br>shoved: recovery steps</td><td></td></tr>
</table>

### People: muscle, energy, flexibility, age, pregnancy, clothing, injury

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/bodies_walk.gif" width="100%"><br><b>bodies_walk</b> <i>(emergent)</i><br>tall, dwarf, belly, armour, pack, skirt</td><td width="50%" valign="top"><img src="showcase/sim/personas_course.gif" width="100%"><br><b>personas_course</b> <i>(emergent)</i><br>child, adult, elder, starved, athlete on the same course: what each jumps, vaults, refuses</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/personas_race.gif" width="100%"><br><b>personas_race</b> <i>(emergent)</i><br>a 36 s all-out run: the reserve of energy sets the pace that can be held</td><td width="50%" valign="top"><img src="showcase/sim/outfits_walk.gif" width="100%"><br><b>outfits_walk</b> <i>(emergent)</i><br>tight skirt, wide skirt, trousers, boots, heels, chainmail, plate</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/pregnant_stairs.gif" width="100%"><br><b>pregnant_stairs</b> <i>(emergent)</i><br>stairs in a skirt: not pregnant vs heavily pregnant</td><td width="50%" valign="top"><img src="showcase/sim/limp_people.gif" width="100%"><br><b>limp_people</b> <i>(emergent)</i><br>sore leg, rigid stick for a lower leg, crutches</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/bump_head.gif" width="100%"><br><b>bump_head</b> <i>(emergent)</i><br>hit the head on a beam</td><td></td></tr>
</table>

### Jumping: how far the body knows it can jump (self-model learned by practice, fear)

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/jump_gap.gif" width="100%"><br><b>jump_gap</b> <i>(emergent)</i><br>gaps of 0.8, 1.8, 2.8 and 3.4 m: the run-up follows the gap</td><td width="50%" valign="top"><img src="showcase/sim/jump_fear.gif" width="100%"><br><b>jump_fear</b> <i>(emergent)</i><br>knowing the limit: jumps 3.4 m, is afraid of 4.4 m, an over-confident one balks at the edge, an over-cautious one will not try</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/jump_wall.gif" width="100%"><br><b>jump_wall</b> <i>(emergent)</i><br>standing jump over a wall</td><td></td></tr>
</table>

### Climbing and hanging

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/climb_rock.gif" width="100%"><br><b>climb_rock</b> <i>(emergent)</i><br>rock face: only the coloured holds can be used</td><td width="50%" valign="top"><img src="showcase/sim/climb_tree.gif" width="100%"><br><b>climb_tree</b> <i>(emergent)</i><br>tree: branch stubs are the only holds</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/ladder_climb.gif" width="100%"><br><b>ladder_climb</b> <i>(goal script)</i><br>ladder</td><td width="50%" valign="top"><img src="showcase/sim/pullup_bar.gif" width="100%"><br><b>pullup_bar</b> <i>(goal script)</i><br>pull-ups on a bar, legs help</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/pullup_pipe.gif" width="100%"><br><b>pullup_pipe</b> <i>(goal script)</i><br>pull-ups on a pipe</td><td width="50%" valign="top"><img src="showcase/sim/pullup_rings.gif" width="100%"><br><b>pullup_rings</b> <i>(goal script)</i><br>pull-ups on rings</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/mantle_ledge.gif" width="100%"><br><b>mantle_ledge</b> <i>(goal script)</i><br>from a hang to standing on a ledge</td><td width="50%" valign="top"><img src="showcase/sim/rope_climb.gif" width="100%"><br><b>rope_climb</b> <i>(goal script)</i><br>climbing a rope with hands and feet</td></tr>
</table>

### Everyday situations

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/door_open.gif" width="100%"><br><b>door_open</b> <i>(goal script)</i><br>open a door</td><td width="50%" valign="top"><img src="showcase/sim/sit_stand.gif" width="100%"><br><b>sit_stand</b> <i>(goal script)</i><br>sit on a chair and stand</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/sit_table.gif" width="100%"><br><b>sit_table</b> <i>(goal script)</i><br>pull the chair out, sit, scoot in, eat, leave (table and chair are real obstacles)</td><td width="50%" valign="top"><img src="showcase/sim/bed_lie_rise.gif" width="100%"><br><b>bed_lie_rise</b> <i>(goal script)</i><br>lie in a bed, get up</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/get_up_floor.gif" width="100%"><br><b>get_up_floor</b> <i>(goal script)</i><br>get up from the floor</td><td width="50%" valign="top"><img src="showcase/sim/rider.gif" width="100%"><br><b>rider</b> <i>(goal script)</i><br>ride a horse (see the horse section)</td></tr>
</table>

### Blows, pain, reactions

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/hit_reactions_a.gif" width="100%"><br><b>hit_reactions_a</b> <i>(emergent)</i><br>hit on head, torso, arm: stagger, doubled over, drop the weapon, clutch</td><td width="50%" valign="top"><img src="showcase/sim/hit_reactions_b.gif" width="100%"><br><b>hit_reactions_b</b> <i>(physics, evolved)</i><br>leg: limp; hard head blow: physical fall, lie, get up</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/hit_reactions_c.gif" width="100%"><br><b>hit_reactions_c</b> <i>(physics, evolved)</i><br>groin (man vs woman) and knee</td><td width="50%" valign="top"><img src="showcase/sim/dodge_reactions.gif" width="100%"><br><b>dodge_reactions</b> <i>(emergent)</i><br>notice in time: side step, duck, hop, block; too late: hit</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/weapon_reactions.gif" width="100%"><br><b>weapon_reactions</b> <i>(emergent)</i><br>axe vs shield, axe on a bare head, arrows dodged, caught by a shield, taken; shin block</td><td width="50%" valign="top"><img src="showcase/sim/duel.gif" width="100%"><br><b>duel</b> <i>(emergent)</i><br>two fighters choose targets and reactions on their own</td></tr>
</table>

### Blows with different weapons and limbs; damage from animals

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/weapons_human.gif" width="100%"><br><b>weapons_human</b> <i>(emergent)</i><br>sword, axe, spear and fist: swing or straight thrust, hit or dodged</td><td width="50%" valign="top"><img src="showcase/sim/kick_human.gif" width="100%"><br><b>kick_human</b> <i>(emergent)</i><br>a kick to the thigh: the victim limps</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/wolf_bite.gif" width="100%"><br><b>wolf_bite</b> <i>(emergent)</i><br>a wolf lunges and bites the forearm: the arm is hurt</td><td width="50%" valign="top"><img src="showcase/sim/bear_swipe.gif" width="100%"><br><b>bear_swipe</b> <i>(emergent)</i><br>a bear&#x27;s paw swipe to the head: a knock-down</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/horse_kick.gif" width="100%"><br><b>horse_kick</b> <i>(emergent)</i><br>a hind hoof kick: a hard blow to the torso</td><td></td></tr>
</table>

### Cat

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/cat_jump_up.gif" width="100%"><br><b>cat_jump_up</b> <i>(emergent)</i><br>jump up and down: eight spine joints coil and stretch</td><td width="50%" valign="top"><img src="showcase/sim/slalom_cat.gif" width="100%"><br><b>slalom_cat</b> <i>(emergent)</i><br>slalom: tight turns, balance tail</td></tr>
</table>

### Dog

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/slalom_dog.gif" width="100%"><br><b>slalom_dog</b> <i>(emergent)</i><br>slalom at a run</td><td width="50%" valign="top"><img src="showcase/sim/limp_dogs.gif" width="100%"><br><b>limp_dogs</b> <i>(emergent)</i><br>sore leg, three legs, a stick for a lower leg</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/animal_ages.gif" width="100%"><br><b>animal_ages</b> <i>(emergent)</i><br>old dog, puppy, kid goat</td><td></td></tr>
</table>

### Horse (and rider)

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/horse_gaits.gif" width="100%"><br><b>horse_gaits</b> <i>(emergent)</i><br>walk, trot, canter, gallop</td><td width="50%" valign="top"><img src="showcase/sim/slalom_horse.gif" width="100%"><br><b>slalom_horse</b> <i>(emergent)</i><br>slalom: the big body swings wide</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/horse_jumps.gif" width="100%"><br><b>horse_jumps</b> <i>(emergent)</i><br>fences of 1.0, 1.6 and 2.7 m: jumps, jumps, refuses</td><td width="50%" valign="top"><img src="showcase/sim/horse_load.gif" width="100%"><br><b>horse_load</b> <i>(emergent)</i><br>with 0, 90, 180 kg on the back</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/horse_gait_tail.gif" width="100%"><br><b>horse_gait_tail</b> <i>(emergent)</i><br>5-joint neck nod, hair tail</td><td width="50%" valign="top"><img src="showcase/sim/rider.gif" width="100%"><br><b>rider</b> <i>(goal script)</i><br>rider on the saddle: walk to gallop</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/rider_course.gif" width="100%"><br><b>rider_course</b> <i>(goal script)</i><br>horse and rider: slalom and a fence</td><td></td></tr>
</table>

### Other animals, side by side

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/animals_trot.gif" width="100%"><br><b>animals_trot</b> <i>(emergent)</i><br>dog, cat, horse, wolf, pig trot</td><td width="50%" valign="top"><img src="showcase/sim/quadruped_speeds.gif" width="100%"><br><b>quadruped_speeds</b> <i>(emergent)</i><br>walk to gallop by Froude number</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/quad_species_tails.gif" width="100%"><br><b>quad_species_tails</b> <i>(emergent)</i><br>balance tail, wag, low tail, curl</td><td width="50%" valign="top"><img src="showcase/sim/quad_jump_species.gif" width="100%"><br><b>quad_jump_species</b> <i>(emergent)</i><br>same relative obstacle: cat, dog, wolf, pig</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/animals_stairs_log.gif" width="100%"><br><b>animals_stairs_log</b> <i>(emergent)</i><br>stairs and a log, four legs</td><td></td></tr>
</table>

### Birds and snake

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/birds_walk.gif" width="100%"><br><b>birds_walk</b> <i>(emergent)</i><br>bird gaits</td><td width="50%" valign="top"><img src="showcase/sim/bird_flight.gif" width="100%"><br><b>bird_flight</b> <i>(kinematic model)</i><br>flapping flight model</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/bird_land_ground.gif" width="100%"><br><b>bird_land_ground</b> <i>(kinematic model)</i><br>landing on the ground</td><td width="50%" valign="top"><img src="showcase/sim/bird_land_branch.gif" width="100%"><br><b>bird_land_branch</b> <i>(kinematic model)</i><br>landing on a branch</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/bird_land_water.gif" width="100%"><br><b>bird_land_water</b> <i>(kinematic model)</i><br>landing on water</td><td width="50%" valign="top"><img src="showcase/sim/bird_fly.gif" width="100%"><br><b>bird_fly</b> <i>(physics, evolved)</i><br>physical flight: wings and tail are plates in the air; gliding about 3 s (the stroke is not good yet)</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/bird_land.gif" width="100%"><br><b>bird_land</b> <i>(physics, evolved)</i><br>physical landing: not solved (hits hard)</td><td width="50%" valign="top"><img src="showcase/sim/bird_takeoff.gif" width="100%"><br><b>bird_takeoff</b> <i>(physics, evolved)</i><br>physical take-off: not learned</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/snake_around.gif" width="100%"><br><b>snake_around</b> <i>(kinematic model)</i><br>serpentine motion between walls</td><td></td></tr>
</table>

### Water

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/swim_freestyle.gif" width="100%"><br><b>swim_freestyle</b> <i>(kinematic model)</i><br>swimming with the head above water (hand-built)</td><td width="50%" valign="top"><img src="showcase/sim/dive_swim.gif" width="100%"><br><b>dive_swim</b> <i>(kinematic model)</i><br>diving (hand-built)</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/swim_surface.gif" width="100%"><br><b>swim_surface</b> <i>(physics, evolved)</i><br>physical swimmer at the surface with an oxygen budget: a poor stroke, but it does breathe</td><td width="50%" valign="top"><img src="showcase/sim/swim_under_bottom.gif" width="100%"><br><b>swim_under_bottom</b> <i>(physics, evolved)</i><br>physical swimmer to a goal on the bottom</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/swim_under_far.gif" width="100%"><br><b>swim_under_far</b> <i>(physics, evolved)</i><br>physical swimmer to a far goal at depth</td><td></td></tr>
</table>

### Physical falls (MuJoCo, evolved on the bone-injury score)

<table>
<tr><td width="50%" valign="top"><img src="showcase/sim/shove_forward.gif" width="100%"><br><b>shove_forward</b> <i>(physics, evolved)</i><br>shove: stiff body vs evolved reflex</td><td width="50%" valign="top"><img src="showcase/sim/drop_2m.gif" width="100%"><br><b>drop_2m</b> <i>(physics, evolved)</i><br>drop of 2 m</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/drop_2p5m_fwd.gif" width="100%"><br><b>drop_2p5m_fwd</b> <i>(physics, evolved)</i><br>drop of 2.5 m with forward speed</td><td width="50%" valign="top"><img src="showcase/sim/preg_shove_forward.gif" width="100%"><br><b>preg_shove_forward</b> <i>(physics, evolved)</i><br>pregnant: the general reflex vs the reflex evolved for this body (the belly is scored most)</td></tr>
<tr><td width="50%" valign="top"><img src="showcase/sim/preg_drop_1m.gif" width="100%"><br><b>preg_drop_1m</b> <i>(physics, evolved)</i><br>pregnant: a drop</td><td width="50%" valign="top"><img src="showcase/sim/slide_slope.gif" width="100%"><br><b>slide_slope</b> <i>(physics, evolved)</i><br>standing on a slippery slope</td></tr>
</table>
