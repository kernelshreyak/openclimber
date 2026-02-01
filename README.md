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

## Roadmap (v2.x)

### v2.0 — Ledges & Core Movement (**Released**)
- Realistic climbing and traversal on ledges
- Improved movement stability and edge interaction

### v2.1 — Character Redesign & Dynamic Surface Improvements
- New character system to support procedural/dynamic climbing
- Improvements across standard climbable flat surfaces:
  - walls
  - ledges
- Better handling for dynamic climbable surface placement
- Overall system refinements and animation/physics transitions

### v2.2 — Ladders
- Realistic ladder climbing and transitions
- Consistent mounting/dismounting behavior
- Improved interaction logic for ladder geometry

### v2.3 — Complex Surfaces & Advanced Environments
- Support for more difficult and complex climbable surfaces
- Wider range of wall sections and geometry types
- Vertical tunnels and other non-standard climbing environments
- Expanded edge cases and robustness improvements

---

## Character Redesign (Started February 2026)

A new character system is currently in development to better support procedural climbing.

Instead of relying on large animation sets, the redesign uses a **custom ragdoll-like simplified humanoid rig**, initially built from primitive shapes (cuboids, cylinders, capsules). This enables tuning arm/leg positioning dynamically to adapt to diverse climbing geometry.

**Why this approach?**  
Traditional animation-based solutions scale poorly for this project’s scope, since the intent is to allow arbitrary climbable surfaces without needing to constantly redo animation logic or movement code.

---

## Installation

1. Download **Godot 4.x** from the official website:  
   https://godotengine.org/download/
2. Open the project by selecting `project.godot` in Godot.

---

## Preview

🎥 **Preview Screencast:**  
[Watch here](https://drive.google.com/file/d/1vDeq46uHeIsy6keVXTva3I7BqDe0_6jK/view?usp=drive_link)
