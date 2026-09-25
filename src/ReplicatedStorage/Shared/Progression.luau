-- NEON CITY: level, resort level and prestige math (pure functions, shared by server and client).

local Config = require(script.Parent.Config)

local Progression = {}

Progression.ResortLevelThresholds = { 0, 20, 60, 150, 300 }
Progression.ResortLevelNames = { "Small Resort", "Resort", "Big Resort", "Luxury Resort", "Mega Resort" }

-- XP needed to go from `level` to `level + 1`.
function Progression.XPForLevel(level)
	return 100 + 25 * (level - 1)
end

-- Applies `xp` gained on top of the current level/xp. Returns newLevel, newXP, levelsGained.
function Progression.ApplyXP(level, xp, gained)
	xp += gained
	local levelsGained = 0
	while level < Config.MaxLevel and xp >= Progression.XPForLevel(level) do
		xp -= Progression.XPForLevel(level)
		level += 1
		levelsGained += 1
	end
	if level >= Config.MaxLevel then
		level = Config.MaxLevel
		xp = math.min(xp, Progression.XPForLevel(level))
	end
	return level, xp, levelsGained
end

function Progression.ResortLevel(rating)
	local result = 1
	for index, threshold in ipairs(Progression.ResortLevelThresholds) do
		if rating >= threshold then
			result = index
		end
	end
	return result
end

function Progression.PrestigeIncomeMultiplier(prestige)
	local bonus = math.min(prestige * Config.Prestige.IncomeBonusPerPrestige, Config.Prestige.MaxIncomeBonus)
	return 1 + bonus
end

function Progression.PrestigeTitle(prestige)
	if prestige <= 0 then
		return nil
	end
	local titles = Config.Prestige.Titles
	return titles[math.min(prestige, #titles)]
end

-- Returns true/false plus a reason why a building is locked for this player state.
function Progression.CanUseBuilding(def, level, prestige, passes)
	if def.Pass and not (passes and passes[def.Pass]) then
		return false, "Requires " .. def.Pass .. " pass"
	end
	if def.Prestige and prestige < def.Prestige then
		return false, "Requires Prestige " .. def.Prestige
	end
	if level < def.Level then
		return false, "Unlocks at level " .. def.Level
	end
	return true, nil
end

return Progression
