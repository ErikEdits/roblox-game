-- ShopService: cash cosmetics (car paints), player settings and prestige.
-- Everything here is a request from the client and is fully validated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local ShopService = {}

local services
local cosmeticsById = {}
for _, cosmetic in ipairs(Config.Cosmetics) do
	cosmeticsById[cosmetic.Id] = cosmetic
end

local function buy(player, id)
	local data = services.DataService.Get(player)
	local cosmetic = type(id) == "string" and cosmeticsById[id]
	if not data or not cosmetic then
		return false, "Unknown item"
	end
	if cosmetic.RequiresPass then
		return false, "Included with the " .. Config.Monetization.Passes[cosmetic.RequiresPass].Name
	end
	if data.Cosmetics.Owned[id] then
		return false, "Already owned"
	end
	if not services.EconomyService.SpendCash(player, cosmetic.Price) then
		return false, "Not enough cash (" .. Format.Money(cosmetic.Price) .. ")"
	end
	data.Cosmetics.Owned[id] = true
	data.Cosmetics.Paint = id
	services.DataService.MarkDirty(player)
	services.EconomyService.Notify(player, "Bought " .. cosmetic.Name .. "!", "reward")
	return true
end

local function equip(player, id)
	local data = services.DataService.Get(player)
	local cosmetic = type(id) == "string" and cosmeticsById[id]
	if not data or not cosmetic then
		return false, "Unknown item"
	end
	local usable = data.Cosmetics.Owned[id] or (cosmetic.RequiresPass and services.MonetizationService.HasPass(player, cosmetic.RequiresPass))
	if not usable then
		return false, "You do not own this yet"
	end
	if cosmetic.IsBody then
		data.Cosmetics.Body = data.Cosmetics.Body == "hyper" and "standard" or "hyper"
	else
		data.Cosmetics.Paint = id
	end
	services.DataService.MarkDirty(player)
	return true
end

local function setSetting(player, key, value)
	local data = services.DataService.Get(player)
	if not data or type(key) ~= "string" or Config.DefaultSettings[key] == nil or type(value) ~= "boolean" then
		return false
	end
	data.Settings[key] = value
	services.DataService.MarkDirty(player)
	return true
end

local function prestige(player)
	local data = services.DataService.Get(player)
	if not data then
		return false, "Not ready"
	end
	if data.Level < Config.Prestige.RequiredLevel then
		return false, "Reach level " .. Config.Prestige.RequiredLevel .. " first"
	end
	data.Prestige += 1
	data.Level = 1
	data.XP = 0
	data.Cash = Config.StartingCash
	services.EconomyService.RefreshLeaderstats(player)
	services.PlayerService.RefreshTag(player)
	services.DataService.MarkDirty(player)
	local bonus = math.floor((Progression.PrestigeIncomeMultiplier(data.Prestige) - 1) * 100 + 0.5)
	services.EconomyService.NotifyAll(("%s reached PRESTIGE %d!"):format(player.DisplayName, data.Prestige), "levelup")
	services.EconomyService.Notify(player, ("Prestige %d: your buildings stay, resort income +%d%% forever, new title: %s"):format(
		data.Prestige, bonus, Progression.PrestigeTitle(data.Prestige)), "levelup")
	return true
end

function ShopService.Init(allServices)
	services = allServices
	Remotes.Get("BuyCosmetic").OnServerInvoke = buy
	Remotes.Get("EquipCosmetic").OnServerInvoke = equip
	Remotes.Get("SetSetting").OnServerInvoke = setSetting
	Remotes.Get("Prestige").OnServerInvoke = prestige
end

return ShopService
