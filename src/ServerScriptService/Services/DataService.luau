-- DataService: loading, validating and saving player data (DataStore).
-- Works without DataStore access (e.g. an unpublished place in Studio): data then lives in memory only.
-- The client never writes data directly; every change goes through server services.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Buildings = require(Shared.Buildings)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local DataService = {}
DataService.PlayerLoaded = Signal.new() -- (player, data)
DataService.PlayerLeaving = Signal.new() -- (player, data) fired before the final save

local services
local store = nil
local storeEnabled = false
local profiles = {} -- [player] = { Data = table, NoSave = bool, Dirty = bool }
local snapshotProviders = {}

local DATA_VERSION = 1

local function defaultData()
	local owned = {}
	for _, cosmetic in ipairs(Config.Cosmetics) do
		if cosmetic.Price == 0 and not cosmetic.RequiresPass then
			owned[cosmetic.Id] = true
		end
	end
	return {
		Version = DATA_VERSION,
		Cash = Config.StartingCash,
		XP = 0,
		Level = 1,
		Prestige = 0,
		Buildings = {},
		NextUid = 1,
		Cosmetics = { Owned = owned, Paint = "paint_cyan", Body = "standard" },
		Vehicles = { "neon_racer" },
		Unlocked = {},
		Quests = { Day = 0, Progress = {}, Claimed = {}, Visited = {} },
		Settings = table.clone(Config.DefaultSettings),
		Stats = {
			TotalEarned = 0,
			RacesCompleted = 0,
			RacesWon = 0,
			BestRaceTime = 0,
			MinigamesPlayed = 0,
			CardRushBest = 0,
			EventsJoined = 0,
			NPCVisits = 0,
			Deliveries = 0,
			Likes = 0,
			ReflexBest = 0,
			BestTrialTime = 0,
			PlayTime = 0,
		},
	}
end

-- Fills in missing keys from the template (deep) without touching existing values.
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = type(value) == "table" and table.clone(value) or value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(data[key], value)
		end
	end
end

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Defensive validation: never trust stored data blindly.
local function sanitize(data)
	local default = defaultData()
	if type(data) ~= "table" then
		return default
	end
	reconcile(data, default)

	if not isFiniteNumber(data.Cash) or data.Cash < 0 then
		data.Cash = 0
	end
	data.Cash = math.floor(data.Cash)
	if not isFiniteNumber(data.Level) then
		data.Level = 1
	end
	data.Level = math.clamp(math.floor(data.Level), 1, Config.MaxLevel)
	if not isFiniteNumber(data.XP) or data.XP < 0 then
		data.XP = 0
	end
	data.XP = math.min(math.floor(data.XP), Progression.XPForLevel(data.Level))
	if not isFiniteNumber(data.Prestige) or data.Prestige < 0 then
		data.Prestige = 0
	end
	data.Prestige = math.floor(data.Prestige)

	-- Buildings: only known ids, valid numbers, unique uids.
	local clean, seen, maxUid = {}, {}, 0
	if type(data.Buildings) == "table" then
		for _, entry in ipairs(data.Buildings) do
			if type(entry) == "table" and Buildings.Get(entry.Id) and isFiniteNumber(entry.X) and isFiniteNumber(entry.Z)
				and isFiniteNumber(entry.R) and isFiniteNumber(entry.Uid) and not seen[entry.Uid]
				and #clean < Config.MaxBuildingsPerPlot then
				seen[entry.Uid] = true
				maxUid = math.max(maxUid, entry.Uid)
				local level = isFiniteNumber(entry.L) and math.clamp(math.floor(entry.L), 1, Config.Upgrades.MaxLevel) or 1
				local color = isFiniteNumber(entry.C) and entry.C >= 1 and entry.C <= #Config.AccentColors and math.floor(entry.C) or nil
				table.insert(clean, { Id = entry.Id, X = entry.X, Z = entry.Z, R = math.floor(entry.R) % 4, Uid = entry.Uid, L = level, C = color })
			end
		end
	end
	data.Buildings = clean
	if not isFiniteNumber(data.NextUid) or data.NextUid <= maxUid then
		data.NextUid = maxUid + 1
	end

	if data.Tutorial ~= nil and not isFiniteNumber(data.Tutorial) then
		data.Tutorial = nil
	end
	for key, value in pairs(Config.DefaultSettings) do
		if type(data.Settings[key]) ~= type(value) then
			data.Settings[key] = value
		end
	end
	for key, value in pairs(data.Stats) do
		if not isFiniteNumber(value) then
			data.Stats[key] = 0
		end
	end
	data.Version = DATA_VERSION
	return data
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

-- Session locking: a save carries { Session = { JobId, Time } } while a server uses it.
-- Another server waits for the lock (e.g. during a fast server hop) instead of loading stale data.
local SESSION_TIMEOUT = 180 -- a lock older than this is considered abandoned (server crashed)
local LOCK_RETRIES = 6
local LOCK_RETRY_DELAY = 3

local function jobId()
	return game.JobId ~= "" and game.JobId or "studio"
end

local function loadData(player)
	if not storeEnabled then
		return defaultData(), false
	end
	for attempt = 1, LOCK_RETRIES do
		local lockedByOther = false
		local ok, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(old)
				if type(old) == "table" and type(old.Session) == "table" and old.Session.JobId ~= jobId()
					and type(old.Session.Time) == "number" and os.time() - old.Session.Time < SESSION_TIMEOUT
					and attempt < LOCK_RETRIES then
					lockedByOther = true
					return nil -- keep the other server's lock, try again later
				end
				local data = type(old) == "table" and old or {}
				data.Session = { JobId = jobId(), Time = os.time() }
				return data
			end)
		end)
		if ok and not lockedByOther then
			local data = sanitize(result)
			data.Session = nil
			return data, false
		end
		if not ok then
			warn(("[DataService] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
		end
		task.wait(LOCK_RETRY_DELAY)
	end
	-- Loading failed: play with defaults but never overwrite the real save.
	return defaultData(), true
end

-- release = true when the player leaves (frees the session lock).
local function saveProfile(player, profile, release)
	if not storeEnabled or profile.NoSave then
		return true
	end
	local payload = table.clone(profile.Data)
	payload.Session = not release and { JobId = jobId(), Time = os.time() } or nil
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old)
				-- Never overwrite a save that another server has taken over meanwhile.
				if type(old) == "table" and type(old.Session) == "table" and old.Session.JobId ~= jobId()
					and type(old.Session.Time) == "number" and os.time() - old.Session.Time < SESSION_TIMEOUT then
					return nil
				end
				return payload
			end)
		end)
		if ok then
			return true
		end
		warn(("[DataService] save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
	return false
end

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.IsLoaded(player)
	return profiles[player] ~= nil
end

function DataService.IsPersistent()
	return storeEnabled
end

-- Services register extra snapshot fields (plot, passes, ...).
function DataService.AddSnapshotProvider(provider)
	table.insert(snapshotProviders, provider)
end

function DataService.Snapshot(player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local snapshot = {
		Cash = data.Cash,
		XP = data.XP,
		XPNeeded = Progression.XPForLevel(data.Level),
		Level = data.Level,
		Prestige = data.Prestige,
		Buildings = data.Buildings,
		Cosmetics = data.Cosmetics,
		Quests = data.Quests,
		Settings = data.Settings,
		Stats = data.Stats,
		Saving = storeEnabled,
	}
	for _, provider in ipairs(snapshotProviders) do
		provider(player, snapshot)
	end
	return snapshot
end

-- Marks the player's state as changed; the client receives one coalesced update.
function DataService.MarkDirty(player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

local function onPlayerAdded(player)
	local data, noSave = loadData(player)
	if not player.Parent then
		return
	end
	profiles[player] = { Data = data, NoSave = noSave, Dirty = true, JoinedAt = os.clock() }
	DataService.PlayerLoaded:Fire(player, data)
	player:SetAttribute("DataLoaded", true)

	if not storeEnabled then
		services.EconomyService.Notify(player, "Studio mode: progress is not saved (publish + enable API access to save).", "warning")
	elseif noSave then
		services.EconomyService.Notify(player, "Could not load your save. Progress this session will not be saved.", "error")
	end
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Data.Stats.PlayTime += math.floor(os.clock() - profile.JoinedAt)
	DataService.PlayerLeaving:Fire(player, profile.Data)
	saveProfile(player, profile, true)
	profiles[player] = nil
end

function DataService.Init(allServices)
	services = allServices

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		local probeOk, probeErr = pcall(function()
			return store:GetAsync("__probe")
		end)
		storeEnabled = probeOk
		if not probeOk then
			warn("[DataService] DataStore unavailable, running in memory only: " .. tostring(probeErr))
		end
	else
		warn("[DataService] DataStore unavailable, running in memory only: " .. tostring(result))
	end

	Remotes.Get("GetState").OnServerInvoke = function(player)
		return DataService.Snapshot(player)
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		if RunService:IsStudio() and not storeEnabled then
			return
		end
		local pending = 0
		for player, profile in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)

	-- Coalesced state pushes to clients.
	local stateChanged = Remotes.Get("StateChanged")
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, profile in pairs(profiles) do
				if profile.Dirty and player.Parent then
					profile.Dirty = false
					stateChanged:FireClient(player, DataService.Snapshot(player))
				end
			end
		end
	end)

	-- Autosave.
	while true do
		task.wait(Config.AutosaveInterval)
		for player, profile in pairs(profiles) do
			task.spawn(saveProfile, player, profile)
		end
	end
end

return DataService
