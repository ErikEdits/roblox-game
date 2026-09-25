# PROGRESS

Development log as required by the design document (section 33).

## v0.3 – Customization, cars and city life (2026-09-26)

### Implemented

- **Free-roam cars**: CAR button spawns your own car anywhere (owner-only driving, auto-park when
  empty, removed on teleport / race). Cars collide through rounded skids so they glide over curbs.
- **Car bodies** for cash: Muscle Car, Drift Coupe (+ Hyper body via pass) – identical stats.
- **Building customization**: pick one of 8 neon accent colors per building (COLOR in edit mode).
- **Premium content** (clear, known contents): VIP Penthouse (VIP pass), Cyberpunk Pack pass
  (Neon Sofa, Neon Arch, Cyber Lamp, Holo Sign). Per-resort limits for unique/premium buildings.
- **Resort statistics** in the build menu (rating progress, operations income, visitors/income of
  the last 5 minutes).
- **City life**: NPC families walk as groups with kids, visitors comment on buildings (speech
  bubbles), visitors prefer player resorts 2x over city attractions.
- **Minimap** (PC): roads, plots (own plot gold), track, beach, players, current guide target.
- **Mobile**: UI scale uses the safe area (windows fit small landscape phones).

### Tests performed

- Luau compile (51 scripts), selene, API check: clean. Unit tests: 189.
- Simulator desktop: 217 checks, mobile (`MOBILE=1`, 844x332): 224 checks – 0 runtime errors.

## v0.2 – Content, polish and automated play-testing (2026-09-26)

### Implemented

- **Engine simulator test** (`tests/sim`): runs the built place in Lune with emulated events,
  humanoid movement, remotes and DataStores; plays through the whole game including the client UI.
  Found and fixed: the "My Resort" teleport landed outside the plot (tutorial step never
  completed), NPC visitor bookkeeping leak when a building was removed mid-visit.
- **Building upgrades** (level 1–3): more spend/passive income/appeal/rating, visuals, refunds
  include upgrade costs.
- **Tutorial** (6 steps, server-validated, guide beam to the plot, pulsing buttons, skip).
- **Neon Reflex** reaction minigame (server-timed), **Time Trial** race mode (global leaderboard
  of 1-lap times), optional **Delivery job** with timer and guide beam.
- **Lost & Found** event (collect wallets across the city; lowers Security while active).
- **Daily task pool**: 11 tasks, 5 picked per day for everyone (deterministic by date).
- **Social**: visit / like other resorts (once per day each), likes on plot signs.
- **DataStore session locking** (wait for other server, take over abandoned locks, release on leave).
- **Admin tools** (Studio / creator / `Config.Admins`): cash, levels, force events, tasks, tutorial.
- **AnalyticsService** custom events.
- **Visuals**: Neon Beach district, sidewalks, crosswalks, palms, billboards, benches, planters,
  tower window bands + blinking antennas, night sky, fountain particles, ambient neon animation,
  better building models, build grid overlay.
- **UI polish**: window pop animation, rolling cash counter, level-up celebration, toast fade,
  UI sounds (setting), PLAY hub (2x2), map with player resorts list.

### Tests performed

- Luau compile (49 scripts), selene lint, API check against the reflection database – all clean.
- Unit tests (163) and Card Rush simulation (7,804 checks).
- Simulator play-through: **176 checks, 0 runtime errors** (join, tutorial, building, upgrades,
  build UI, all panels, shop, Card Rush + Neon Reflex via UI, NPC visits, Street Race,
  Time Trial, Delivery, all 5 events, admin tools, likes/visits, leave/rejoin, stale-lock takeover).

### Known problems / risks

- Still no live play test in Roblox Studio (simulator emulates physics only roughly: car handling,
  NPC walking and collisions are not physically simulated).
- UI sounds use the built-in `electronicpingshort.wav`; replace with uploaded sounds if desired.

## v0.1 – MVP vertical slice (2026-09-25)

### Implemented

- **Foundation:** Rojo project, modular services (`Main.server.luau` boots 16 services in a fixed
  order), shared config/catalog modules, remotes declared in one place.
- **Data:** `DataService` – DataStore load with retries, defaults + reconcile + sanitisation,
  `UpdateAsync` saves, autosave every 120 s, `BindToClose`, in-memory fallback (Studio), never
  overwrites a save that failed to load.
- **Economy / progression:** cash, XP, levels 1–100, unlock notifications, leaderstats, resort
  rating → resort level 1–5, passive resort income, optional prestige (level 100, keeps buildings,
  +10 % income per prestige, titles).
- **Plots & building:** 16 plots, owner sign, 21 buildings / 7 categories, place / move / rotate /
  delete (50 % refund) / copy, 4-stud grid, server-side validation (level, pass, prestige, cost,
  bounds, overlap, limit 40), save & restore.
- **NPC visitors:** 6 types, capped count scaled by city tourism/popularity, avenue waypoint routing
  without pathfinding, collision groups so NPCs never get stuck, enter buildings and spend money for
  the owner (money pop-ups), static + event attractions.
- **Card Rush:** 7 server-generated question types, server-side timing, speed bonus, perfect bonus.
- **Racing:** Street Race lobby, up to 8 players, NPC racers fill to 4, 2 laps, server checkpoint
  validation, DNF handling, placement rewards, best times (OrderedDataStore leaderboard).
- **Events:** scheduler, City Blackout (repair generators), Live Concert (crowd rewards, NPCs go to
  the stage), VIP Night (boosted resorts), Race Rush (2× race rewards), participation rewards,
  plaza event board.
- **City simulation:** Power / Tourism / Security / Popularity.
- **Daily tasks:** 5 tasks, UTC reset, claim rewards; unique-visit tracking via `ZoneService`.
- **Shop / monetization:** car paints for cash, VIP Pass and Neon Hyper Car game passes (IDs to
  be configured), VIP lounge door, overhead VIP tag.
- **UI (mobile-first):** HUD (cash, level/XP, zone, city stats, event banner, toasts, next-goal
  hint), build menu + placement toolbar, Play hub, Card Rush screen, Shop, Tasks/Stats/Prestige,
  Map teleports, Settings (low graphics, NPC labels, reward pop-ups), race HUD.
- **Map:** generated by `tools/generate_map.py` (~600 parts, 10 point lights).

### Files

- `default.project.json`, `tools/generate_map.py`, `src/Workspace/*.model.json`
- `src/ReplicatedStorage/Shared/`: `Config`, `Buildings`, `BuildingModels`, `Progression`,
  `Placement`, `PlotUtil`, `Format`, `Remotes`, `Signal`
- `src/ServerScriptService/`: `Main.server.luau`, `Services/*` (Data, Economy, Monetization, Plot,
  Building, City, Quest, Shop, Player, Zone, NPC, Minigame, Race + CarFactory, Event, Leaderboard, World)
- `src/StarterPlayerScripts/`: `Client.client.luau`, `Controllers/*` (UI, State, Panels, HUD,
  BuildController, PlayPanel, ShopPanel, Menus, RaceHUD, VehicleController)
- `build/NEON_CITY.rbxl` (built place file)

### Tests performed

- Luau compile check of all 38 scripts (Luau 0.663 compiler) – 0 errors.
- `selene` lint (Luau std + Roblox globals) – 0 errors, 0 warnings.
- API check against Roblox's reflection database (rbx-dom, API version 728): every class,
  enum item and property used in scripts, map files and the project file exists. The checker was
  validated by injecting typos, which it caught.
- Unit tests (Luau, mocked Roblox) – 163 checks: money/time formatting, XP curve (131,175 XP to
  level 100), level cap, resort level, prestige multiplier, unlock rules, catalog sanity (grid,
  plot fit, categories, NPC types), placement snapping/clamping/overlap/rotation for every building.
- Card Rush simulation – 300 full rounds (7,804 checks): every question has exactly one valid
  answer set, too-fast / double / late answers are rejected, scores and stats add up.
- Map layout checked with a top-down render (districts, plots, track, spawns, attractions).
- Rojo build of `.rbxl`, hierarchy verified.

**Not yet done:** a live play test inside Roblox Studio (not available in the build environment).

### Known problems / risks

- Vehicle handling values (`Config.Race.Car*`) are untested in real physics and may need tuning.
- NPCs use Roblox's default R15 walk/idle animation IDs; if those fail to load, NPCs slide.
- No DataStore session locking (a very fast server hop could, in rare cases, load older data).
- Game pass IDs are `0` until created on the website (shop shows "not set up yet").
- `StreamingEnabled` is off (small map); revisit when the city grows.
- Money pop-ups and "Resort operations" toasts may feel noisy at high income – tune in Config.

### Next tasks

1. Play test in Studio (solo + 2-player local server: *Test > Clients and Servers*), tune car
   handling (`Config.Race.Car*`), NPC counts and prices.
2. v0.2 polish: build-mode grid overlay, better building art (Phase 2), sounds and music.
3. Tutorial / onboarding flow, analytics events (`AnalyticsService`).
4. More minigames (reaction, memory), Time Trial race mode, security-related events.
5. Session locking for DataStore, developer products if needed.
