-- QuestService: daily tasks that reset at 00:00 UTC. All progress is tracked server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local QuestService = {}

local services
local byId = {}
for _, def in ipairs(Config.DailyTasks) do
	byId[def.Id] = def
end

local function today()
	return os.time() // 86400
end

local function ensureToday(data)
	local day = today()
	if data.Quests.Day ~= day then
		data.Quests = { Day = day, Progress = {}, Claimed = {}, Visited = {} }
		return true
	end
	return false
end

function QuestService.Increment(player, id, amount)
	local data = services.DataService.Get(player)
	local def = byId[id]
	if not data or not def or type(amount) ~= "number" then
		return
	end
	ensureToday(data)
	local before = data.Quests.Progress[id] or 0
	local after = math.clamp(before + amount, 0, def.Goal)
	if after ~= before then
		data.Quests.Progress[id] = after
		services.DataService.MarkDirty(player)
		if before < def.Goal and after >= def.Goal then
			services.EconomyService.Notify(player, "Daily task complete: " .. def.Text .. "! Claim it in TASKS.", "quest")
		end
	end
end

-- Unique places visited today (other players' resorts and districts).
function QuestService.Visit(player, placeKey)
	local data = services.DataService.Get(player)
	if not data then
		return
	end
	ensureToday(data)
	if not data.Quests.Visited[placeKey] then
		data.Quests.Visited[placeKey] = true
		QuestService.Increment(player, "visits", 1)
	end
end

local function claim(player, id)
	local data = services.DataService.Get(player)
	local def = type(id) == "string" and byId[id]
	if not data or not def then
		return false, "Unknown task"
	end
	ensureToday(data)
	if data.Quests.Claimed[id] then
		return false, "Already claimed"
	end
	if (data.Quests.Progress[id] or 0) < def.Goal then
		return false, "Not complete yet"
	end
	data.Quests.Claimed[id] = true
	services.EconomyService.Reward(player, def.Cash, def.XP, "Task reward")
	services.DataService.MarkDirty(player)
	return true
end

function QuestService.Init(allServices)
	services = allServices

	services.DataService.PlayerLoaded:Connect(function(_player, data)
		ensureToday(data)
	end)

	services.DataService.AddSnapshotProvider(function(player, snapshot)
		local data = services.DataService.Get(player)
		if data and ensureToday(data) then
			snapshot.Quests = data.Quests
		end
		snapshot.QuestResetIn = 86400 - (os.time() % 86400)
	end)

	Remotes.Get("ClaimTask").OnServerInvoke = claim
end

return QuestService
