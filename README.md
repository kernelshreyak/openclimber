# OpenClimber v2

**OpenClimber v2** is an open-source **3D urban climbing game** focused on a **custom physics-driven climbing system** designed to support a wide range of climbing techniques and environments.

This version is being **rebuilt from scratch** with a cleaner architecture and full compatibility with **Godot 4.x** (Forward+ renderer). The goal is to create a highly dynamic climbing framework where **climbable surfaces can be added freely** without requiring rework of core movement logic or animation sets.

---

## Key Goals

- Physics-based climbing interactions (not animation-dependent)
- Modular climbing system that supports arbitrary level design
- Realistic movement on:
  - ledges
  - ladders
  - climbable wall segments

---

## Roadmap (v2.x)

### v2.0 — Ledges
- Realistic climbing and traversal on ledges
- Improved movement stability and edge interaction

### v2.1 — Ladders
- Realistic ladder climbing and transitions
- Consistent mounting/dismounting behavior

### v2.2 — Climbable Walls
- Realistic climbing on wall sections
- Support for dynamic climbable surface placement

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
