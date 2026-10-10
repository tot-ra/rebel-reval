# Procedural motion report

Status: research report, 2026-10-08. Task **CM-01**. Page for the system: [Procedural motion (research)](../SYSTEMS/PROCEDURAL_MOTION.md). Code: `tools/research/procedural_motion/`, open source at <https://github.com/tot-ra/skeleto-nn>. Nothing here runs in the game. Showcase gallery of the research runs: [gallery](../../tools/research/procedural_motion/runs/showcase/gallery.md).

The question: can one motion system, driven by body parameters and a few general rules, cover the situations the game needs (people, animals and birds; terrain; obstacles; everyday actions; blows and falls; clothing) instead of a clip per situation, and can it be used on the shipped rigs later? This report shows what exists, how each motion is made, and what does not work yet.

How to read the labels: **emergent** means the motion comes out of body numbers and terrain by general rules; **goals** means a scripted list of goals for pelvis, hands and feet that the IK and balance code carry out; **kinematic model** means a hand-built formula; **physics** means a physical body whose controller was evolved or learned.

## 1. Walking, running, terrain (emergent)

The gait (walk, trot, canter, gallop) follows from the Froude number v²/(g h), so a dwarf, a horse and a cat pick their own cadence and stride. Feet are planted in the world and swing between footholds searched on the terrain, so stairs, kerbs, logs and slopes are just terrain. The pelvis is as high as the stance legs can reach, the trunk leans to keep the centre of mass over the feet (a belly, a pack or armour changes posture on its own), a ceiling lowers the body, A* navigates around walls.

![walk and run](images/procedural_motion/walk_run.gif)
![stairs](images/procedural_motion/stairs_up_down.gif)
![different bodies](images/procedural_motion/bodies_walk.gif)

Running through clutter uses the same rules. In the forest the runner goes around trunks and ducks under low branches; in the crowd the speed follows the width of the gap, the shoulders turn sideways and the hands come up.

![forest](images/procedural_motion/run_forest.gif)
![crowd](images/procedural_motion/run_crowd.gif)

## 2. Clothing (emergent)

An outfit changes joint ranges, adds mass on the limbs it covers and sets the foot shape; the planner copes. From the top of the GIF: plain, tight long skirt (short stride, hip flexion limited), wide skirt, tight trousers, heavy boots (stiff toe roll), high heels (the foot stands pitched on its ball, short unsteady steps, low top speed), chainmail, plate armour (stiff spine, shoulders and ankles, slow).

![outfits](images/procedural_motion/outfits_walk.gif)

Limping uses the same machinery. A sore leg shortens the time spent on it, the trunk leans over it and the other side steps short; a rigid stick in place of a lower leg has no ankle or foot roll, a short stance, the leg swung out and round, and the trunk leaning over it; on crutches one leg is held up and the crutch tips are planted while the good leg swings through and move ahead while it is down, with the hands on the grips. A dog can walk on three legs or with a stick for the lower hind leg.

![limping people](images/procedural_motion/limp_people.gif)
![limping dogs](images/procedural_motion/limp_dogs.gif)

## 3. Jumping (emergent, power limited)

The legs can give a limited take-off speed; the planner searches for the lowest apex that the vertical limit and the total limit allow, and a run-up adds horizontal speed. It refuses jumps the legs cannot make (a standing jump of 3.5 m, or a wall that is too high). Species differ in spine range and hind-limb power: the cat coils and extends its eight spine joints and rears up, the horse barely rotates.

![jump gap](images/procedural_motion/jump_gap.gif)
![species jump](images/procedural_motion/quad_jump_species.gif)

## 3b. Knowing what you can jump, and fear (emergent)

Three kinds of body numbers differ between people: **muscle** (jump and sprint power), **energy** (a reserve that drains with effort and refills at rest) and **flexibility** (joint ranges). A body also keeps a belief about its own jump range that it learns by practising on flat ground (a dozen attempts take any prior, over-confident or fearful, to the true range). At a gap it picks the lowest run-up speed that the belief allows, weighing the pain of failing (it grows with the depth) against a detour; if no speed does, it stops at the edge afraid. An over-confident one runs and is refused at the take-off by the real mechanics.

![gaps](images/procedural_motion/jump_gap.gif)
![fear](images/procedural_motion/jump_fear.gif)
![obstacle course](images/procedural_motion/obstacle_course.gif)

## 3c. Child, adult, elder, starved, athlete; pregnancy

The same course for five people: the child (little muscle for its size, a lot of energy, flexible) plays and hops, the elder and the starved one stop at the first pit, the athlete clears them all. In a 36 s all-out run the reserve of energy decides the pace that can be held. A heavily pregnant woman in a skirt takes stairs slower, plants each foot fully on the tread, holds the skirt and supports the belly.

![course](images/procedural_motion/personas_course.gif)
![race](images/procedural_motion/personas_race.gif)
![pregnant](images/procedural_motion/pregnant_stairs.gif)

## 3d. Starting a run and stick input

From a squat the body either stands first (unhurried) or drives out with the trunk forward and rises with the speed (hurried); a sprinter starts with the hands on the ground. With a stick as input the body brakes with the trunk leaning back, turns on the spot and accelerates again; a sharp turn at speed first slows it down.

![start](images/procedural_motion/start_from_squat.gif)
![stick](images/procedural_motion/joystick_control.gif)

## 3e. Different weapons, limbs and attackers

Sword, axe, spear and fist go through the same reactions as the stick (the spear and the fist go straight, the blades swing); a kick, a wolf's bite, a bear's paw and a horse's hoof are limb attacks that reach a point of the victim in time and put a blow of a given strength into its pain model (a forearm bite hurts the arm, a paw to the head knocks the man down, a hoof throws him). Limits: the bear does not rear on its hind legs and overlaps the victim slightly; the horse only kicks back.

![weapons](images/procedural_motion/weapons_human.gif)
![wolf](images/procedural_motion/wolf_bite.gif)
![bear](images/procedural_motion/bear_swipe.gif)
![horse](images/procedural_motion/horse_kick.gif)

## 4. Animals: spine, neck, tail (emergent)

Cat, dog, wolf, horse and pig differ in the number of spine joints and the range of the whole column, the neck joints and the nod that travels up the neck with the gait, the tail type (balance organ, wag, low and stiff, heavy hair that flags at speed and flicks at rest, curl) and the hoof or paw.

![tails](images/procedural_motion/quad_species_tails.gif)
![horse](images/procedural_motion/horse_gait_tail.gif)

Separately, the cat and the dog turn tight, the horse is a big body: its turning radius at a canter is about six metres, it swings wide, takes fences of 1.0 and 1.6 m and refuses 2.7 m (it knows the height is beyond it); with a rider the body leans with the turns and rises over the fence.

![cat](images/procedural_motion/slalom_cat.gif)
![dog](images/procedural_motion/slalom_dog.gif)
![horse slalom](images/procedural_motion/slalom_horse.gif)
![fences](images/procedural_motion/horse_jumps.gif)
![rider](images/procedural_motion/rider_course.gif)
![ages](images/procedural_motion/animal_ages.gif)

## 5. Birds (kinematic model)

Flight is a flapping model with beat rate from mass. Landing is solved from the landing point: the approach speed and glide slope follow from the distance and the height, then a flare, feet forward. On the ground the bird runs out, on a branch it nearly stalls and the toes close, on water it skids and floats low.

![branch](images/procedural_motion/bird_land_branch.gif)
![water](images/procedural_motion/bird_land_water.gif)

## 6. Climbing where only some points can be held (emergent)

Three points of contact stay; the fourth limb reaches for a free hold within reach that its kind allows (yellow hand holds, blue foot holds, grey both). Rock face and tree, random holds, no stored route.

![rock](images/procedural_motion/climb_rock.gif)
![tree](images/procedural_motion/climb_tree.gif)

## 7. Everyday actions (goals)

Door, chair, table, bed, get up from the floor, ladder, riding, pull-ups, mounting a ledge, a rope: sequences of goals for pelvis, hands and feet. At the table the chair is pulled out by its back (the hands grip it and it follows), the body goes round it, sits, scoots in; the table and the chair block the body, and no bone enters the tabletop (a test checks it).

![door](images/procedural_motion/door_open.gif)
![table](images/procedural_motion/sit_table.gif)
![bed](images/procedural_motion/bed_lie_rise.gif)
![pull-up](images/procedural_motion/pullup_bar.gif)
![ledge](images/procedural_motion/mantle_ledge.gif)
![rope](images/procedural_motion/rope_climb.gif)

## 8. Blows, pain and reactions

There is no scripted duel: a blow (stick, axe, arrow) is aimed at a body part; the defender notices it after its own delay and chooses by expected pain between duck, side step, step back, hop, block with a forearm, a shield or a lifted knee, or taking it. At impact the hit is resolved from the real positions. Pain per region changes what the body can do: an injured arm cannot hold a goal and drops the weapon, an injured leg limps, a torso blow doubles the body over, a head blow makes the walk weave; a blow to the groin is felt about three times less by a woman. A hard blow knocks the body down; the fall is simulated on the physical body with the evolved reflex and the get-up starts from the pose it ended in.

![hits](images/procedural_motion/hit_reactions_a.gif)
![knock-down](images/procedural_motion/hit_reactions_b.gif)
![groin and knee](images/procedural_motion/hit_reactions_c.gif)
![dodge](images/procedural_motion/dodge_reactions.gif)
![weapons](images/procedural_motion/weapon_reactions.gif)
![duel](images/procedural_motion/duel.gif)

Running into a wall: the runner who sees it early puts the hands on the wall and sinks; the stroke is about 45 cm and the force on each arm is small. The one who sees it late has a short stroke; the one who does not see it stops in the thickness of the chest and head and falls. The numbers in the caption come from the injury model below.

![wall](images/procedural_motion/run_into_wall.gif)

## 9. The injury model and what was evolved against it

A bone breaks when the force through it exceeds a tolerance, and it tolerates less when the load arrives fast. Stopping a mass m moving at v over a stroke s takes F = m v² / (2 s), so a yielding stop (flexing limb, roll, muscle springiness) spreads the same momentum over thirty times the stroke of a rigid one and lowers both the peak and the rate. Tolerances in body weights: head 5, torso 8, arms 3.5, legs 8; the head weighs three times as much as an arm in the score. This one score is the target of every learned or evolved part: the fall and landing reflex, the slope-slide controller, the reward of the PPO tracker, and the choice of a reaction in a fight.

### Fall and landing reflex (physics, evolved)

240 held-out shoves and drops of 0.4 to 2.6 m, the same for every row. Mean fracture risk per region (0 = none, 1 = certain); the cost is the weighted score the controller was evolved on, and the evolved row is the result of CMA-ES on that score (the contact model is soft tissue, 20 ms; the legs tolerate 10 body weights, the head 5).

| controller | injury cost | head | torso | arms | legs |
|---|---|---|---|---|---|
| statue (stiff, no reflex) | 3.72 | 0.46 | 0.67 | 0.44 | 0.71 |
| hand-made starting pose | 3.81 | 0.55 | 0.48 | 0.73 | 0.53 |
| evolved on bone-injury score | 1.61 | 0.02 | 0.01 | 0.61 | 0.78 |

The reflex nearly removes head and torso injury. The legs still carry 12 to 15 body weights in drops of 1 to 2.5 m (34 to 66 for the stiff body), which is better but above the leg tolerance, and the arms still take 1 to 6; those two columns stay high and are the weak part.

![fall reflex](images/procedural_motion/drop_2m.gif)

### Standing on a slippery slope (physics, evolved)

40 held-out slopes of 8 to 25 degrees and friction 0.12 to 0.4, scored with the same injury model (a slip that ends in a fall also hurts).

| controller | stays up 5 s | mean time up | mean slide |
|---|---|---|---|
| stiff body, no controller | 0% | 1.1 s | 0.44 m |
| evolved controller | 20% | 1.8 s | 0.25 m |

A partial result: the evolved controller helps, most slopes still end in a fall.

![slope](images/procedural_motion/slide_slope.gif)

## 9b. Water and air as physics (learned, poor)

The swimmer and the bird are physical bodies in a medium: water gives buoyancy, drag and flat palms and soles that push on it, with an oxygen budget that is spent while the mouth is under water; air gives wings and tail as plates with lift, stall and drag. Strokes and flapping are found by evolution against these forces. The models work, the results do not yet: the stroke is a flail (about 0.5 m/s, the goal on the bottom is not reached) and the bird glides about 3 s from 6 m, lands hard and does not take off. The kinematic swimming and flight in the showcase are hand-built.

![swimmer](images/procedural_motion/swim_surface.gif)
![bird](images/procedural_motion/bird_fly.gif)

## 9c. A pregnant body falls

The belly is a mass with a collision sphere and the highest weight in the injury score. The general reflex still leaves a belly risk of 0.55; a reflex evolved for this body brings it to 0.07 (cost 7.1 to 2.7) while the head stays safe.

![pregnant fall](images/procedural_motion/preg_shove_forward.gif)

## 10. On the shipped rig

The same motion, exported as world rotations of the mapped bones, drives `assets/characters/shared/mart.glb` in Blender (Workbench render). Only the bones that exist in that rig are mapped (spine, chest, head, legs, upper arms and forearms); there are no toe or clavicle bones in the map, and no furniture is drawn.

![on the rig](images/procedural_motion/game_walk_run.gif)

## 11. What does not work yet

* **The learned walking policy.** A PPO policy that follows the planner on a physical body holds only with an assist force on the pelvis; with the assist removed about two thirds of the episodes still fall (66 percent at the last iteration). It ran on the earlier skeleton; the code is kept and the pain term is in the reward, but it was not retrained.
* **Limbs in a fall.** The reflex protects the head and torso, but the arms and legs still take large forces on drops of a metre and more.
* **The physical swimmer and bird** (section 9b) work as physics and learn badly.
* **Authored parts.** Doors, beds, ladders, riding are goal sequences; swimming, diving, flight and the snake are hand-built.
* **Climbing** is a greedy search and can dead-end on a hard route.
* **Hit resolution** is geometric; the pain numbers are plausible, not clinical.
* **Rig retarget** is basic; a facial or finger layer, cloth and hair physics are absent.

## 12. How to rerun

See the commands in [Procedural motion (research)](../SYSTEMS/PROCEDURAL_MOTION.md). The gallery is `python make_showcase.py` and opens `runs/showcase/index.html`.
