# Procedural motion: existing solutions and licences

Status: research report, 2026-10-16. Web research only, no code changes. Companion to the [Procedural motion report](procedural_motion_report.md) and the system page [Procedural motion (research)](../SYSTEMS/MUSCLE_LOCOMOTION.md).

The question: which existing runtimes, training tools, research code, datasets and Godot addons can a commercial Godot 4.7 game use for a condition-adaptive motion layer? The layer is a small MLP, a few thousand weights. It reads condition channels (friction, cold, blood loss, wound site, pain per region, fatigue, ground sink, wind, vestibular noise) and outputs style parameters (stride, cadence, crouch, stance width, arm hug, hand to wound, tremor, wing-beat rate). Those parameters drive the existing kinematic planner and clip layer. Training runs offline in Python, the weights go to JSON, and the forward pass runs in GDScript.

Verdict key: **YES** means commercial use is allowed with no conditions beyond keeping the licence text. **YES-attr** means it is allowed with attribution or a notice. **NO** means the licence forbids commercial use. **UNCLEAR** means I could not read or confirm the terms. Licences were read on 2026-10-16 from the GitHub API licence field or the licence file itself, unless the text says otherwise. Code, pretrained weights and training data are judged separately. A permissive code licence does not clear the data a model was trained on.

## 1. Runtime inference in Godot

| Name | What it does | Licence | Verdict | Godot integration | Relevance |
|---|---|---|---|---|---|
| Pure GDScript forward pass (own code) | Dense layers plus tanh or ReLU over `PackedFloat32Array` | Own code | YES | Trivial. Two layers of 32 to 64 units cost a few thousand multiply-adds per character per tick | Best fit for an MLP of a few thousand weights. No native binaries and no platform risk |
| [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents) | RL bridge between Godot and SB3, CleanRL, rllib and Sample Factory. Exports policies to ONNX | MIT | YES | ONNX inference needs the **.NET (C#) build** of Godot. The README calls ONNX support "experimental" | Useful if we ever train inside Godot. The C# requirement is a cost for a GDScript project |
| [iree.gd](https://github.com/iree-gd/iree.gd) | GDExtension that wraps the IREE runtime. Runs compiled PyTorch or TFLite models | MIT (IREE itself: [Apache-2.0](https://github.com/iree-org/iree)) | YES-attr | Build from source with CMake and submodules. No published releases. Metal on macOS and iOS, Vulkan on Windows, Linux and Android | Too heavy for a tiny MLP. Worth a look only if networks grow past about 100k weights |
| [godot_onnx_extension](https://github.com/joemarshall/godot_onnx_extension) | `OnnxRunner.load_model` / `run(PackedFloat32Array)` | MIT (ONNX Runtime: [MIT](https://github.com/microsoft/onnxruntime)) | YES | Small project: 41 commits, no releases, last push 2024-02. We would have to build and maintain it per platform | Same as above. An option, not needed now |
| [Godot-ONNX-AI-Models-Loaders](https://github.com/mat490/Godot-ONNX-AI-Models-Loaders) | C++ GDExtension with an `ONNXLoader` node | MIT | YES | Early stage. Windows binaries only, as far as I could see | Low |
| [Godot-Torch](https://github.com/joshuadahlunr/Godot-Torch) | LibTorch wrapper | No licence file | NO (all rights reserved by default) | Abandoned in 2023 | None. LibTorch adds hundreds of MB anyway |
| GDScript NN addons: [mohsenph69/Godot-Neural-Networks](https://github.com/mohsenph69/Godot-Neural-Networks) (MIT, 2022), [ZeroLikviz/godot_plugin-neural-network](https://github.com/ZeroLikviz/godot_plugin-neural-network) (BSD-2-Clause, 2025), [SinaMajdieh/godot-neural-network](https://github.com/SinaMajdieh/godot-neural-network) (MIT, GPU compute) | Small trainable MLPs in Godot | MIT / BSD-2 | YES-attr | Drop-in addons, but they are not used as libraries: we would only borrow ideas | Our forward pass is about 30 lines, so writing it ourselves is simpler than taking a dependency |

Verdict for section 1: write the forward pass in GDScript. If profiling ever shows a need, port the same JSON weights to a small GDExtension C++ function (no ONNX). Keep ONNX Runtime GDExtensions in reserve; both candidates are MIT but immature.

## 2. Training frameworks (offline, not shipped)

| Name | Licence | Verdict | Notes |
|---|---|---|---|
| [MuJoCo](https://github.com/google-deepmind/mujoco) | Apache-2.0 | YES | CPU simulator. Runs on macOS natively |
| [MuJoCo MJX / Playground](https://github.com/google-deepmind/mujoco_playground) | Apache-2.0 | YES | JAX GPU training. On macOS it is CPU-only in practice, so it pays off only on a Linux and NVIDIA box |
| [dm_control](https://github.com/google-deepmind/dm_control) | Apache-2.0 | YES | Includes `suite/dog.xml`, a full dog skeleton with spine, tail, jaw and four legs, and a rodent. The XML has no per-file header; the repo-level Apache-2.0 applies, but the mesh assets need a check before redistribution |
| [MuJoCo Menagerie](https://github.com/google-deepmind/mujoco_menagerie) | Per model (repo licence field: NOASSERTION) | Check each model | Robot quadrupeds (Unitree, ANYmal, Spot), humanoids, `flybody`. No real animals except the fly |
| [Brax](https://github.com/google/brax) | Apache-2.0 | YES | JAX physics plus PPO and ES |
| [Isaac Gym](https://developer.nvidia.com/isaac-gym) (Preview 4) | NVIDIA proprietary evaluation EULA, accepted at [download](https://developer.nvidia.com/isaac-gym/download) | UNCLEAR, treat as NO | Deprecated by NVIDIA and Linux plus NVIDIA only. [IsaacGymEnvs](https://github.com/isaac-sim/IsaacGymEnvs) code is BSD-3 (archived), but it needs the Gym binary |
| [Isaac Lab](https://github.com/isaac-sim/IsaacLab) | BSD-3-Clause | YES for code | Requires Isaac Sim. [Isaac Sim](https://github.com/isaac-sim/IsaacSim) source is Apache-2.0, but it depends on Omniverse Kit and assets under the [Isaac Sim Additional Software and Materials License](https://www.nvidia.com/en-us/agreements/enterprise-software/isaac-sim-additional-software-and-materials-license/). Only the trained weights would ship, so it is probably fine, but this is heavy and needs an NVIDIA GPU |
| [stable-baselines3](https://github.com/DLR-RM/stable-baselines3) | MIT | YES | PPO and SAC in PyTorch |
| [CleanRL](https://github.com/vwxyzjn/cleanrl) | MIT | YES | Single-file RL. Easy to adapt |
| [evosax](https://github.com/RobertTLange/evosax) | Apache-2.0 | YES | JAX evolution strategies |
| [pycma](https://github.com/CMA-ES/pycma) | BSD-3-Clause | YES | CMA-ES on numpy. Well suited to a few thousand parameters |
| [EvoTorch](https://github.com/nnaisense/evotorch) | Apache-2.0 | YES | ES on PyTorch |
| [PyTorch](https://github.com/pytorch/pytorch) | BSD-3-style | YES | |

Weights we train ourselves, with our own reward or targets, belong to us whatever tool trained them. Only the training data matters (section 3).

## 3. Learned character-control research code and datasets

| Name | What it does | Code licence | Weights / data | Verdict |
|---|---|---|---|---|
| [DeepMimic](https://github.com/xbpeng/DeepMimic) | Physics policy imitates mocap clips. Humanoid, plus a dog in the paper | MIT | Clip provenance in `data/motions` is not documented in the README | Code YES. Clips UNCLEAR, so do not ship policies trained on them |
| [MimicKit](https://github.com/xbpeng/MimicKit) (Peng) | DeepMimic, AMP, ASE, ADD, LCP and others in one framework. Isaac Gym, Isaac Lab or Newton backends | Apache-2.0 | Motion data comes from a separate download with no licence stated | Code YES. Data UNCLEAR. This is the permissive way to get AMP and ASE ideas |
| [ASE](https://github.com/nv-tlabs/ASE) (AMP/ASE, NVIDIA) | Adversarial skill embeddings | **NVIDIA License, s.3.3: "non-commercially ... research or evaluation purposes only"** | Reallusion sword-and-shield clips | **NO** |
| [CALM](https://github.com/NVlabs/CALM) | Conditional adversarial latent models, built on ASE | **NVIDIA License, same non-commercial clause** | Reallusion clips | **NO** |
| [IsaacGymEnvs](https://github.com/isaac-sim/IsaacGymEnvs) AMP tasks | AMP humanoid reference | BSD-3 | CMU-derived clips | Code YES-attr, but it needs the Isaac Gym binary (section 2) |
| [ProtoMotions](https://github.com/NVlabs/ProtoMotions) (includes MaskedMimic) | Large-scale physics humanoid control | Apache-2.0 | Trained on **AMASS (non-commercial)** with **SMPL bodies** (non-commercial); also BONES-SEED, whose licence is gated | Code YES. Its pretrained weights: **NO** |
| [PHC](https://github.com/ZhengyiLuo/PHC) | Perpetual humanoid control | BSD-3-Clause-Clear | AMASS plus SMPL | Code YES. Weights **NO** |
| [Meta Motivo](https://github.com/facebookresearch/MetaMotivo) / [HumEnv](https://github.com/facebookresearch/humenv) | Behavioural foundation model | **CC BY-NC 4.0** | AMASS | **NO** |
| [AI4Animation](https://github.com/sebastianstarke/AI4Animation) (PFNN successors MANN for quadrupeds, NSM, LMP, DeepPhase) | Neural kinematic controllers. MANN is the reference for dog gaits | README: "only for research or education purposes, and not freely available for commercial use"; mocap is **CC BY-NC 4.0** (this includes the MANN dog data) | **NO** | Ideas only (gating, phase) |
| [PFNN](https://theorangeduck.com/page/phase-functioned-neural-networks-character-control) (Holden 2017) | Phase-functioned net | No licence on the page or in the README; code and data ship in `pfnn.zip` | UNCLEAR, treat as NO | Ideas only |
| [orangeduck/Motion-Matching](https://github.com/orangeduck/Motion-Matching) | Motion matching plus Learned Motion Matching (decompressor, stepper, projector) in C++ | MIT | Uses the LAFAN1 data, **CC BY-NC-ND 4.0** | Code YES-attr, data **NO**. We can re-train on CC BY data |
| Learned Motion Matching (Ubisoft, Holden et al. 2020), [DReCon](https://montreal.ubisoft.com/en/drecon-data-driven-responsive-control-of-physics-based-characters/) (2019), SuperTrack (2021) | Ubisoft La Forge papers | Not released as code, except Holden's reimplementation above | n/a | Inspiration only |
| [LAFAN1](https://github.com/ubisoft/ubisoft-laforge-animation-dataset) | 4.6 h of human locomotion | n/a | **CC BY-NC-ND 4.0** | **NO** |
| [ZeroEGGS](https://github.com/ubisoft/ubisoft-laforge-ZeroEGGS) | Gesture data | Repo licence field: NOASSERTION, not read in full | Assumed NC like LAFAN1 | UNCLEAR |
| [AMASS](https://amass.is.tue.mpg.de/license.html), [SMPL/SMPL-X](https://smpl-x.is.tue.mpg.de/modellicense.html) | Unified mocap corpus and body model | n/a | Non-commercial. SMPL-X also bars training networks for commercial use. Commercial SMPL is sold by [Meshcapade](https://meshcapade.notion.site/The-SMPL-Model-Licenses-2144560e54388085af5eff111fcdf266) (tiered annual fee) | **NO** |
| [CMU Graphics Lab Mocap](http://mocap.cs.cmu.edu/) | 2,600 human clips, BVH conversions available | n/a | Front page: "free for all uses". The FAQ (not re-read: TLS failure) traditionally adds "do not resell the data directly" | **YES** for training. Do not redistribute the raw clips |
| [100STYLE](https://www.ianxmason.com/100style/) (Mason) | 100 locomotion styles, 60 fps XSens BVH. Styles include **Drunk, Old, LimpLeft and LimpRight, DragLeftLeg and DragRightLeg, Depressed, Crouched, WalkingStick, Balance, SlideFeet, InTheDark, Stiff, Rushed** | n/a | **CC BY 4.0**. Credit "The 100STYLE Dataset - Ian Mason" | **YES-attr**. The most relevant data we found for drunk, limp, old and slip-like targets |
| [BONES-SEED](https://huggingface.co/datasets/bones-studio/seed) | About 142k humanoid motions | n/a | Gated "BONES-SEED License" that I could not read. NVIDIA's [timeline annotations](https://huggingface.co/datasets/nvidia/SEED-Timeline-Annotations) are CC BY 4.0, but that covers only the annotations | UNCLEAR. Ask licensing@bones.studio |
| [Mixamo](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400) | Rigged clips | n/a | The FAQ allows commercial use in projects, but **"the only research application Mixamo content can't be used in is training machine-learning models"**, and raw files must not be redistributed (FAQ copy from 2022) | Using clips in the game: YES. **Training: NO** |

None of the learned *quadruped* datasets we found (the MANN dog) allows commercial use. Animal motion has to come from our own planner, our own physics optimisation (MuJoCo with the dm_control dog, Apache-2.0), or hand-keyed reference.

## 4. Godot-native procedural animation

| Name | What it does | Licence | Verdict | Effort / relevance |
|---|---|---|---|---|
| Godot core `SkeletonModifier3D` stack ([class list](https://docs.godotengine.org/en/latest/classes/class_skeletonmodifier3d.html)) | Since [4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/): `TwoBoneIK3D`, `ChainIK3D` → `SplineIK3D`, `IterateIK3D` → `FABRIK3D` / `CCDIK3D` / `JacobianIK3D`, plus `BoneConstraint3D` (4.5), `BoneTwistDisperser3D`, `LimitAngularVelocityModifier3D`, `LookAtModifier3D`, `SpringBoneSimulator3D`, `PhysicalBoneSimulator3D` | MIT (engine) | YES | Already in 4.7. This is the natural place to apply MLP style outputs: a modifier after the clip layer. There is no built-in foot placement or slope logic; we supply targets from raycasts |
| [Godot Jolt](https://github.com/godot-jolt/godot-jolt) / [JoltPhysics](https://github.com/jrouwe/JoltPhysics) | Physics engine. Built into Godot core since 4.4; the extension is in maintenance mode | MIT | YES | Use the core module. Gives ragdoll and physical bones for falls and hits |
| [many_bone_ik](https://github.com/V-Sekai/many_bone_ik) (V-Sekai) | Multi-chain constrained IK, engine module | MIT | YES-attr | Engine module (needs a custom build). Largely superseded by the 4.6 core IK |
| [RenIK](https://github.com/MMMaellon/renik) | Humanoid limb IK plus foot placement, engine module | MIT | YES-attr | Small (30 commits). Godot 4 status not stated. Reference for foot placement |
| [BobMervell/Procedural-Animation](https://github.com/BobMervell/Procedural-Animation) | Addon of procedural leg and step nodes | MIT | YES-attr | 8 stars. Reference only |
| [TheBogdichHD/procedural-animation-godot](https://github.com/TheBogdichHD/procedural-animation-godot) | Quadruped procedural animation for Godot 4.4 | MIT | YES-attr | Tiny demo. Reference only |
| [CBerry22/Godot-4.0-Procedural-Animation](https://github.com/CBerry22/Godot-4.0-Procedural-Animation), [jegor377/ProceduralWalk](https://github.com/jegor377/ProceduralWalk) | Tutorial-grade spider and humanoid walkers | MIT | YES-attr | Reference only |
| [Johnz86/locomotion-godot](https://github.com/Johnz86/locomotion-godot), [MeroVinggen spider](https://github.com/MeroVinggen/Godot-Spider-Procedural-Animation), [Gecko](https://github.com/Neurotremolo/Gecko) | Foot-placement IK and layered locomotion; spider; gecko | **No licence file** | NO (copyright by default) | Do not copy |

None of these models slipping, mud sink, snow drag or condition-driven style. Terrain foot placement exists only as simple raycast IK. Our planner is already ahead of every addon we found.

## 5. Commercial middleware (reference only)

| Name | Status / cost | Usable from Godot? |
|---|---|---|
| [Euphoria](https://en.wikipedia.org/wiki/Euphoria_(software)) (NaturalMotion) | Licensing ended in 2017 ([PocketGamer.biz](https://www.pocketgamer.biz/news/65937/naturalmotion-ends-commercial-tech-licensing-business/)). Lives on in Rockstar's RAGE | No |
| [Cascadeur](https://cascadeur.com/payment/tariffs/) | Offline physics-assisted keyframing (AutoPhysics). Indie $96/yr (under $100k revenue), Pro $396/yr; annual plans become perpetual after 12 months | As an authoring tool only: export FBX or glTF clips. Useful for hand-keyed animal reference clips we own |
| Unreal Motion Matching / Pose Search, Mover | Part of UE5. UE licence (5% royalty over $1M gross) | No, engine-locked. Its design (trajectory plus pose features, chooser tables) is public in UE docs |
| Unity Kinematica | "On hold" since [Q2 2021](https://discussions.unity.com/t/animation-status-update-q2-2021/844689), effectively dead | No |
| [PuppetMaster](https://assetstore.unity.com/packages/tools/physics/puppetmaster-48977) (RootMotion) | Active ragdoll, $90 per seat, Unity-only | No (Asset Store EULA, Unity-only). Its idea of a muscle-driven ragdoll pinned to animation can be rebuilt with Jolt plus `PhysicalBoneSimulator3D` |
| Active ragdoll (general) | Many open Unity and Unreal samples | Ideas only |

## 6. Bird flight

| Name | What it does | Licence | Verdict |
|---|---|---|---|
| [Flappy Hummingbird](https://github.com/purdue-biorobotics/flappy) (Purdue, ICRA 2019) | Flapping-wing dynamics, Gym interface, PID and RL controllers | MIT | YES-attr. Old stack (DART 6.2.1, TF < 2.0). Useful mainly for its wing-force model |
| [Data-driven control of flapping flight](https://mrl.snu.ac.kr/research/ProjectBird/birdFlight.htm) (Ju et al., TOG 2013) | Simulated dove learning wingbeats from mocap | Download offered, licence not stated | UNCLEAR. Inspiration only |
| [flybody](https://github.com/TuragaLab/flybody) | MuJoCo fruit fly with learned flight and walking | Apache-2.0 | YES. Insect, not bird. Shows wing-actuator RL in MuJoCo |
| [PteraSoftware](https://github.com/MOLOCH-dev/PteraSoftware) | Unsteady vortex-lattice aerodynamics for flapping wings | Not checked | Inspiration for lift and drag tables |
| Boids (Reynolds 1987) plus kinematic wing cycles | Flocking and banking | Public method | YES. What games ship |
| "How to Train Your Dragon" (Won et al., SIGGRAPH Asia 2017) | Example-guided flapping-flight control | Code not found | Inspiration only |

We found no permissive, game-ready learned bird controller. The practical route is a kinematic wing cycle whose rate, amplitude and glide ratio come from the MLP (wind, wet plumage, cold, injury), plus a cheap quasi-steady lift and drag model for banking and stalls.

## 7. Recommendation

**Adopt now:**
- Inference: a GDScript dense forward pass that reads JSON weights. No dependency, deterministic, works on every export platform. Port the same math to a GDExtension C++ function only if the profiler asks for it. Keep ONNX (MIT [godot_onnx_extension](https://github.com/joemarshall/godot_onnx_extension), MIT [iree.gd](https://github.com/iree-gd/iree.gd)) in reserve for larger nets.
- Training: MuJoCo (Apache-2.0) with the dm_control dog and our own humanoid and animal MJCF; numpy or PyTorch (BSD-3); pycma CMA-ES (BSD-3) for a few thousand weights; SB3 or CleanRL (MIT) if gradient RL is needed. Brax or MJX (Apache-2.0) only on a Linux GPU box.
- Data: 100STYLE (CC BY 4.0, add a credit line to CREDITS) as supervised targets for drunk, limp, old, crouched, balance and slide-feet style vectors; CMU mocap (free for all uses, do not redistribute raw clips) for baseline gait statistics; our own planner and physics rollouts for animals and conditions with no mocap (ice, mud, snow, cold, bleeding).
- Godot side: the core 4.6+ IK modifiers and Jolt (MIT) for the application layer and ragdoll falls.

**Avoid (licence):** ASE, CALM and other NVIDIA-License repos (non-commercial); AI4Animation, MANN dog data and PFNN (non-commercial or unstated); LAFAN1 and other Ubisoft La Forge data (CC BY-NC-ND); AMASS, SMPL and every pretrained weight trained on them (ProtoMotions, MaskedMimic, PHC, Meta Motivo); Mixamo as ML training data; Isaac Gym Preview (proprietary, deprecated); unlicensed Godot repos.

**Inspiration only:** DReCon, SuperTrack, Learned Motion Matching (Holden's MIT code is usable, but only with re-trained, cleared data), AMP and ASE discriminators (permissively available through MimicKit), MANN gating for quadruped gaits, Euphoria and PuppetMaster active ragdolls, UE Motion Matching, bird-flight papers.

**Not verified:** BONES-SEED licence (gated); CMU FAQ wording (TLS failure; front page read); Mixamo terms after 2022; Menagerie per-model licences; DeepMimic and MimicKit motion-clip provenance; PFNN zip contents; Isaac Gym Preview 4 EULA text.
