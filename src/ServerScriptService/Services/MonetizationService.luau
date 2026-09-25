-- MonetizationService: Robux game passes with clearly defined content.
-- No gambling, no random rewards, no competitive advantages.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)

local MonetizationService = {}

local services
local owned = {} -- [player] = { VIP = bool, HyperCar = bool }

local function passKeyForId(passId)
	for key, pass in pairs(Config.Monetization.Passes) do
		if pass.Id ~= 0 and pass.Id == passId then
			return key
		end
	end
	return nil
end

function MonetizationService.HasPass(player, key)
	local passes = owned[player]
	return passes ~= nil and passes[key] == true
end

function MonetizationService.GetPasses(player)
	return owned[player] or {}
end

local function grant(player, key)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	if services.PlayerService then
		services.PlayerService.RefreshTag(player)
	end
	services.DataService.MarkDirty(player)
end

local function checkPasses(player)
	local passes = {}
	owned[player] = passes
	local studioGrant = RunService:IsStudio() and Config.Monetization.GrantAllInStudio
	for key, pass in pairs(Config.Monetization.Passes) do
		if studioGrant then
			passes[key] = true
		elseif pass.Id ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			passes[key] = ok and result == true
		end
	end
	if services.PlayerService then
		services.PlayerService.RefreshTag(player)
	end
	services.DataService.MarkDirty(player)
end

function MonetizationService.Init(allServices)
	services = allServices

	services.DataService.PlayerLoaded:Connect(function(player)
		owned[player] = {}
		task.spawn(checkPasses, player)
	end)

	services.DataService.AddSnapshotProvider(function(player, snapshot)
		snapshot.Passes = table.clone(owned[player] or {})
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyForId(passId)
		if key then
			grant(player, key)
			services.EconomyService.Notify(player, "Thanks for your purchase! " .. Config.Monetization.Passes[key].Name .. " unlocked.", "reward")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return MonetizationService
