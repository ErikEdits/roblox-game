-- NPCService: visitors that make the city feel alive and drive the resort economy.
--
-- Loop per NPC:  Spawn -> choose destination -> travel -> activity -> spend money
--                -> choose another destination (1-3 times) -> leave / despawn
--
-- Performance rules: capped NPC count, simple state machine per NPC, no pathfinding
-- (avenue waypoints + NPCs only collide with walkable ground), no per-frame work.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Buildings)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local PlotUtil = require(Shared.PlotUtil)
local Progression = require(Shared.Progression)

local NPCService = {}

local services
local npcFolder
local hiddenFolder
local template
local usesR15Animations = false
local activeCount = 0
local visitors = {} -- [building model] = current visitor count
local staticAttractions = {}
local dynamicAttractions = {} -- [name] = attraction
local spawnPoints = {}
local vipResorts = {} -- [player] = true during VIP Night
local vipSpendMultiplier = 1
local typeWeightBoost = {} -- [type] = multiplier (events)

local PLAZA_HALF = 80
local EDGES = {
	N = Vector3.new(0, 0, -72),
	S = Vector3.new(0, 0, 72),
	E = Vector3.new(72, 0, 0),
	W = Vector3.new(-72, 0, 0),
}
local FOUNTAIN_CLEARANCE = 20

local ANIM_WALK = "rbxassetid://507777826"
local ANIM_IDLE = "rbxassetid://507766666"

local SKIN_TONES = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(241, 194, 125),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(92, 56, 37),
}
local PANTS = {
	Color3.fromRGB(35, 35, 45),
	Color3.fromRGB(40, 50, 90),
	Color3.fromRGB(70, 60, 50),
	Color3.fromRGB(230, 230, 235),
}

----------------------------------------------------------------------
-- Model templates
----------------------------------------------------------------------
local function makeBlockyRig()
	local model = Instance.new("Model")
	local function block(name, size, offset, collide)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(offset)
		part.CanCollide = collide
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	local root = block("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), true)
	root.Transparency = 1
	local torso = block("UpperTorso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), false)
	local head = block("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), false)
	local legL = block("LeftUpperLeg", Vector3.new(0.9, 2, 1), Vector3.new(-0.5, 1, 0), false)
	local legR = block("RightUpperLeg", Vector3.new(0.9, 2, 1), Vector3.new(0.5, 1, 0), false)
	for _, part in ipairs({ torso, head, legL, legR }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildTemplate()
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		usesR15Animations = true
		local bodyColors = result:FindFirstChildOfClass("BodyColors")
		if bodyColors then
			bodyColors:Destroy()
		end
		local animate = result:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		return result
	end
	warn("[NPCService] Using blocky fallback rig: " .. tostring(result))
	return makeBlockyRig()
end

local function recolor(model, shirt)
	local skin = SKIN_TONES[math.random(#SKIN_TONES)]
	local pants = PANTS[math.random(#PANTS)]
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local name = part.Name
			if name == "Head" or name:find("Hand") then
				part.Color = skin
			elseif name:find("Leg") or name:find("Foot") then
				part.Color = pants
			else
				part.Color = shirt
			end
		end
	end
end

local function addLabel(model, typeName, info)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NPCLabel"
	gui.Size = UDim2.fromOffset(110, 22)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = Config.NPC.LabelDistance
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = info.Icon or typeName
	label.TextColor3 = info.Color
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = head
end

----------------------------------------------------------------------
-- Routing (avenue waypoints)
----------------------------------------------------------------------
local function avenueOf(position)
	if math.abs(position.X) <= PLAZA_HALF and math.abs(position.Z) <= PLAZA_HALF then
		return "P"
	end
	if math.abs(position.X) < math.abs(position.Z) then
		return position.Z < 0 and "N" or "S"
	end
	return position.X > 0 and "E" or "W"
end

local function roadPoint(position, lane)
	local avenue = avenueOf(position)
	if avenue == "N" or avenue == "S" then
		return Vector3.new(lane, 0, position.Z)
	elseif avenue == "E" or avenue == "W" then
		return Vector3.new(position.X, 0, lane)
	end
	return position
end

-- Inserts a side step when a straight segment would cross the plaza fountain.
local function avoidFountain(points)
	local result = {}
	for _, point in ipairs(points) do
		local previous = result[#result]
		if previous then
			local a = Vector2.new(previous.X, previous.Z)
			local b = Vector2.new(point.X, point.Z)
			local ab = b - a
			if ab.Magnitude > 1 then
				local t = math.clamp(-a:Dot(ab) / ab:Dot(ab), 0, 1)
				local closest = a + ab * t
				if closest.Magnitude < FOUNTAIN_CLEARANCE and t > 0 and t < 1 then
					local side = Vector2.new(-ab.Y, ab.X).Unit
					if closest:Dot(side) < 0 then
						side = -side
					end
					local detour = side * (FOUNTAIN_CLEARANCE + 12)
					table.insert(result, Vector3.new(detour.X, 0, detour.Y))
				end
			end
		end
		table.insert(result, point)
	end
	return result
end

local function route(from, to, lane, approach)
	local a = avenueOf(from)
	local target = approach or to
	local b = avenueOf(target)
	local points = { roadPoint(from, lane) }
	if a ~= b then
		if a ~= "P" then
			table.insert(points, EDGES[a])
		end
		if b ~= "P" then
			table.insert(points, EDGES[b])
		end
	end
	table.insert(points, roadPoint(target, lane))
	if approach then
		table.insert(points, approach)
	end
	table.insert(points, to)
	return avoidFountain(points)
end

----------------------------------------------------------------------
-- Movement
----------------------------------------------------------------------
local function alive(record)
	return record.Model.Parent ~= nil and record.Humanoid.Health > 0
end

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function walkTo(record, target, arriveRadius)
	arriveRadius = arriveRadius or 3
	local humanoid = record.Humanoid
	local deadline = os.clock() + Config.NPC.MoveTimeout
	local lastIssue = 0
	while alive(record) do
		if flatDistance(record.Root.Position, target) <= arriveRadius then
			return true
		end
		local now = os.clock()
		if now > deadline then
			-- Stuck: catch up instantly instead of wandering forever.
			record.Model:PivotTo(CFrame.new(target + Vector3.new(0, 4, 0)))
			return true
		end
		if now - lastIssue > 3 then
			humanoid:MoveTo(target)
			lastIssue = now
		end
		task.wait(0.3)
	end
	return false
end

local function walkRoute(record, points, finalRadius)
	for index, point in ipairs(points) do
		local radius = index == #points and finalRadius or 4
		if not walkTo(record, point, radius) then
			return false
		end
	end
	return true
end

local function setupAnimations(record)
	if not usesR15Animations then
		return
	end
	local humanoid = record.Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local walk = Instance.new("Animation")
	walk.AnimationId = ANIM_WALK
	local idle = Instance.new("Animation")
	idle.AnimationId = ANIM_IDLE
	local ok, walkTrack, idleTrack = pcall(function()
		return animator:LoadAnimation(walk), animator:LoadAnimation(idle)
	end)
	if not ok then
		return
	end
	idleTrack.Looped = true
	walkTrack.Looped = true
	idleTrack:Play()
	local walking = false
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 and not walking then
			walking = true
			walkTrack:Play(0.2)
			walkTrack:AdjustSpeed(humanoid.WalkSpeed / 14)
		elseif speed <= 0.5 and walking then
			walking = false
			walkTrack:Stop(0.2)
		end
	end)
end

----------------------------------------------------------------------
-- Destinations
----------------------------------------------------------------------
local function weightedPick(candidates, total)
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for _, candidate in ipairs(candidates) do
		roll -= candidate.Weight
		if roll <= 0 then
			return candidate
		end
	end
	return candidates[#candidates]
end

local function chooseDestination(record)
	local candidates, total = {}, 0
	local function add(destination, weight)
		if weight > 0 then
			destination.Weight = weight
			total += weight
			table.insert(candidates, destination)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local plot = services.PlotService.GetPlot(player)
		if plot then
			local resortLevel = player:GetAttribute("ResortLevel") or 1
			local vipBoost = vipResorts[player] and Config.Events.VIPNight.SpawnWeight or 1
			for _, building in ipairs(services.BuildingService.GetBuildings(player)) do
				local appeal = building.Def.Appeal[record.Type] or 0
				if appeal > 0 and not record.Visited[building.Model] then
					local crowd = 1 + (visitors[building.Model] or 0)
					add({
						Kind = "Building",
						Building = building,
						Position = building.Model.PrimaryPart.Position,
						Approach = PlotUtil.Entrance(plot.Model),
						Radius = math.max(building.Def.Size[1], building.Def.Size[2]) / 2 - 1,
					}, appeal * Buildings.AppealMultiplier(building.Level) * (1 + 0.25 * (resortLevel - 1)) * vipBoost / crowd)
				end
			end
		end
	end

	local function addAttraction(attraction)
		if attraction.Types[record.Type] and not record.Visited[attraction] then
			add({ Kind = "Attraction", Attraction = attraction, Position = attraction.Position, Radius = 6 }, attraction.Weight)
		end
	end
	for _, attraction in ipairs(staticAttractions) do
		addAttraction(attraction)
	end
	for _, attraction in pairs(dynamicAttractions) do
		addAttraction(attraction)
	end

	return weightedPick(candidates, total)
end

local function performBuildingVisit(record, destination)
	local building = destination.Building
	local model = building.Model
	visitors[model] = (visitors[model] or 0) + 1

	-- "Enter" the building: hide the NPC while it is inside.
	local info = Config.NPC.Types[record.Type]
	record.Model.Parent = hiddenFolder
	task.wait(math.random(Config.NPC.ActivityTimeMin * 10, Config.NPC.ActivityTimeMax * 10) / 10)
	local remaining = (visitors[model] or 1) - 1
	visitors[model] = remaining > 0 and remaining or nil -- nil: no leak for removed buildings

	local owner = building.Owner
	local stillThere = model.Parent ~= nil and model.PrimaryPart ~= nil
	if owner.Parent and stillThere and services.BuildingService.BuildingExists(owner, building.Uid) then
		local data = services.DataService.Get(owner)
		if data then
			local amount = building.Def.Spend
				* Buildings.IncomeMultiplier(building.Level)
				* info.SpendMultiplier
				* Progression.PrestigeIncomeMultiplier(data.Prestige)
				* (vipResorts[owner] and vipSpendMultiplier or 1)
				* (math.random(85, 115) / 100)
			if amount >= 1 then
				local gained = services.EconomyService.AddCash(owner, amount, "npc")
				services.BuildingService.RecordVisit(owner, gained)
				data.Stats.NPCVisits += 1
				services.TutorialService.Event(owner, "FirstVisitor")
				services.QuestService.Increment(owner, "npcvisits", 1)
				local top = model.PrimaryPart.Position + Vector3.new(0, model.PrimaryPart.Size.Y / 2 + 2, 0)
				services.EconomyService.Popup(owner, top, "+" .. Format.Money(gained), info.Color)
			end
		end
	end

	-- Leave through the front door (or where it stood, if the building was removed meanwhile).
	local door = record.Root.Position
	if model.Parent and model.PrimaryPart then
		door = (model.PrimaryPart.CFrame * CFrame.new(0, 0, -model.PrimaryPart.Size.Z / 2 - 3)).Position
	end
	record.Model:PivotTo(CFrame.new(Vector3.new(door.X, record.Root.Position.Y, door.Z)))
	record.Model.Parent = npcFolder
	pcall(function()
		record.Root:SetNetworkOwner(nil)
	end)
end

local function runVisits(record)
	local visits = math.random(Config.NPC.VisitsMin, Config.NPC.VisitsMax)
	local startedAt = os.clock()
	for _ = 1, visits do
		if not alive(record) or os.clock() - startedAt > 300 then
			break
		end
		local destination = chooseDestination(record)
		if not destination then
			break
		end
		local target = destination.Position
		local points = route(record.Root.Position, Vector3.new(target.X, 0, target.Z), record.Lane, destination.Approach)
		if not walkRoute(record, points, destination.Radius) then
			break
		end
		if destination.Kind == "Building" then
			record.Visited[destination.Building.Model] = true
			if destination.Building.Model.Parent then
				performBuildingVisit(record, destination)
			end
		else
			record.Visited[destination.Attraction] = true
			task.wait(math.random(Config.NPC.ActivityTimeMin, Config.NPC.ActivityTimeMax + (destination.Attraction.StayBonus or 0)))
		end
	end

	-- Leave the city.
	if alive(record) and #spawnPoints > 0 then
		local exit = spawnPoints[math.random(#spawnPoints)]
		walkRoute(record, route(record.Root.Position, exit, record.Lane, nil), 6)
	end
end

local function runNPC(record)
	local ok, err = pcall(runVisits, record)
	if not ok then
		warn("[NPCService] NPC error: " .. tostring(err))
	end
	record.Model:Destroy()
	activeCount -= 1
end

local function pickType()
	local total, entries = 0, {}
	for name, info in pairs(Config.NPC.Types) do
		local weight = info.Weight * (typeWeightBoost[name] or 1)
		total += weight
		table.insert(entries, { Name = name, Weight = weight })
	end
	local picked = weightedPick(entries, total)
	return picked and picked.Name or "Tourist"
end

local function createNPC(typeName)
	local info = Config.NPC.Types[typeName]
	local model = template:Clone()
	model.Name = typeName
	recolor(model, info.Color)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return nil
	end
	humanoid.WalkSpeed = Config.NPC.WalkSpeed * math.random(85, 115) / 100
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	for _, state in ipairs({
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Flying,
	}) do
		humanoid:SetStateEnabled(state, false)
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "NPC"
			descendant.CastShadow = false
		end
	end
	return { Model = model, Humanoid = humanoid, Root = root, Type = typeName, Visited = {} }
end

local function place(record, position)
	record.Model:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	record.Model.Parent = npcFolder
	pcall(function()
		record.Root:SetNetworkOwner(nil)
	end)
	setupAnimations(record)
end

-- Family members follow their leader, enter buildings with them and leave with them.
local function runFollower(follower, leader, offset)
	local hidden = false
	while follower.Model.Parent and leader.Model.Parent do
		if leader.Model.Parent == hiddenFolder then
			if not hidden then
				hidden = true
				follower.Model.Parent = hiddenFolder
			end
		else
			local target = leader.Root.Position + leader.Root.CFrame:VectorToWorldSpace(offset)
			if hidden then
				hidden = false
				follower.Model:PivotTo(CFrame.new(target))
				follower.Model.Parent = npcFolder
				pcall(function()
					follower.Root:SetNetworkOwner(nil)
				end)
			elseif flatDistance(follower.Root.Position, target) > 30 then
				follower.Model:PivotTo(CFrame.new(target)) -- fell too far behind
			else
				follower.Humanoid.WalkSpeed = leader.Humanoid.WalkSpeed * 1.15
				follower.Humanoid:MoveTo(target)
			end
		end
		task.wait(0.4)
	end
	follower.Model:Destroy()
	activeCount -= 1
end

local function spawnNPC()
	local typeName = pickType()
	local info = Config.NPC.Types[typeName]
	local record = createNPC(typeName)
	if not record then
		return
	end
	addLabel(record.Model, typeName, info)

	local lane = math.random(-14, 14)
	record.Lane = lane
	local position
	if math.random() < 0.35 then
		-- Arrive along the resort avenue so resorts see traffic quickly.
		position = Vector3.new(lane, 0, math.random(-800, -120))
	else
		position = spawnPoints[math.random(#spawnPoints)] + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	end
	place(record, position)
	activeCount += 1
	task.spawn(runNPC, record)

	-- Families bring one or two kids along.
	if typeName == "Family" and math.random() < Config.NPC.FamilyGroupChance then
		for index = 1, math.random(1, 2) do
			local kid = createNPC("Family")
			if kid then
				pcall(function()
					kid.Model:ScaleTo(0.7)
				end)
				local offset = Vector3.new(index == 1 and -3 or 3, 0, 3)
				place(kid, position + offset)
				activeCount += 1
				task.spawn(runFollower, kid, record, offset)
			end
		end
	end
end

----------------------------------------------------------------------
-- Public API (used by EventService)
----------------------------------------------------------------------
function NPCService.SetAttraction(name, position, types, weight, stayBonus)
	local set = {}
	for _, typeName in ipairs(types) do
		set[typeName] = true
	end
	dynamicAttractions[name] = { Name = name, Position = position, Types = set, Weight = weight, StayBonus = stayBonus }
end

function NPCService.RemoveAttraction(name)
	dynamicAttractions[name] = nil
end

function NPCService.SetVIPResorts(players, spendMultiplier)
	vipResorts = {}
	for _, player in ipairs(players) do
		vipResorts[player] = true
	end
	vipSpendMultiplier = spendMultiplier or 1
end

function NPCService.SetTypeBoost(typeName, multiplier)
	typeWeightBoost[typeName] = multiplier
end

function NPCService.GetActiveCount()
	return activeCount
end

function NPCService.Init(allServices)
	services = allServices

	npcFolder = Instance.new("Folder")
	npcFolder.Name = "NPCs"
	npcFolder.Parent = workspace

	hiddenFolder = Instance.new("Folder")
	hiddenFolder.Name = "NPCsInside"
	hiddenFolder.Parent = ServerStorage

	for _, part in ipairs(workspace:WaitForChild("NPCSpawns"):GetChildren()) do
		table.insert(spawnPoints, Vector3.new(part.Position.X, 0, part.Position.Z))
	end
	for _, part in ipairs(workspace:WaitForChild("Attractions"):GetChildren()) do
		local types = {}
		for typeName in string.gmatch(part:GetAttribute("Types") or "", "[^,]+") do
			types[typeName] = true
		end
		table.insert(staticAttractions, {
			Name = part.Name,
			Position = Vector3.new(part.Position.X, 0, part.Position.Z),
			Types = types,
			Weight = part:GetAttribute("Weight") or 1,
		})
	end
end

function NPCService.Start()
	template = buildTemplate()
	while true do
		task.wait(Config.NPC.SpawnInterval)
		local city = services.CityService.Get()
		local activity = (city.Tourism + city.Popularity) / 200
		local target = Config.NPC.MinActive + (Config.NPC.MaxActive - Config.NPC.MinActive) * activity
		if services.EventService.GetCurrent() then
			target += 6
		end
		if activeCount < math.floor(target) then
			local ok, err = pcall(spawnNPC)
			if not ok then
				warn("[NPCService] spawn failed: " .. tostring(err))
			end
		end
	end
end

return NPCService
