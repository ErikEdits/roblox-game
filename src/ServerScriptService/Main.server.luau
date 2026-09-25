-- NEON CITY server bootstrap.
-- Every system is a small service module (see ./Services). Init wires dependencies,
-- Start begins loops and connections.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.Setup()

local ORDER = {
	"WorldService",
	"DataService",
	"EconomyService",
	"MonetizationService",
	"PlotService",
	"BuildingService",
	"CityService",
	"QuestService",
	"ShopService",
	"PlayerService",
	"ZoneService",
	"NPCService",
	"MinigameService",
	"RaceService",
	"EventService",
	"LeaderboardService",
}

local servicesFolder = script.Parent:WaitForChild("Services")
local services = {}

for _, name in ipairs(ORDER) do
	services[name] = require(servicesFolder:WaitForChild(name))
end

for _, name in ipairs(ORDER) do
	local service = services[name]
	if service.Init then
		service.Init(services)
	end
end

for _, name in ipairs(ORDER) do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print(("[NEON CITY] server started with %d services"):format(#ORDER))
