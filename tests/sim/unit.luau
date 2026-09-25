--!nocheck
-- Pure-logic unit tests for shared modules (formatting, progression, catalog, placement).
-- Run: lune run tests/sim/unit.luau
local process = require("@lune/process")
local Engine = require("./engine")
local game = Engine.Load(process.args[1] or "build/NEON_CITY.rbxl")
local Shared = game.ReplicatedStorage.Shared
local Config = Engine.Require(Shared.Config)
local Buildings = Engine.Require(Shared.Buildings)
local Progression = Engine.Require(Shared.Progression)
local Placement = Engine.Require(Shared.Placement)
local Format = Engine.Require(Shared.Format)

local passes, failures = 0, 0
local function check(cond, msg)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. msg)
	end
end

-- Format
check(Format.Money(1234567) == "$1,234,567", "Money " .. Format.Money(1234567))
check(Format.Money(999) == "$999", "Money small")
check(Format.Money(1000) == "$1,000", "Money 1000 " .. Format.Money(1000))
check(Format.ShortMoney(12500) == "$12.5K", "Short " .. Format.ShortMoney(12500))
check(Format.ShortMoney(3000000) == "$3M", "Short M " .. Format.ShortMoney(3000000))
check(Format.ShortMoney(950) == "$950", "Short small")
check(Format.Time(125) == "2:05", "Time")
check(Format.RaceTime(65.5) == "1:05.50", "RaceTime " .. Format.RaceTime(65.5))

-- Progression
local lvl, xp, gained = Progression.ApplyXP(1, 0, 100)
check(lvl == 2 and xp == 0 and gained == 1, "levelup exact")
lvl, xp = Progression.ApplyXP(1, 0, 99)
check(lvl == 1 and xp == 99, "no levelup")
lvl, xp = Progression.ApplyXP(1, 0, 10^9)
check(lvl == Config.MaxLevel, "cap level")
local total = 0
for l = 1, 99 do total += Progression.XPForLevel(l) end
print("XP needed for level 100:", total)
check(Progression.ResortLevel(0) == 1 and Progression.ResortLevel(20) == 2 and Progression.ResortLevel(1000) == 5, "resort level")
check(Progression.PrestigeIncomeMultiplier(0) == 1 and math.abs(Progression.PrestigeIncomeMultiplier(3) - 1.3) < 1e-9, "prestige mult")
check(Progression.PrestigeIncomeMultiplier(99) == 2, "prestige cap")
local ok = Progression.CanUseBuilding(Buildings.Get("hotel"), 1, 0, {})
check(not ok, "hotel locked lvl1")
ok = Progression.CanUseBuilding(Buildings.Get("vip_sign"), 50, 0, {})
check(not ok, "vip sign needs pass")
ok = Progression.CanUseBuilding(Buildings.Get("vip_sign"), 1, 0, { VIP = true })
check(ok, "vip sign with pass")

-- Buildings catalog sanity
for _, def in ipairs(Buildings.List) do
	check(def.Size[1] % Config.GridSize == 0 and def.Size[2] % Config.GridSize == 0, def.Id .. " grid size")
	check(def.Size[1] <= Config.PlotSize and def.Size[2] <= Config.PlotSize, def.Id .. " fits plot")
	check(table.find(Buildings.Categories, def.Category) ~= nil, def.Id .. " category")
	check(type(def.Cost) == "number" and def.Cost >= 0, def.Id .. " cost")
	for t in pairs(def.Appeal) do check(Config.NPC.Types[t] ~= nil, def.Id .. " appeal type " .. t) end
end

-- Placement
local motel = Buildings.Get("motel") -- 20x16
local x, z = Placement.Normalize(motel, 3, 3, 0)
check(x == 2 and z == 4, ("snap motel %s %s"):format(x, z))
x, z = Placement.Normalize(motel, 1000, -1000, 0)
check(x == 30 and z == -32, ("clamp motel %s %s"):format(x, z))
local valid = Placement.IsValid(motel, x, z, 0, {}, nil)
check(valid, "clamped valid")
x, z = Placement.Normalize(motel, 1000, 0, 1) -- rotated 16x20
check(x == 32, "rotated clamp " .. x)
check(Placement.IsValid(motel, x, z, 1, {}, nil), "rotated valid")
local existing = { { Id = "motel", X = 0, Z = 0, R = 0, Uid = 1 } }
check(not Placement.IsValid(motel, 4, 4, 0, existing, nil), "overlap detected")
check(Placement.IsValid(motel, 4, 4, 0, existing, 1), "ignore own uid when moving")
check(Placement.IsValid(motel, 20, 0, 0, existing, nil), "touching edges allowed")
check(not Placement.IsValid(motel, 44, 0, 0, {}, nil), "outside plot")
check(not Placement.IsValid(motel, 0, 0, 5, {}, nil), "bad rotation")
-- Every building: normalized positions are always valid on an empty plot, all rotations
for _, def in ipairs(Buildings.List) do
	for rot = 0, 3 do
		for _ = 1, 30 do
			local px, pz = Placement.Normalize(def, math.random(-60, 60), math.random(-60, 60), rot)
			if not Placement.IsValid(def, px, pz, rot, {}, nil) then
				check(false, "normalize invalid " .. def.Id)
			end
		end
	end
end

Engine.Stopped = true
print(("%d passed, %d failed"):format(passes, failures))
process.exit(failures == 0 and 0 or 1)
