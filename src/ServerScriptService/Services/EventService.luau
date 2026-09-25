-- EventService: server-driven city events that keep the city moving even with 1-3 players.
-- Flow: Scheduler -> choose event -> announcement -> NPC reaction -> players participate
--       -> event ends -> rewards / statistics

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local EventService = {}

local services
local eventRemote
local current = nil
local lastEventId = nil
local nextEventAt = 0 -- os.clock()
local nextEventServerTime = 0 -- workspace:GetServerTimeNow()

local PARTICIPATION_CASH = 250
local PARTICIPATION_XP = 60

-- Blackout state
local cityLights = {} -- { Part, Color, Material }
local cityPointLights = {}
local generators = {} -- { Model, Body, Status, Prompt, Repaired }

-- Concert state
local stageLights = {}
local crowdZone

local NEONS = {
	Color3.fromRGB(0, 235, 255),
	Color3.fromRGB(255, 40, 200),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(140, 255, 60),
	Color3.fromRGB(150, 80, 255),
	Color3.fromRGB(255, 120, 30),
}

function EventService.GetCurrent()
	return current
end

function EventService.MarkParticipant(player, eventId)
	if current and current.Id == eventId and not current.Participants[player] then
		current.Participants[player] = true
		services.EconomyService.Notify(player, "You joined the event: " .. current.Name, "event")
	end
end

local function publicInfo()
	if not current then
		return { NextAt = nextEventServerTime }
	end
	return {
		Id = current.Id,
		Name = current.Name,
		Description = current.Description,
		Hint = current.Hint,
		EndsAt = current.EndsAtServer,
		NextAt = nextEventServerTime,
	}
end

local function broadcast()
	eventRemote:FireAllClients(publicInfo())
end

----------------------------------------------------------------------
-- Event definitions
----------------------------------------------------------------------
local Events = {}

Events.Blackout = {
	Name = "City Blackout",
	Description = "The Entertainment District lost power!",
	Hint = "Go to the Entertainment District and repair 3 generators.",
	Duration = Config.Events.Blackout.Duration,
	Start = function()
		for _, entry in ipairs(cityLights) do
			entry.Part.Material = Enum.Material.SmoothPlastic
			entry.Part.Color = Color3.new(entry.Color.R * 0.12, entry.Color.G * 0.12, entry.Color.B * 0.12)
		end
		for _, light in ipairs(cityPointLights) do
			light.Enabled = false
		end
		for _, generator in ipairs(generators) do
			generator.Repaired = false
			generator.Status.Color = Color3.fromRGB(255, 40, 40)
			generator.Prompt.Enabled = true
		end
		services.CityService.SetPowerOverride(30)
	end,
	Stop = function()
		for _, entry in ipairs(cityLights) do
			entry.Part.Material = entry.Material
			entry.Part.Color = entry.Color
		end
		for _, light in ipairs(cityPointLights) do
			light.Enabled = true
		end
		for _, generator in ipairs(generators) do
			generator.Status.Color = Color3.fromRGB(140, 255, 60)
			generator.Prompt.Enabled = false
		end
		services.CityService.SetPowerOverride(nil)
	end,
}

Events.Concert = {
	Name = "Live Concert",
	Description = "A concert started at the Entertainment District stage!",
	Hint = "Stand in the crowd in front of the stage to earn rewards.",
	Duration = Config.Events.Concert.Duration,
	Start = function()
		local center = crowdZone and crowdZone.Position or Vector3.new(400, 0, 70)
		services.NPCService.SetAttraction("Concert", Vector3.new(center.X, 0, center.Z), { "Event", "Tourist", "Family", "Racer", "Luxury", "Business" }, 25, 20)
		services.NPCService.SetTypeBoost("Event", 4)
		task.spawn(function()
			local event = current
			local lastTick = os.clock()
			while current == event do
				for _, entry in ipairs(stageLights) do
					entry.Part.Color = NEONS[math.random(#NEONS)]
				end
				if os.clock() - lastTick >= Config.Events.Concert.TickInterval and crowdZone then
					lastTick = os.clock()
					for _, player in ipairs(Players:GetPlayers()) do
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if root and services.ZoneService.PointInPart(crowdZone, root.Position) then
							EventService.MarkParticipant(player, "Concert")
							services.EconomyService.AddCash(player, Config.Events.Concert.TickCash, "concert")
							services.EconomyService.AddXP(player, Config.Events.Concert.TickXP)
							services.EconomyService.Popup(player, root.Position + Vector3.new(0, 5, 0), "+" .. Format.Money(Config.Events.Concert.TickCash), Color3.fromRGB(255, 40, 200))
						end
					end
				end
				task.wait(0.4)
			end
		end)
	end,
	Stop = function()
		services.NPCService.RemoveAttraction("Concert")
		services.NPCService.SetTypeBoost("Event", 1)
		for _, entry in ipairs(stageLights) do
			entry.Part.Color = entry.Color
		end
	end,
}

Events.VIPNight = {
	Name = "VIP Night",
	Description = "Luxury tourists flood selected resorts!",
	Hint = "Chosen resorts earn double. Visit them to join the party.",
	Duration = Config.Events.VIPNight.Duration,
	Eligible = function()
		for _, player in ipairs(Players:GetPlayers()) do
			if (player:GetAttribute("ResortRating") or 0) > 0 then
				return true
			end
		end
		return false
	end,
	Start = function(event)
		local owners = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if (player:GetAttribute("ResortRating") or 0) > 0 then
				table.insert(owners, player)
			end
		end
		-- Shuffle so every resort gets a chance, not only the biggest one.
		for i = #owners, 2, -1 do
			local j = math.random(i)
			owners[i], owners[j] = owners[j], owners[i]
		end
		local chosen, names = {}, {}
		for i = 1, math.min(Config.Events.VIPNight.Resorts, #owners) do
			table.insert(chosen, owners[i])
			table.insert(names, owners[i].DisplayName)
			event.Participants[owners[i]] = true
		end
		event.Chosen = chosen
		event.Description = "VIP Night at " .. table.concat(names, " & ") .. "'s resort! Luxury tourists everywhere."
		services.NPCService.SetVIPResorts(chosen, Config.Events.VIPNight.SpendMultiplier)
		services.NPCService.SetTypeBoost("Luxury", 3)
	end,
	Stop = function()
		services.NPCService.SetVIPResorts({}, 1)
		services.NPCService.SetTypeBoost("Luxury", 1)
	end,
}

Events.StreetRace = {
	Name = "Race Rush",
	Description = "Double race rewards for everyone!",
	Hint = "Join a Street Race (PLAY > Street Race) for 2x cash and XP.",
	Duration = Config.Events.StreetRace.Duration,
	Start = function()
		services.RaceService.SetEventMultiplier(Config.Race.EventMultiplier)
		services.RaceService.OpenLobby()
	end,
	Stop = function()
		services.RaceService.SetEventMultiplier(1)
	end,
}

local EVENT_IDS = { "Blackout", "Concert", "VIPNight", "StreetRace" }

----------------------------------------------------------------------
-- Scheduler
----------------------------------------------------------------------
local function scheduleNext()
	local delay = math.random(Config.Events.IntervalMin, Config.Events.IntervalMax)
	nextEventAt = os.clock() + delay
	nextEventServerTime = workspace:GetServerTimeNow() + delay
end

local function startEvent(id)
	local def = Events[id]
	current = {
		Id = id,
		Name = def.Name,
		Description = def.Description,
		Hint = def.Hint,
		Participants = {},
		EndsAtClock = os.clock() + def.Duration,
		EndsAtServer = workspace:GetServerTimeNow() + def.Duration,
	}
	lastEventId = id
	local ok, err = pcall(def.Start, current)
	if not ok then
		warn("[EventService] start failed: " .. tostring(err))
	end
	services.EconomyService.NotifyAll("EVENT: " .. current.Name .. " - " .. current.Hint, "event")
	broadcast()
	services.CityService.Update()
end

local function stopEvent(reason)
	local event = current
	if not event then
		return
	end
	current = nil
	local ok, err = pcall(Events[event.Id].Stop, event)
	if not ok then
		warn("[EventService] stop failed: " .. tostring(err))
	end
	for player in pairs(event.Participants) do
		if player.Parent then
			local data = services.DataService.Get(player)
			if data then
				data.Stats.EventsJoined += 1
			end
			services.QuestService.Increment(player, "event", 1)
			services.EconomyService.Reward(player, PARTICIPATION_CASH, PARTICIPATION_XP, event.Name .. " participation")
		end
	end
	scheduleNext()
	services.EconomyService.NotifyAll(event.Name .. (reason or " has ended."), "event")
	broadcast()
	services.CityService.Update()
end

local function pickEvent()
	local options = {}
	for _, id in ipairs(EVENT_IDS) do
		local def = Events[id]
		if id ~= lastEventId and (not def.Eligible or def.Eligible()) then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		return "Concert"
	end
	return options[math.random(#options)]
end

-- Starts a specific event right now (admin tools / automated tests).
function EventService.ForceStart(id)
	if not Events[id] then
		return false
	end
	if current then
		stopEvent(nil)
	end
	startEvent(id)
	return true
end

function EventService.OnZoneChanged(player, zoneKey)
	if current and current.Id == "VIPNight" and zoneKey and current.Chosen then
		for _, owner in ipairs(current.Chosen) do
			if zoneKey == "resort:" .. owner.UserId then
				EventService.MarkParticipant(player, "VIPNight")
			end
		end
	end
end

----------------------------------------------------------------------
-- Event board (plaza)
----------------------------------------------------------------------
local boardLabels

local function createBoard()
	local board = workspace:FindFirstChild("City") and workspace.City.Plaza:FindFirstChild("EventBoard")
	if not board then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "EventGui"
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 30)
	padding.PaddingLeft = UDim.new(0, 30)
	padding.PaddingRight = UDim.new(0, 30)
	padding.Parent = gui

	local function line(name, height, color, font)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = font or Enum.Font.GothamBold
		label.TextColor3 = color
		label.Text = ""
		label.Parent = gui
		return label
	end
	boardLabels = {
		Title = line("Title", 70, Color3.fromRGB(255, 40, 200), Enum.Font.GothamBlack),
		Event = line("Event", 60, Color3.new(1, 1, 1), Enum.Font.GothamBlack),
		Hint = line("Hint", 70, Color3.fromRGB(0, 235, 255)),
		Timer = line("Timer", 50, Color3.fromRGB(255, 200, 60)),
		Stats = line("Stats", 150, Color3.fromRGB(200, 200, 230)),
	}
	boardLabels.Title.Text = "CITY EVENTS"
end

local function updateBoard()
	if not boardLabels then
		return
	end
	if current then
		boardLabels.Event.Text = "NOW: " .. string.upper(current.Name)
		boardLabels.Hint.Text = current.Hint
		boardLabels.Timer.Text = "Ends in " .. Format.Time(current.EndsAtClock - os.clock())
	else
		boardLabels.Event.Text = "NEXT EVENT"
		boardLabels.Hint.Text = "Blackout, Concert, VIP Night or Race Rush"
		boardLabels.Timer.Text = "Starts in " .. Format.Time(nextEventAt - os.clock())
	end
	local stats = services.CityService.Get()
	boardLabels.Stats.Text = ("Power %d%%   Tourism %d%%\nSecurity %d%%   Popularity %d%%"):format(stats.Power, stats.Tourism, stats.Security, stats.Popularity)
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
local function setupBlackout()
	local district = workspace:WaitForChild("City"):WaitForChild("Entertainment")
	for _, descendant in ipairs(district:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			table.insert(cityLights, { Part = descendant, Color = descendant.Color, Material = descendant.Material })
		elseif descendant:IsA("Light") then
			table.insert(cityPointLights, descendant)
		end
	end

	local folder = workspace:WaitForChild("EventAreas"):WaitForChild("Generators")
	for _, model in ipairs(folder:GetChildren()) do
		local body = model:FindFirstChild("Body")
		local status = model:FindFirstChild("Status")
		if body and status then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Repair Generator"
			prompt.ObjectText = "Generator"
			prompt.HoldDuration = 2.5
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt.Parent = body
			local generator = { Model = model, Body = body, Status = status, Prompt = prompt, Repaired = true }
			table.insert(generators, generator)

			prompt.Triggered:Connect(function(player)
				if not current or current.Id ~= "Blackout" or generator.Repaired then
					return
				end
				generator.Repaired = true
				generator.Status.Color = Color3.fromRGB(140, 255, 60)
				prompt.Enabled = false
				EventService.MarkParticipant(player, "Blackout")
				local cfg = Config.Events.Blackout
				services.EconomyService.Reward(player, cfg.RepairCash, cfg.RepairXP, "Generator repaired")

				local repaired = 0
				for _, other in ipairs(generators) do
					if other.Repaired then
						repaired += 1
					end
				end
				services.CityService.SetPowerOverride(30 + math.floor(70 * repaired / #generators))
				if repaired == #generators then
					for participant in pairs(current.Participants) do
						if participant.Parent then
							services.EconomyService.Reward(participant, cfg.AllRepairedBonusCash, cfg.AllRepairedBonusXP, "Power restored bonus")
						end
					end
					stopEvent(" is over - power restored! Great teamwork.")
				else
					services.EconomyService.NotifyAll(("Generator repaired by %s (%d/%d)"):format(player.DisplayName, repaired, #generators), "event")
				end
			end)
		end
	end
end

local function setupConcert()
	local concert = workspace:WaitForChild("EventAreas"):WaitForChild("Concert")
	crowdZone = concert:FindFirstChild("CrowdZone")
	local lights = concert:FindFirstChild("Lights")
	if lights then
		for _, part in ipairs(lights:GetChildren()) do
			if part:IsA("BasePart") then
				table.insert(stageLights, { Part = part, Color = part.Color })
			end
		end
	end
end

function EventService.Init(allServices)
	services = allServices
	eventRemote = Remotes.Get("EventState")
	setupBlackout()
	setupConcert()
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				eventRemote:FireClient(player, publicInfo())
			end
		end)
	end)
end

function EventService.Start()
	createBoard()
	nextEventAt = os.clock() + Config.Events.FirstDelay
	nextEventServerTime = workspace:GetServerTimeNow() + Config.Events.FirstDelay
	broadcast()
	while true do
		task.wait(1)
		local now = os.clock()
		if current then
			if now >= current.EndsAtClock then
				stopEvent(nil)
			end
		elseif now >= nextEventAt then
			startEvent(pickEvent())
		end
		updateBoard()
	end
end

return EventService
