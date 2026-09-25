-- EconomyService: the only place that changes cash and XP.
-- Callers are other server services; the client can only *request* actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Buildings)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local EconomyService = {}

local services
local notifyRemote
local popupRemote

local function updateLeaderstats(player, data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	stats.Cash.Value = data.Cash
	stats.Level.Value = data.Level
end

function EconomyService.RefreshLeaderstats(player)
	local data = services.DataService.Get(player)
	if data then
		updateLeaderstats(player, data)
	end
end

function EconomyService.Notify(player, text, kind)
	if not notifyRemote then
		notifyRemote = Remotes.Get("Notify")
	end
	notifyRemote:FireClient(player, text, kind or "info")
end

function EconomyService.NotifyAll(text, kind)
	if not notifyRemote then
		notifyRemote = Remotes.Get("Notify")
	end
	notifyRemote:FireAllClients(text, kind or "info")
end

-- Floating "+$40" text at a world position, shown only to `player`.
function EconomyService.Popup(player, position, text, color)
	if not popupRemote then
		popupRemote = Remotes.Get("MoneyPopup")
	end
	popupRemote:FireClient(player, position, text, color)
end

function EconomyService.GetCash(player)
	local data = services.DataService.Get(player)
	return data and data.Cash or 0
end

-- amount must be a positive number computed by the server.
function EconomyService.AddCash(player, amount, source)
	local data = services.DataService.Get(player)
	if not data or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	amount = math.floor(amount)
	data.Cash += amount
	-- Refunds are not earnings (statistics / daily tasks).
	if source ~= "refund" then
		data.Stats.TotalEarned += amount
		if services.QuestService then
			services.QuestService.Increment(player, "earn", amount)
		end
	end
	updateLeaderstats(player, data)
	services.DataService.MarkDirty(player)
	return amount
end

function EconomyService.CanAfford(player, amount)
	local data = services.DataService.Get(player)
	return data ~= nil and data.Cash >= amount
end

function EconomyService.SpendCash(player, amount)
	local data = services.DataService.Get(player)
	if not data or type(amount) ~= "number" or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= math.floor(amount)
	updateLeaderstats(player, data)
	services.DataService.MarkDirty(player)
	return true
end

function EconomyService.AddXP(player, amount)
	local data = services.DataService.Get(player)
	if not data or type(amount) ~= "number" or amount <= 0 then
		return
	end
	local oldLevel = data.Level
	data.Level, data.XP = Progression.ApplyXP(data.Level, data.XP, math.floor(amount))
	if data.Level > oldLevel then
		local unlocked = {}
		for _, def in ipairs(Buildings.List) do
			if def.Level > oldLevel and def.Level <= data.Level and not def.Pass and not def.Prestige then
				table.insert(unlocked, def.Name)
			end
		end
		local message = ("LEVEL UP! You are now level %d."):format(data.Level)
		if #unlocked > 0 then
			message ..= " Unlocked: " .. table.concat(unlocked, ", ")
		end
		EconomyService.Notify(player, message, "levelup")
		if services.PlayerService then
			services.PlayerService.RefreshTag(player)
		end
	end
	updateLeaderstats(player, data)
	services.DataService.MarkDirty(player)
end

-- Convenience: cash + XP + one notification.
function EconomyService.Reward(player, cash, xp, reason)
	local gained = 0
	if cash and cash > 0 then
		gained = EconomyService.AddCash(player, cash, reason)
	end
	if xp and xp > 0 then
		EconomyService.AddXP(player, xp)
	end
	if reason then
		local parts = {}
		if gained > 0 then
			table.insert(parts, "+" .. Format.Money(gained))
		end
		if xp and xp > 0 then
			table.insert(parts, "+" .. math.floor(xp) .. " XP")
		end
		EconomyService.Notify(player, reason .. "  " .. table.concat(parts, "  "), "reward")
	end
end

function EconomyService.Init(allServices)
	services = allServices

	services.DataService.PlayerLoaded:Connect(function(player, data)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = data.Cash
		cash.Parent = stats
		local level = Instance.new("IntValue")
		level.Name = "Level"
		level.Value = data.Level
		level.Parent = stats
		stats.Parent = player
	end)
end

return EconomyService
