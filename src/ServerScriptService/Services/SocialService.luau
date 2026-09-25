-- SocialService: visit and like other players' resorts (social features are optional extras).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local SocialService = {}

local services

local function resortList(viewer)
	local list = {}
	local viewerData = services.DataService.Get(viewer)
	local liked = viewerData and viewerData.Quests.Liked or {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = services.DataService.Get(player)
		if player ~= viewer and data and services.PlotService.GetPlot(player) then
			table.insert(list, {
				UserId = player.UserId,
				Name = player.DisplayName,
				ResortLevel = player:GetAttribute("ResortLevel") or 1,
				Rating = player:GetAttribute("ResortRating") or 0,
				Likes = data.Stats.Likes or 0,
				Buildings = #data.Buildings,
				LikedToday = liked[tostring(player.UserId)] == true,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Rating > b.Rating
	end)
	return list
end

local function like(player, userId)
	if type(userId) ~= "number" then
		return false, "Invalid"
	end
	local owner = Players:GetPlayerByUserId(userId)
	local data = services.DataService.Get(player)
	local ownerData = owner and services.DataService.Get(owner)
	if not owner or owner == player or not data or not ownerData then
		return false, "Resort not found"
	end
	data.Quests.Liked = data.Quests.Liked or {}
	local key = tostring(userId)
	if data.Quests.Liked[key] then
		return false, "You already liked this resort today"
	end
	data.Quests.Liked[key] = true
	ownerData.Stats.Likes = (ownerData.Stats.Likes or 0) + 1
	services.EconomyService.Reward(owner, Config.Social.LikeCash, Config.Social.LikeXP, player.DisplayName .. " liked your resort!")
	services.EconomyService.Reward(player, 0, Config.Social.LikerXP, nil)
	services.PlotService.UpdateSign(owner)
	services.DataService.MarkDirty(player)
	services.DataService.MarkDirty(owner)
	services.AnalyticsService.Log(player, "ResortLiked")
	return true
end

function SocialService.Init(allServices)
	services = allServices
	Remotes.Get("GetResorts").OnServerInvoke = resortList
	Remotes.Get("LikeResort").OnServerInvoke = like
end

return SocialService
