# OpenClimber v2

**OpenClimber v2** is an open-source **3D urban climbing game** focused on a **custom physics-driven climbing system** designed to support a wide range of climbing techniques and environments.

This version has been **rebuilt from scratch** with a cleaner architecture and full compatibility with **Godot 4.x** (Forward+ renderer). The goal is to create a highly dynamic climbing framework where **climbable surfaces can be added freely** without requiring rework of core movement logic or animation sets.

---

## Key Goals

- Physics-based climbing interactions (not animation-dependent)
- Modular climbing system that supports arbitrary level design
- Realistic movement across common climbable surfaces (ledges, walls, etc.)
- Scalable system for more complex climbing geometry

---

## Procedural Motion, Not Animation

What sets OpenClimber apart is that **the character has no animations at all**. There are no clips, no skeleton and no animation state machine. Every frame, code works out where each joint should be from what the character is physically doing:

- **Climbing** — each hand and foot grips its own fixed point on the surface. Moving sends one limb at a time to a new hold, and the body is pulled after the planted limbs by a spring rather than being moved directly. Elbows and knees are solved to fit wherever the hands and feet are holding.
- **Hanging** — where there is nothing under the feet they come off, the arms straighten, and the character hangs and shimmies on the hands alone.
- **Walking and running** — one gait phase drives the legs, with stride, knee lift, lean and cadence scaling with speed.
- **Jumping** — the pose follows vertical velocity, reaching up while rising and bracing while falling.

Because motion is computed instead of played back, a new kind of climbable surface needs no new animation set: if the limbs can find holds on it, the character can climb it. The limbs are placed by rule and the body is spring-driven; it is not a full ragdoll simulation.

---

## Roadmap (v2.x)

### v2.0 — Ledges & Core Movement (**Released**)
- Realistic climbing and traversal on ledges
- Improved movement stability and edge interaction

### v2.1 — Character Redesign & Dynamic Surface Improvements (**In Progress**)

Done:
- [x] New procedural character rig built from cubes, with explicit joints per arm and leg (replaces the imported animated character)
- [x] Generic `ClimbableSurface` objects — any surface in the group can be climbed, no hard-coded ledge names
- [x] Grip-driven climbing — each hand and foot holds its own point, limbs move one at a time, and the body is pulled after them
- [x] Climbing on walls at arbitrary angles (the character aligns to the surface the hands are holding)
- [x] Ledges with the new character — hang, shimmy, and pull up where there is room to stand
- [x] Movement stops at the edges of a surface instead of running past them
- [x] Topping out onto a wall, stepping off at the floor, wall jump, and letting go
- [x] Blended transitions between ground, air, climb and pull-up
- [x] Distinct walk, run and jump motion; double jump
- [x] Keyboard (WASD / arrows) and gamepad controls, with camera-relative movement
- [x] Visual pass — re-proportioned character, materials, sky, lighting and fog
- [x] Obstacle course and a mountain with panels, ledges and a narrow strip to climb

Remaining:
- [ ] Play-test and tune the grip climbing (speed, body spring, hand placement on narrow strips)
- [ ] Moving between surfaces that meet at an angle, such as around a corner
- [ ] Overhangs and ceilings
- [ ] Refresh the preview screencast below, which predates the visual pass

Dev logs:
- [Dev log 1 — procedural character and generic surfaces](docs/v2.1/v2.1-dev-log.md)
- [Dev log 2 — grip climbing, look pass, and a course to climb](docs/v2.1/v2.1-dev-log-2.md)

### v2.2 — Ladders (**Planned**)
- Realistic ladder climbing and transitions
- Consistent mounting/dismounting behavior
- Improved interaction logic for ladder geometry

### v2.3 — Complex Surfaces & Advanced Environments (**Planned**)
- Support for more difficult and complex climbable surfaces
- Wider range of wall sections and geometry types
- Vertical tunnels and other non-standard climbing environments
- Expanded edge cases and robustness improvements

---

## Character Redesign (Started February 2026)

The new character system is in the game and is what v2.1 climbing is built on.

Instead of relying on large animation sets, the redesign uses a **custom simplified humanoid rig** built from primitive cubes, with every limb driven by explicit joints. Those joints are what the procedural motion above positions each frame, which is what lets the arms and legs adapt to whatever geometry they are climbing.

**Why this approach?**  
Traditional animation-based solutions scale poorly for this project’s scope, since the intent is to allow arbitrary climbable surfaces without needing to constantly redo animation logic or movement code.

---

## Installation

1. Download **Godot 4.7** or newer from the official website:  
   https://godotengine.org/download/
2. Open the project by selecting `project.godot` in Godot.

---

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move / climb | `WASD` or arrow keys | Left stick or D-pad |
| Jump, and once more in mid-air (jumps off a wall while climbing) | `Space` | A |
| Let go of a wall | `X` | B |
| Run | `Shift` | Right trigger or left stick click |
| Look around | Right mouse drag, wheel to zoom | Right stick |
| Recenter camera | `C` | Right stick click |

Jump towards a climbable panel to grab it. Each hand and foot then holds its own point on the surface: moving sends one limb at a time to a new hold and the body is pulled after them. Where there is nothing under the feet, such as on a ledge, the character hangs from the hands and can shimmy along. Climbing up past the top edge pulls the character onto the wall if there is room to stand.

---

## Preview

🎥 **Preview Screencast:**  
[Watch here](https://drive.google.com/file/d/1vDeq46uHeIsy6keVXTva3I7BqDe0_6jK/view?usp=drive_link)
