# ADR 0020: Kalev character realism

## Status
Superseded by [ADR 0022](0022-realistic-human-characters.md) on 2026-09-26: realism now applies to every human, built on the MakeHuman CC0 base. Originally accepted by maintainer direction, 2026-09-12: improve the main character toward The Witcher 3 type of realism and support changing clothes, armour and weapons.

## Context
P0-206 brought the generated grounded character set into gameplay. Kalev still has a simple smooth face, cap-like hair and inflated clothing. The existing wardrobe supports separately skinned mesh layers and fitted equipment.

## Decision
P0-210 replaces Kalev’s stylized surface treatment with adult facial anatomy, restrained natural coloration, groomed hair, textile structure and worn leather. The Witcher 3 is a fidelity reference, not a source of game assets or a promise of equivalent production quality. All geometry and material maps remain original and reproducible. Keep shared bone names, animation clips, stable IDs and wardrobe APIs. Fit Kalev’s wearables to the revised model. No new gameplay system or playable scope enters production; the previous Kalev stylized finish is superseded within the same hero budget. NPC and environment direction remains unchanged.

## Alternatives
More uniform subdivision would retain the same stylized forms. Replacing the rig would needlessly disrupt equipment and animation compatibility. Copying third-party game meshes is excluded.

## Consequences
Kalev is a scoped exception to ADR 0018’s anime shape treatment. Budget remains 60,000 body triangles and 2048-pixel textures. Cloth uses skinning; finger articulation, facial performance and cloth simulation remain separate work. Review closeups and animated wardrobe combinations in Godot.
