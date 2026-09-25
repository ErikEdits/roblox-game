-- AdminService: testing tools for the game owner. Available in Roblox Studio, or live for the
-- experience creator / user IDs listed in Config.Admins. Every action is validated here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local AdminService = {}

local services

function AdminService.IsAdmin(player)
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Config.Admins, player.UserId) ~= nil
end

local ACTIONS = {}

function ACTIONS.Cash(player)
	services.EconomyService.AddCash(player, 10000, "admin")
	return "+$10,000"
end

function ACTIONS.BigCash(player)
	services.EconomyService.AddCash(player, 1000000, "admin")
	return "+$1,000,000"
end

function ACTIONS.Levels(player)
	local data = services.DataService.Get(player)
	local gained = 0
	for _ = 1, 5 do
		if data.Level < Config.MaxLevel then
			services.EconomyService.AddXP(player, Progression.XPForLevel(data.Level) - data.XP)
			gained += 1
		end
	end
	return "+" .. gained .. " levels"
end

function ACTIONS.MaxLevel(player)
	local data = services.DataService.Get(player)
	data.Level = Config.MaxLevel
	data.XP = 0
	services.EconomyService.RefreshLeaderstats(player)
	services.DataService.MarkDirty(player)
	return "Level " .. Config.MaxLevel
end

for _, id in ipairs({ "Blackout", "Concert", "VIPNight", "StreetRace", "LostAndFound" }) do
	ACTIONS["Event" .. id] = function()
		return services.EventService.ForceStart(id) and ("Started " .. id) or "Unknown event"
	end
end

function ACTIONS.ResetTasks(player)
	local data = services.DataService.Get(player)
	data.Quests.Day = 0
	services.DataService.MarkDirty(player)
	return "Daily tasks reset"
end

function ACTIONS.CompleteTasks(player)
	local data = services.DataService.Get(player)
	for _, def in ipairs(services.QuestService.GetToday()) do
		data.Quests.Progress[def.Id] = def.Goal
	end
	services.DataService.MarkDirty(player)
	return "All tasks completed"
end

function ACTIONS.ResetTutorial(player)
	local data = services.DataService.Get(player)
	data.Tutorial = 1
	services.DataService.MarkDirty(player)
	return "Tutorial restarted"
end

function AdminService.Init(allServices)
	services = allServices

	services.DataService.AddSnapshotProvider(function(player, snapshot)
		snapshot.IsAdmin = AdminService.IsAdmin(player)
	end)

	Remotes.Get("AdminAction").OnServerInvoke = function(player, action)
		if not AdminService.IsAdmin(player) then
			return false, "Not allowed"
		end
		local handler = type(action) == "string" and ACTIONS[action]
		if not handler or not services.DataService.Get(player) then
			return false, "Unknown action"
		end
		local ok, result = pcall(handler, player)
		if not ok then
			return false, tostring(result)
		end
		services.EconomyService.Notify(player, "[Admin] " .. tostring(result), "info")
		return true, result
	end
end

return AdminService
