-- CityService: lightweight global city values that drive NPC activity and flavour.
--   Power      - drops during a City Blackout, restored by repairing generators
--   Tourism    - grows with the total resort rating on the server
--   Security   - slowly drifts; big crowds lower it a little
--   Popularity - players online + active events

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CityService = {}

local services
local stats = { Power = 100, Tourism = 50, Security = 90, Popularity = 50 }
local powerOverride = nil
local remote

function CityService.Get()
	return stats
end

function CityService.SetPowerOverride(value)
	powerOverride = value
	CityService.Update()
end

function CityService.Update()
	local totalRating = 0
	for _, player in ipairs(Players:GetPlayers()) do
		totalRating += player:GetAttribute("ResortRating") or 0
	end
	local event = services.EventService and services.EventService.GetCurrent()

	stats.Power = powerOverride or 100
	stats.Tourism = math.clamp(math.floor(35 + totalRating / 6 + (event and 10 or 0)), 0, 100)
	local drift = math.random(-2, 2)
	local crowdPenalty = (event and event.Id == "Concert") and 6 or 0
	stats.Security = math.clamp(stats.Security + drift, 78, 98) - crowdPenalty
	stats.Security = math.clamp(stats.Security, 0, 100)
	stats.Popularity = math.clamp(math.floor(40 + #Players:GetPlayers() * 4 + (event and 15 or 0) + math.min(20, totalRating / 20)), 0, 100)

	remote:FireAllClients(stats)
end

function CityService.Init(allServices)
	services = allServices
	remote = Remotes.Get("CityStats")
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				remote:FireClient(player, stats)
			end
		end)
	end)
end

function CityService.Start()
	while true do
		CityService.Update()
		task.wait(10)
	end
end

return CityService
