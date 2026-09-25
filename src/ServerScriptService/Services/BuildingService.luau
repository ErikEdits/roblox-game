-- BuildingService: server-authoritative placement, moving and deleting of resort buildings,
-- save/restore of builds, resort rating and passive resort income.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BuildingModels = require(Shared.BuildingModels)
local Buildings = require(Shared.Buildings)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Placement = require(Shared.Placement)
local PlotUtil = require(Shared.PlotUtil)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local BuildingService = {}

local services
local models = {} -- [player] = { [uid] = model }
local lastRequest = {} -- [player] = os.clock()

local function rateLimited(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.15 then
		return true
	end
	lastRequest[player] = now
	return false
end

local function isNumber(value)
	return type(value) == "number" and value == value and math.abs(value) < 1e6
end

local function findEntry(data, uid)
	for index, entry in ipairs(data.Buildings) do
		if entry.Uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

local function spawnModel(player, plot, entry)
	local cframe = PlotUtil.BuildingCFrame(plot.Model, entry.X, entry.Z, entry.R)
	local model = BuildingModels.Build(entry.Id, cframe)
	model:SetAttribute("BuildingId", entry.Id)
	model:SetAttribute("Uid", entry.Uid)
	model:SetAttribute("OwnerId", player.UserId)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Buildings"
		end
	end
	local folder = plot.Model:FindFirstChild("Buildings")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Buildings"
		folder.Parent = plot.Model
	end
	model.Parent = folder
	models[player] = models[player] or {}
	models[player][entry.Uid] = model
	return model
end

local function passes(player)
	return services.MonetizationService.GetPasses(player)
end

function BuildingService.RecalculateRating(player)
	local data = services.DataService.Get(player)
	if not data then
		return
	end
	local rating = 0
	for _, entry in ipairs(data.Buildings) do
		local def = Buildings.Get(entry.Id)
		rating += def and def.Rating or 0
	end
	local resortLevel = Progression.ResortLevel(rating)
	local previous = player:GetAttribute("ResortLevel")
	player:SetAttribute("ResortRating", rating)
	player:SetAttribute("ResortLevel", resortLevel)
	if previous and resortLevel > previous then
		services.EconomyService.Notify(player, "Your resort grew to: " .. Progression.ResortLevelNames[resortLevel] .. "! More visitors will come.", "levelup")
	end
	services.PlotService.UpdateSign(player)
end

-- Used by NPCService and passive income: all live buildings of a player.
function BuildingService.GetBuildings(player)
	local list = {}
	local data = services.DataService.Get(player)
	local playerModels = models[player]
	if not data or not playerModels then
		return list
	end
	for _, entry in ipairs(data.Buildings) do
		local model = playerModels[entry.Uid]
		if model and model.PrimaryPart then
			table.insert(list, { Def = Buildings.Get(entry.Id), Model = model, Uid = entry.Uid, Owner = player })
		end
	end
	return list
end

function BuildingService.BuildingExists(player, uid)
	return models[player] ~= nil and models[player][uid] ~= nil
end

local function place(player, id, x, z, rot)
	if rateLimited(player) then
		return false, "Slow down"
	end
	if type(id) ~= "string" or not isNumber(x) or not isNumber(z) or not isNumber(rot) then
		return false, "Invalid request"
	end
	local def = Buildings.Get(id)
	local data = services.DataService.Get(player)
	local plot = services.PlotService.GetPlot(player)
	if not def or not data or not plot then
		return false, "Not ready"
	end
	rot = math.floor(rot) % 4
	local allowed, reason = Progression.CanUseBuilding(def, data.Level, data.Prestige, passes(player))
	if not allowed then
		return false, reason
	end
	if #data.Buildings >= Config.MaxBuildingsPerPlot then
		return false, "Your plot is full (" .. Config.MaxBuildingsPerPlot .. " buildings)"
	end
	x, z = Placement.Normalize(def, x, z, rot)
	local valid, why = Placement.IsValid(def, x, z, rot, data.Buildings, nil)
	if not valid then
		return false, why
	end
	if not services.EconomyService.SpendCash(player, def.Cost) then
		return false, "Not enough cash (" .. Format.Money(def.Cost) .. ")"
	end

	local entry = { Id = id, X = x, Z = z, R = rot, Uid = data.NextUid }
	data.NextUid += 1
	table.insert(data.Buildings, entry)
	spawnModel(player, plot, entry)

	local xp = math.min(Config.PlaceXPCap, math.max(5, math.floor(def.Cost / Config.PlaceXPDivisor)))
	services.EconomyService.AddXP(player, xp)
	BuildingService.RecalculateRating(player)
	services.DataService.MarkDirty(player)
	return true, entry.Uid
end

local function move(player, uid, x, z, rot)
	if rateLimited(player) then
		return false, "Slow down"
	end
	if not isNumber(uid) or not isNumber(x) or not isNumber(z) or not isNumber(rot) then
		return false, "Invalid request"
	end
	local data = services.DataService.Get(player)
	local plot = services.PlotService.GetPlot(player)
	if not data or not plot then
		return false, "Not ready"
	end
	local entry = findEntry(data, uid)
	if not entry then
		return false, "Building not found"
	end
	local def = Buildings.Get(entry.Id)
	rot = math.floor(rot) % 4
	x, z = Placement.Normalize(def, x, z, rot)
	local valid, why = Placement.IsValid(def, x, z, rot, data.Buildings, uid)
	if not valid then
		return false, why
	end
	entry.X, entry.Z, entry.R = x, z, rot
	local model = models[player] and models[player][uid]
	if model then
		BuildingModels.MoveTo(model, entry.Id, PlotUtil.BuildingCFrame(plot.Model, x, z, rot))
	end
	services.DataService.MarkDirty(player)
	return true, uid
end

local function delete(player, uid)
	if rateLimited(player) then
		return false, "Slow down"
	end
	if not isNumber(uid) then
		return false, "Invalid request"
	end
	local data = services.DataService.Get(player)
	if not data then
		return false, "Not ready"
	end
	local entry, index = findEntry(data, uid)
	if not entry then
		return false, "Building not found"
	end
	local def = Buildings.Get(entry.Id)
	table.remove(data.Buildings, index)
	local model = models[player] and models[player][uid]
	if model then
		model:Destroy()
		models[player][uid] = nil
	end
	local refund = math.floor(def.Cost * Config.SellRefund)
	if refund > 0 then
		services.EconomyService.AddCash(player, refund, "refund")
	end
	BuildingService.RecalculateRating(player)
	services.DataService.MarkDirty(player)
	return true, refund
end

local function restore(player, data)
	local plot = services.PlotService.GetPlot(player)
	if not plot then
		return
	end
	-- Validate saved layout again (plot rules may have changed between versions).
	local kept = {}
	for _, entry in ipairs(data.Buildings) do
		local def = Buildings.Get(entry.Id)
		if def then
			local x, z = Placement.Normalize(def, entry.X, entry.Z, entry.R)
			entry.X, entry.Z = x, z
			if Placement.IsValid(def, x, z, entry.R, kept, nil) then
				table.insert(kept, entry)
				spawnModel(player, plot, entry)
			end
		end
	end
	data.Buildings = kept
	BuildingService.RecalculateRating(player)
end

local function passiveIncomeLoop()
	while true do
		task.wait(Config.PassiveIncomeInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = services.DataService.Get(player)
			if data and #data.Buildings > 0 then
				local total = 0
				for _, entry in ipairs(data.Buildings) do
					local def = Buildings.Get(entry.Id)
					total += def and def.Passive or 0
				end
				total *= Progression.PrestigeIncomeMultiplier(data.Prestige)
				if total >= 1 then
					services.EconomyService.Reward(player, total, 0, "Resort operations")
				end
			end
		end
	end
end

function BuildingService.Init(allServices)
	services = allServices

	services.DataService.PlayerLoaded:Connect(restore)

	Remotes.Get("PlaceBuilding").OnServerInvoke = place
	Remotes.Get("MoveBuilding").OnServerInvoke = move
	Remotes.Get("DeleteBuilding").OnServerInvoke = delete

	Players.PlayerRemoving:Connect(function(player)
		if models[player] then
			for _, model in pairs(models[player]) do
				model:Destroy()
			end
		end
		models[player] = nil
		lastRequest[player] = nil
	end)
end

function BuildingService.Start()
	passiveIncomeLoop()
end

return BuildingService
