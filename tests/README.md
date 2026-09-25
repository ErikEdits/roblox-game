# Tests

These run outside Roblox Studio (used by the AI coding agent during development).

| Test | What it does | Run |
|---|---|---|
| `sim/run.luau` | Loads `build/NEON_CITY.rbxl` in [Lune](https://lune-org.github.io/docs), emulates the engine parts that Lune lacks (events, humanoid movement, remotes, DataStores) and plays the whole game: join, tutorial, building, upgrades, build UI, all panels, shop, Card Rush via UI, NPC visits, a Street Race, all 4 events, teleports, leave/rejoin persistence. Fails on any runtime error. | `rojo build -o build/NEON_CITY.rbxl && lune run tests/sim/run.luau` |
| `api_check.py` | Checks every class / enum / property used in scripts and map files against Roblox's reflection database (from the `rbx_reflection_database` crate). | `pip install msgpack && python3 tests/api_check.py` |

Note: `sim/engine.luau` overrides a few reflected properties (e.g. `BasePart.Position`,
`Humanoid.Health`). Stock Lune only lets custom getters handle properties that are *not* in the
reflection database, so the simulator needs Lune built with custom getters/setters taking priority
(two small changes in `lune-roblox/src/instance/base.rs`: check `find_property_getter` /
`find_property_setter` before `find_property_info`).
