-- WorldService: collision groups, interaction prompts and teleport pads for the static city.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local WorldService = {}

local services

local GROUPS = { "Props", "Buildings", "NPC", "Players", "Cars", "GhostCars" }

local PROMPTS = {
	Shop = { Action = "Open Shop", Object = "Shop" },
	CardRush = { Action = "Play Card Rush", Object = "Card Rush" },
	Tasks = { Action = "Daily Tasks", Object = "Tasks Board" },
	Build = { Action = "Build Menu", Object = "Resort Builder" },
	Race = { Action = "Join Street Race", Object = "Race Lobby" },
}

local function setupCollisionGroups()
	for _, name in ipairs(GROUPS) do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	-- NPCs only collide with walkable ground (Default) so they never get stuck on props.
	for _, other in ipairs(GROUPS) do
		PhysicsService:CollisionGroupSetCollidable("NPC", other, false)
	end
	-- Ghost (NPC) race cars are driven by constraints and collide with nothing.
	PhysicsService:CollisionGroupSetCollidable("GhostCars", "Default", false)
	for _, other in ipairs(GROUPS) do
		PhysicsService:CollisionGroupSetCollidable("GhostCars", other, false)
	end
end

local function assignPropGroups()
	local roots = { "City", "Plots", "EventAreas", "RaceTrack", "Teleports" }
	for _, rootName in ipairs(roots) do
		local root = workspace:FindFirstChild(rootName)
		if root then
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:IsA("BasePart") and not descendant:GetAttribute("Walkable") then
					descendant.CollisionGroup = "Props"
				end
			end
		end
	end
end

local function setupPrompts()
	local openUI = Remotes.Get("OpenUI")
	for _, descendant in ipairs(workspace:GetDescendants()) do
		local kind = descendant:IsA("BasePart") and descendant:GetAttribute("Prompt")
		local info = kind and PROMPTS[kind]
		if info then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = info.Action
			prompt.ObjectText = info.Object
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = descendant
			prompt.Triggered:Connect(function(player)
				if kind == "Race" then
					services.RaceService.Join(player)
				else
					openUI:FireClient(player, kind)
				end
			end)
		end
	end
end

local function setupTeleportPads()
	local folder = workspace:FindFirstChild("Teleports")
	if not folder then
		return
	end
	local cooldown = {}
	for _, pad in ipairs(folder:GetChildren()) do
		local target = pad:GetAttribute("Target")
		if pad:IsA("BasePart") and target then
			pad.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player then
					return
				end
				local now = os.clock()
				if cooldown[player] and now - cooldown[player] < 3 then
					return
				end
				cooldown[player] = now
				services.PlayerService.TeleportTo(player, target)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
	end)
end

function WorldService.Init(allServices)
	services = allServices
	setupCollisionGroups()
	assignPropGroups()
end

function WorldService.Start()
	setupPrompts()
	setupTeleportPads()
end

return WorldService
