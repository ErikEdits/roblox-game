-- PlayerService: characters (collision group, overhead tag) and validated teleports.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local PlayerService = {}

local services
local lastTeleport = {}

local DESTINATIONS = {
	Plaza = CFrame.new(0, 4, 40),
	Racing = CFrame.lookAt(Vector3.new(40, 4, 172), Vector3.new(40, 4, 190)),
	Entertainment = CFrame.lookAt(Vector3.new(200, 4, -28), Vector3.new(200, 4, -60)),
	Shopping = CFrame.lookAt(Vector3.new(-180, 4, -28), Vector3.new(-180, 4, -60)),
	VIPLounge = CFrame.lookAt(Vector3.new(-300, 4, -40), Vector3.new(-300, 4, -60)),
	Beach = CFrame.lookAt(Vector3.new(500, 4, 270), Vector3.new(500, 4, 400)),
}

local function buildTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local data = services.DataService.Get(player)
	local tag = head:FindFirstChild("NeonTag")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "NeonTag"
		tag.Size = UDim2.fromOffset(220, 56)
		tag.StudsOffset = Vector3.new(0, 2.8, 0)
		tag.MaxDistance = 90
		tag.AlwaysOnTop = false
		tag.LightInfluence = 0

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLine"
		nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.Parent = tag

		local infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "InfoLine"
		infoLabel.Position = UDim2.fromScale(0, 0.55)
		infoLabel.Size = UDim2.new(1, 0, 0.45, 0)
		infoLabel.BackgroundTransparency = 1
		infoLabel.Font = Enum.Font.GothamBold
		infoLabel.TextScaled = true
		infoLabel.TextColor3 = Color3.fromRGB(0, 235, 255)
		infoLabel.TextStrokeTransparency = 0.5
		infoLabel.Parent = tag

		tag.Parent = head
	end

	local prestige = data and data.Prestige or 0
	local level = data and data.Level or 1
	local isVIP = services.MonetizationService.HasPass(player, "VIP")
	local stars = prestige > 0 and (" " .. string.rep("⭐", math.min(prestige, 5))) or ""
	tag.NameLine.Text = player.DisplayName .. stars
	tag.NameLine.TextColor3 = isVIP and Color3.fromRGB(255, 205, 70) or Color3.new(1, 1, 1)

	local info = { "Lv " .. level }
	local title = Progression.PrestigeTitle(prestige)
	if title then
		table.insert(info, title)
	end
	if isVIP then
		table.insert(info, "VIP")
	end
	tag.InfoLine.Text = table.concat(info, "  |  ")
end

function PlayerService.RefreshTag(player)
	task.defer(buildTag, player)
end

local function onCharacterAdded(player, character)
	local function setGroup(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		setGroup(descendant)
	end
	character.DescendantAdded:Connect(setGroup)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	character:WaitForChild("Head", 10)
	buildTag(player)
end

function PlayerService.TeleportTo(player, target)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, "No character"
	end
	if services.RaceService.IsRacing(player) then
		return false, "You are in a race"
	end
	local destination
	if target == "Resort" then
		destination = services.PlotService.SpawnCFrame(player)
	elseif string.sub(target, 1, 7) == "Resort:" then
		local owner = Players:GetPlayerByUserId(tonumber(string.sub(target, 8)) or 0)
		destination = owner and services.PlotService.SpawnCFrame(owner)
	else
		destination = DESTINATIONS[target]
	end
	if not destination then
		return false, "Unknown destination"
	end
	if humanoid.Sit then
		humanoid.Sit = false
	end
	services.VehicleService.Despawn(player)
	character:PivotTo(destination)
	return true
end

function PlayerService.Init(allServices)
	services = allServices

	Remotes.Get("Teleport").OnServerInvoke = function(player, target)
		if type(target) ~= "string" then
			return false, "Invalid"
		end
		local now = os.clock()
		if lastTeleport[player] and now - lastTeleport[player] < 1.5 then
			return false, "Wait a moment"
		end
		lastTeleport[player] = now
		return PlayerService.TeleportTo(player, target)
	end

	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return PlayerService
