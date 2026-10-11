"""Anatomy and solved-contact regression cases, independent of Blender."""
import math
import unittest
from tools.assets.mammal_limb_anatomy import landmarks, cycle, pose_points, distance

PARAMETERS={
    'dog':(.4,.11,-.23,.24),'forge_cat':(.29,.095,-.17,.18),
    'fox':(.32,.075,-.20,.20),'sheep':(.46,.15,-.24,.26),
    'goat':(.49,.12,-.22,.22),'pig':(.34,.17,-.26,.29),
    'boar':(.44,.17,-.26,.29),'hare':(.22,.07,-.12,.13),
    'rat':(.095,.039,-.075,.09),
}

class MammalLimbAnatomyTests(unittest.TestCase):
    def test_hind_stifle_is_forward_of_hip_and_hock_is_raised(self):
        for species,p in PARAMETERS.items():
            for limb in landmarks(species,*p):
                root,knee,ankle,ball,toe=limb.points
                with self.subTest(species=species,limb=limb.suffix):
                    self.assertGreater(ankle[2],ball[2]*2)
                    self.assertLess(toe[1],ball[1])
                    if limb.hind:
                        self.assertLess(knee[1],root[1])
                        self.assertGreater(ankle[1],knee[1])
                    else:
                        self.assertGreater(knee[1],root[1])
                        self.assertLess(ankle[1],knee[1])

    def test_full_cycles_preserve_bone_lengths_and_planted_feet(self):
        for species,p in PARAMETERS.items():
            limbs=landmarks(species,*p)
            for running in (False,True):
                for frame in range(201):
                    contact=0
                    for limb in limbs:
                        points,planted=cycle(species,limb,frame/200,running)
                        for i in range(4):
                            self.assertAlmostEqual(distance(points[i],points[i+1]),distance(limb.points[i],limb.points[i+1]),places=7)
                        lift=points[3][2]-limb.points[3][2]
                        self.assertGreaterEqual(lift,-1e-8)
                        if planted:
                            contact+=1;self.assertAlmostEqual(lift,0,places=8)
                    self.assertGreaterEqual(contact,2,(species,running,frame))

    def test_walk_has_four_distinct_lift_events(self):
        for species,p in PARAMETERS.items():
            if species=='hare':continue
            events=[]
            for limb in landmarks(species,*p):
                flags=[cycle(species,limb,i/400)[1] for i in range(401)]
                events.append(next(i for i in range(1,401) if flags[i-1] and not flags[i]))
            self.assertEqual(len(set(events)),4,species)
            landings=[]
            for limb in landmarks(species,*p):
                flags=[cycle(species,limb,i/400)[1] for i in range(400)]
                landings.extend((i,limb.suffix) for i in range(400) if flags[i] and not flags[i-1])
            self.assertEqual([suffix for _,suffix in sorted(landings)],['LB','LF','RB','RF'],species)

    def test_digit_and_hind_foot_species_differences(self):
        for species in ('dog','forge_cat','fox'):
            self.assertTrue(all(l.digits==4 for l in landmarks(species,*PARAMETERS[species])))
        rat=landmarks('rat',*PARAMETERS['rat'])
        self.assertEqual([l.digits for l in rat],[4,5,4,5])
        hare=landmarks('hare',*PARAMETERS['hare'])
        self.assertGreater(distance(hare[1].points[2],hare[1].points[4]),2*distance(hare[0].points[3],hare[0].points[4]))
        for species in ('hare','rat'):
            for limb in landmarks(species,*PARAMETERS[species]):
                if limb.hind:
                    self.assertGreater(distance(limb.points[2],limb.points[3]),2*distance(limb.points[3],limb.points[4]))
        for species in ('sheep','goat','pig','boar'):
            self.assertTrue(all(l.hoof and l.digits==2 for l in landmarks(species,*PARAMETERS[species])))

    def test_rest_and_cycle_seams(self):
        for species,p in PARAMETERS.items():
            for limb in landmarks(species,*p):
                for a,b in zip(pose_points(limb),limb.points):
                    self.assertLess(distance(a,b),1e-7)
                for running in (False,True):
                    for a,b in zip(cycle(species,limb,0,running)[0],cycle(species,limb,1,running)[0]):
                        self.assertLess(distance(a,b),1e-12)

if __name__=='__main__':unittest.main()
