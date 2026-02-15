class_name PhysicsConfig

## Phrame = physics/evolution frame. Visual ticks interpolate between phrames.
const PHRAME_HZ: int = 6
const PHRAME_DT: float = 1.0 / PHRAME_HZ  # ~0.167s per phrame

## Godot physics tick rate — must match project.godot [physics] setting.
## With PHRAME_HZ == PHYSICS_TICKS_HZ, one phrame is consumed per physics tick.
const PHYSICS_TICKS_HZ: int = 6

## Numerical stability limit for C++ evolution substeps within one phrame
const MAX_SUBSTEP_DT: float = 0.02
