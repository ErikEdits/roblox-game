-- ZoneService: which district / resort each player is in (cheap 1 Hz check).
-- Feeds daily "visit" tasks, the HUD location label and event participation.

local Players = game:GetService("Players")

local ZoneService = {}

local services
local zoneParts = {}
local current = {} -- [player] = zone key

function ZoneService.PointInPart(part, position)
	local offset = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

function ZoneService.GetZone(player)
	return current[player]
end

local function resolve(player, position)
	local owner = services.PlotService.GetOwnerAt(position)
	if owner then
		if owner == player then
			return "resort:self", "Your Resort"
		end
		return "resort:" .. owner.UserId, owner.DisplayName .. "'s Resort"
	end
	for _, part in ipairs(zoneParts) do
		if ZoneService.PointInPart(part, position) then
			return "district:" .. part.Name, part.Name
		end
	end
	return nil, "Neon City"
end

function ZoneService.Init(allServices)
	services = allServices
	local folder = workspace:WaitForChild("Zones")
	zoneParts = folder:GetChildren()
	-- Smaller zones first so the plaza wins over a district overlapping it.
	table.sort(zoneParts, function(a, b)
		return a.Size.Magnitude < b.Size.Magnitude
	end)
	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
	end)
end

function ZoneService.Start()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and services.DataService.IsLoaded(player) then
				local key, label = resolve(player, root.Position)
				if key ~= current[player] then
					current[player] = key
					player:SetAttribute("Zone", label)
					if key and key ~= "resort:self" then
						services.QuestService.Visit(player, key)
					end
					services.EventService.OnZoneChanged(player, key)
				end
			end
		end
	end
end

return ZoneService
