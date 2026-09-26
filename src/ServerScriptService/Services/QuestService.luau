-- QuestService: daily tasks that reset at 00:00 UTC. All progress is tracked server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local QuestService = {}

local services
local byId = {}
for _, def in ipairs(Config.DailyTaskPool) do
	byId[def.Id] = def
end

local function today()
	return os.time() // 86400
end

local todayCache = { Day = -1, List = {} }

-- The same tasks for everyone on a given UTC day (deterministic shuffle seeded by the day).
function QuestService.GetToday()
	local day = today()
	if todayCache.Day ~= day then
		local pool = table.clone(Config.DailyTaskPool)
		local rng = Random.new(day)
		for i = #pool, 2, -1 do
			local j = rng:NextInteger(1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		todayCache = { Day = day, List = { table.unpack(pool, 1, math.min(Config.DailyTaskCount, #pool)) } }
	end
	return todayCache.List
end

local function isActive(id)
	for _, def in ipairs(QuestService.GetToday()) do
		if def.Id == id then
			return true
		end
	end
	return false
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
	if not data or not def or type(amount) ~= "number" or not isActive(id) then
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
	if not data or not def or not isActive(id) then
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
		snapshot.DailyTasks = QuestService.GetToday()
	end)

	Remotes.Get("ClaimTask").OnServerInvoke = claim
end

return QuestService
