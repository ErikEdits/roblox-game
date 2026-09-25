-- NEON CITY: single place that declares every remote.
-- The server creates them (Remotes.Setup), clients wait for them (Remotes.Get).
-- Remember: remotes are requests. The server validates everything it receives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	"Notify", -- S->C (text, kind)
	"StateChanged", -- S->C (player state snapshot)
	"EventState", -- S->C (current server event or nil)
	"CityStats", -- S->C (power, tourism, security, popularity)
	"RaceState", -- S->C (personal race HUD info)
	"OpenUI", -- S->C (panel name) e.g. when a ProximityPrompt is used
	"MoneyPopup", -- S->C (world position, text, color)
}

Remotes.Functions = {
	"GetState",
	"PlaceBuilding",
	"MoveBuilding",
	"DeleteBuilding",
	"CardRushStart",
	"CardRushAnswer",
	"ClaimTask",
	"BuyCosmetic",
	"EquipCosmetic",
	"SetSetting",
	"Prestige",
	"JoinRace",
	"Teleport",
}

local FOLDER_NAME = "Remotes"

function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup is server only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(Remotes.Events) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in ipairs(Remotes.Functions) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

function Remotes.Get(name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

return Remotes
