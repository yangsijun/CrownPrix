<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Input

## Purpose
Digital Crown input handling utilities for converting raw crown rotation to steering parameters.

## Key Files

| File | Description |
|------|-------------|
| `CrownInputHandler.swift` | Stateless enum mapping normalized crown rotation (-1 to 1) to turnRate and targetSpeed via GameConfig constants |

## For AI Agents

### Working In This Directory
- `CrownInputHandler` is currently unused — its logic was moved directly into `PhysicsEngine`
- The crown rotation value comes from SwiftUI's `.digitalCrownRotation` modifier in `RaceView`
- If reactivating this handler, ensure it stays consistent with PhysicsEngine's steering math

### Testing Requirements
- QA tests validate crown input response: neutral → max speed, max turn → min speed, clamping, symmetry

### Common Patterns
- Namespace enum pattern (not instantiable, static methods only)

## Dependencies

### Internal
- `Config/GameConfig` — steering constants

### External
- CoreGraphics

<!-- MANUAL: -->
