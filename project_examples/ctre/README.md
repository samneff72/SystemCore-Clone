# CTRE Example Projects

> [!CAUTION]
> **NOT YET TESTED ON HARDWARE.** The version alignment below (Phoenix 6 `26.70.0-alpha-2`,
> WPILib 2027 alpha-8, SystemCore OS 17) and the updated setup flow were researched from
> upstream release notes and source code. They have not been verified on a physical build yet.
> The example projects have not been compiled. Report what works and what doesn't before
> treating this as a release.

Commands v2 and v3 example robot projects targeting WPILib `2027.0.0-alpha-8`
(project year `2027_alpha7`) and Phoenix 6 `26.70.0-alpha-2`.

- [`ctre-commands-v2`](./ctre-commands-v2)
- [`ctre-commands-v3`](./ctre-commands-v3)

Each drives one TalonFX (ID 33) on `new CANBus(CANPort.CAN_S1)` and one on a CANivore named
`CANivore`. Device firmware must be `26.70.x`.
