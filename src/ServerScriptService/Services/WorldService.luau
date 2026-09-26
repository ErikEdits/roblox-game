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
	Delivery = { Action = "Start Delivery Job", Object = "Delivery Jobs" },
	Reflex = { Action = "Play Neon Reflex", Object = "Neon Reflex" },
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
				elseif kind == "Delivery" then
					local ok, message = services.JobService.StartDelivery(player)
					if not ok and message then
						services.EconomyService.Notify(player, message, "warning")
					end
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

local function setupEffects()
	-- Fountain spray (one small emitter; clients can switch effects off with Low graphics).
	local plaza = workspace:FindFirstChild("City") and workspace.City:FindFirstChild("Plaza")
	local column = plaza and plaza:FindFirstChild("FountainColumn")
	if column then
		local attachment = Instance.new("Attachment")
		attachment.Name = "SprayAttachment"
		attachment.Position = Vector3.new(column.Size.X / 2, 0, 0) -- top of the upright cylinder
		attachment.Parent = column
		local spray = Instance.new("ParticleEmitter")
		spray.Name = "Spray"
		spray.Rate = 40
		spray.Lifetime = NumberRange.new(1.2, 1.6)
		spray.Speed = NumberRange.new(14, 18)
		spray.SpreadAngle = Vector2.new(18, 18)
		spray.Acceleration = Vector3.new(0, -30, 0)
		spray.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 80, 220))
		spray.LightEmission = 0.8
		spray.Size = NumberSequence.new(0.6, 0.2)
		spray.Transparency = NumberSequence.new(0.2, 1)
		spray.EmissionDirection = Enum.NormalId.Right
		spray.Parent = attachment
	end
end

function WorldService.Start()
	setupEffects()
	setupPrompts()
	setupTeleportPads()
end

return WorldService
