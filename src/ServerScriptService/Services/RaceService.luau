-- RaceService: Street Race for up to 8 real players, topped up with NPC racers so a
-- race is always possible - even alone on the server.
-- Server validates checkpoints, measures times and hands out rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local CarFactory = require(script.Parent.CarFactory)

local RaceService = {}

local services
local raceStateRemote
local carsFolder
local checkpoints = {}
local pathPoints = {}
local gridSpots = {}

local state = "Idle" -- Idle | Lobby | Countdown | Racing | Results
local lobbyEndsAt = 0
local lobby = {} -- array of players waiting
local racers = {} -- array of racer records
local byPlayer = {} -- [player] = racer (Countdown/Racing/Results)
local raceStartedAt = 0
local eventMultiplier = 1

local NPC_NAMES = { "Nova", "Blitz", "Vortex", "Echo", "Zephyr", "Pulse", "Rogue", "Flux" }
local NPC_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(150, 80, 255),
	Color3.fromRGB(60, 255, 150),
	Color3.fromRGB(255, 120, 30),
}
local OUT_OF_CAR_LIMIT = 8
local TRACK_Y = 0.2

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function sortedChildren(folder, prefix)
	local list = {}
	for _, child in ipairs(folder:GetChildren()) do
		local index = tonumber(child.Name:sub(#prefix + 1))
		if index then
			list[index] = child
		end
	end
	return list
end

function RaceService.IsRacing(player)
	return byPlayer[player] ~= nil
end

function RaceService.GetState()
	return state
end

function RaceService.SetEventMultiplier(multiplier)
	eventMultiplier = multiplier
end

local function send(player, payload)
	if player and player.Parent then
		raceStateRemote:FireClient(player, payload)
	end
end

----------------------------------------------------------------------
-- NPC path helpers
----------------------------------------------------------------------
local function buildPath(startPosition)
	local points = { startPosition }
	for _ = 1, Config.Race.Laps do
		for _, point in ipairs(pathPoints) do
			table.insert(points, point)
		end
	end
	table.insert(points, pathPoints[1])
	table.insert(points, pathPoints[2]) -- overshoot past the finish line
	local lengths = { 0 }
	for i = 2, #points do
		lengths[i] = lengths[i - 1] + flatDistance(points[i - 1], points[i])
	end
	return { Points = points, Lengths = lengths, Total = lengths[#lengths] }
end

local function samplePath(path, distance)
	distance = math.clamp(distance, 0, path.Total)
	for i = 2, #path.Points do
		if path.Lengths[i] >= distance then
			local a, b = path.Points[i - 1], path.Points[i]
			local segment = path.Lengths[i] - path.Lengths[i - 1]
			local t = segment > 0 and (distance - path.Lengths[i - 1]) / segment or 0
			local direction = (b - a)
			direction = Vector3.new(direction.X, 0, direction.Z)
			if direction.Magnitude < 0.01 then
				direction = Vector3.new(1, 0, 0)
			end
			return a:Lerp(b, t), direction.Unit
		end
	end
	local last = path.Points[#path.Points]
	return last, Vector3.new(1, 0, 0)
end

----------------------------------------------------------------------
-- Race flow
----------------------------------------------------------------------
local function progressScore(racer)
	if racer.Finished then
		return math.huge
	end
	local nextPoint = checkpoints[racer.NextCP]
	local chassis = racer.Car and racer.Car.PrimaryPart
	local position = chassis and chassis.Position or nextPoint
	return (racer.Lap * #checkpoints + racer.NextCP) * 10000 - flatDistance(position, nextPoint)
end

local function standings()
	local list = table.clone(racers)
	table.sort(list, function(a, b)
		if a.Finished and b.Finished then
			return a.FinishTime < b.FinishTime
		elseif a.Finished ~= b.Finished then
			return a.Finished
		elseif a.DNF ~= b.DNF then
			return not a.DNF
		end
		return progressScore(a) > progressScore(b)
	end)
	return list
end

local function cleanup()
	for _, racer in ipairs(racers) do
		if racer.Car then
			local seat = racer.Car:FindFirstChild("DriverSeat")
			local weld = seat and seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			racer.Car:Destroy()
		end
	end
	local humans = {}
	for player in pairs(byPlayer) do
		table.insert(humans, player)
	end
	racers = {}
	byPlayer = {}
	state = "Idle"
	for _, player in ipairs(humans) do
		send(player, { Phase = "Idle" })
		task.defer(function()
			services.PlayerService.TeleportTo(player, "Racing")
		end)
	end
end

local function finishRace()
	state = "Results"
	local order = standings()
	local board = {}
	for place, racer in ipairs(order) do
		table.insert(board, {
			Place = place,
			Name = racer.Name,
			Time = racer.Finished and Format.RaceTime(racer.FinishTime) or "DNF",
			IsNPC = racer.Player == nil,
		})
	end

	for place, racer in ipairs(order) do
		local player = racer.Player
		if player and player.Parent then
			local cash, xp = 0, 0
			if racer.Finished then
				local reward = Config.Race.Rewards[place] or Config.Race.FinishReward
				cash, xp = reward.Cash * eventMultiplier, reward.XP * eventMultiplier
				local data = services.DataService.Get(player)
				if data then
					data.Stats.RacesCompleted += 1
					if place == 1 then
						data.Stats.RacesWon += 1
					end
					if data.Stats.BestRaceTime == 0 or racer.FinishTime < data.Stats.BestRaceTime then
						data.Stats.BestRaceTime = math.floor(racer.FinishTime * 100) / 100
						services.LeaderboardService.SubmitRaceTime(player, racer.FinishTime)
					end
				end
				services.QuestService.Increment(player, "races", 1)
				services.EconomyService.Reward(player, cash, xp, ("Street Race - place %d"):format(place))
			end
			send(player, {
				Phase = "Results",
				Place = racer.Finished and place or nil,
				Time = racer.Finished and Format.RaceTime(racer.FinishTime) or "DNF",
				Cash = math.floor(cash),
				XP = math.floor(xp),
				Standings = board,
			})
		end
	end
	task.delay(6, cleanup)
end

local function markDNF(racer)
	if racer.Finished or racer.DNF then
		return
	end
	racer.DNF = true
	if racer.Car then
		local seat = racer.Car:FindFirstChild("DriverSeat")
		local weld = seat and seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		racer.Car:Destroy()
		racer.Car = nil
	end
	if racer.Player then
		send(racer.Player, { Phase = "DNF" })
	end
end

local function updateRacer(racer, now)
	if racer.Finished or racer.DNF or not racer.Car or not racer.Car.PrimaryPart then
		return
	end
	local position = racer.Car.PrimaryPart.Position

	if racer.Player then
		local player = racer.Player
		local seat = racer.Car:FindFirstChild("DriverSeat")
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local occupant = seat and seat.Occupant
		if occupant and occupant ~= humanoid then
			-- Somebody else jumped in: eject them.
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			occupant = nil
		end
		if occupant then
			racer.OutSince = nil
		else
			racer.OutSince = racer.OutSince or now
			if now - racer.OutSince > OUT_OF_CAR_LIMIT or not player.Parent then
				markDNF(racer)
				return
			end
		end
	end

	local target = checkpoints[racer.NextCP]
	if flatDistance(position, target) <= Config.Race.CheckpointRadius then
		racer.NextCP += 1
		if racer.NextCP > #checkpoints then
			racer.NextCP = 1
			racer.Lap += 1
			if racer.Lap >= Config.Race.Laps then
				racer.Finished = true
				racer.FinishTime = now - raceStartedAt
				local seat = racer.Car:FindFirstChild("DriverSeat")
				if seat then
					seat:SetAttribute("Locked", true)
				end
			end
		end
	end
end

local function sendHud(now)
	local order = standings()
	for place, racer in ipairs(order) do
		if racer.Player and not racer.DNF then
			send(racer.Player, {
				Phase = racer.Finished and "Finished" or "Racing",
				Lap = math.min(racer.Lap + 1, Config.Race.Laps),
				Laps = Config.Race.Laps,
				Position = place,
				Count = #order,
				Checkpoint = racer.NextCP,
				Checkpoints = #checkpoints,
				NextCheckpoint = checkpoints[racer.NextCP],
				Time = racer.Finished and racer.FinishTime or (now - raceStartedAt),
				OutOfCar = racer.OutSince and math.max(0, OUT_OF_CAR_LIMIT - (now - racer.OutSince)) or nil,
			})
		end
	end
end

local function raceLoop()
	local npcConnection = RunService.Heartbeat:Connect(function(dt)
		for _, racer in ipairs(racers) do
			if not racer.Player and racer.Car and racer.Car.PrimaryPart then
				racer.Distance += racer.Speed * dt
				local position, direction = samplePath(racer.Path, racer.Distance)
				local right = direction:Cross(Vector3.yAxis)
				position += right * racer.LaneOffset
				local chassis = racer.Car.PrimaryPart
				chassis.Follow.Position = Vector3.new(position.X, TRACK_Y + 1.1, position.Z)
				chassis.Face.CFrame = CFrame.lookAt(Vector3.zero, direction)
			end
		end
	end)

	local lastHud = 0
	while state == "Racing" do
		local now = os.clock()
		for _, racer in ipairs(racers) do
			updateRacer(racer, now)
			if not racer.Player and racer.Finished and racer.Distance >= racer.Path.Total - 1 then
				racer.Speed = 0
			end
		end
		if now - lastHud > 0.25 then
			lastHud = now
			sendHud(now)
		end

		local humansActive = false
		for _, racer in ipairs(racers) do
			if racer.Player and not racer.Finished and not racer.DNF then
				humansActive = true
			end
		end
		if not humansActive or now - raceStartedAt > Config.Race.TimeLimit then
			for _, racer in ipairs(racers) do
				if racer.Player and not racer.Finished then
					markDNF(racer)
				end
			end
			break
		end
		task.wait(0.1)
	end
	npcConnection:Disconnect()
	finishRace()
end

local function seatPlayer(player, car)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = car:FindFirstChild("DriverSeat")
	if not humanoid or humanoid.Health <= 0 or not seat then
		return false
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
	return true
end

local function beginRace()
	local humans = {}
	for _, player in ipairs(lobby) do
		local character = player.Parent and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(humans, player)
		end
	end
	lobby = {}
	if #humans == 0 then
		state = "Idle"
		return
	end

	state = "Countdown"
	racers = {}
	local slot = 0
	for _, player in ipairs(humans) do
		slot += 1
		local data = services.DataService.Get(player)
		local paint = Config.Cosmetics[1].Color
		local body = "standard"
		if data then
			for _, cosmetic in ipairs(Config.Cosmetics) do
				if cosmetic.Id == data.Cosmetics.Paint and not cosmetic.IsBody then
					paint = cosmetic.Color
				end
			end
			if data.Cosmetics.Body == "hyper" and services.MonetizationService.HasPass(player, "HyperCar") then
				body = "hyper"
			end
		end
		local car = CarFactory.Build(gridSpots[slot], { Color = paint, Body = body, Name = player.Name .. "_Car" })
		car.PrimaryPart.Anchored = true
		car.Parent = carsFolder
		local racer = { Player = player, Name = player.DisplayName, Car = car, NextCP = 1, Lap = 0, Finished = false, DNF = false }
		table.insert(racers, racer)
		byPlayer[player] = racer
		seatPlayer(player, car)
	end

	local npcCount = math.max(0, math.min(Config.Race.MinRacers, #gridSpots) - #humans)
	local names = table.clone(NPC_NAMES)
	for _ = 1, npcCount do
		slot += 1
		local name = table.remove(names, math.random(#names))
		local car = CarFactory.Build(gridSpots[slot], { Color = NPC_COLORS[math.random(#NPC_COLORS)], NPC = true, Name = "NPC_" .. name })
		car.PrimaryPart.Anchored = true
		car.Parent = carsFolder
		table.insert(racers, {
			Name = name .. " (NPC)",
			Car = car,
			NextCP = 1,
			Lap = 0,
			Finished = false,
			DNF = false,
			Distance = 0,
			Speed = math.random(Config.Race.NPCSpeedMin * 10, Config.Race.NPCSpeedMax * 10) / 10,
			LaneOffset = math.random(-6, 6),
			Path = buildPath(gridSpots[slot].Position),
		})
	end

	for count = Config.Race.CountdownTime, 1, -1 do
		for _, racer in ipairs(racers) do
			if racer.Player then
				send(racer.Player, { Phase = "Countdown", Count = count })
				-- Retry seating in case the first attempt raced the character.
				local seat = racer.Car:FindFirstChild("DriverSeat")
				if seat and not seat.Occupant then
					seatPlayer(racer.Player, racer.Car)
				end
			end
		end
		task.wait(1)
	end

	raceStartedAt = os.clock()
	state = "Racing"
	for _, racer in ipairs(racers) do
		if racer.Car and racer.Car.PrimaryPart then
			local chassis = racer.Car.PrimaryPart
			chassis.Anchored = false
			pcall(function()
				chassis:SetNetworkOwner(racer.Player and racer.Player.Parent and racer.Player or nil)
			end)
		end
		if racer.Player then
			send(racer.Player, { Phase = "Go" })
		end
	end
	raceLoop()
end

local function openLobby()
	if state ~= "Idle" then
		return false
	end
	state = "Lobby"
	lobby = {}
	lobbyEndsAt = os.clock() + Config.Race.LobbyTime
	services.EconomyService.NotifyAll(("Street Race starting in %ds! Press PLAY > Street Race to join."):format(Config.Race.LobbyTime), "race")
	task.delay(Config.Race.LobbyTime, function()
		local ok, err = pcall(beginRace)
		if not ok then
			warn("[RaceService] race failed: " .. tostring(err))
			cleanup()
		end
	end)
	return true
end

function RaceService.OpenLobby()
	return openLobby()
end

function RaceService.Join(player)
	if not services.DataService.IsLoaded(player) then
		return false, "Loading..."
	end
	if byPlayer[player] then
		return false, "You are already racing"
	end
	if table.find(lobby, player) then
		return true, "Already in the lobby"
	end
	if state == "Idle" then
		openLobby()
	end
	if state ~= "Lobby" then
		services.EconomyService.Notify(player, "A race is running right now. Try again in a moment!", "info")
		return false, "Race in progress"
	end
	if #lobby >= math.min(Config.Race.MaxParticipants, #gridSpots) then
		return false, "Race is full"
	end
	table.insert(lobby, player)
	local remaining = math.max(0, math.ceil(lobbyEndsAt - os.clock()))
	services.EconomyService.Notify(player, ("Joined the Street Race! Starting in %ds."):format(remaining), "race")
	send(player, { Phase = "Lobby", Remaining = remaining })
	services.EventService.MarkParticipant(player, "StreetRace")
	return true
end

function RaceService.Init(allServices)
	services = allServices
	raceStateRemote = Remotes.Get("RaceState")

	local track = workspace:WaitForChild("RaceTrack")
	for _, part in ipairs(sortedChildren(track:WaitForChild("Checkpoints"), "CP")) do
		table.insert(checkpoints, Vector3.new(part.Position.X, TRACK_Y, part.Position.Z))
	end
	for _, part in ipairs(sortedChildren(track:WaitForChild("Path"), "W")) do
		table.insert(pathPoints, Vector3.new(part.Position.X, TRACK_Y, part.Position.Z))
	end
	for _, part in ipairs(sortedChildren(track:WaitForChild("Grid"), "G")) do
		local position = Vector3.new(part.Position.X, TRACK_Y, part.Position.Z)
		-- Grid faces the first path segment (race direction).
		local direction = (pathPoints[2] - pathPoints[1]) * Vector3.new(1, 0, 1)
		table.insert(gridSpots, CFrame.lookAt(position, position + direction.Unit))
	end

	carsFolder = Instance.new("Folder")
	carsFolder.Name = "RaceCars"
	carsFolder.Parent = workspace

	Remotes.Get("JoinRace").OnServerInvoke = function(player)
		return RaceService.Join(player)
	end

	-- Stepping on the race pad joins too.
	local pad = track:FindFirstChild("JoinPad")
	if pad then
		local debounce = {}
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and not debounce[player] then
				debounce[player] = true
				RaceService.Join(player)
				task.delay(4, function()
					debounce[player] = nil
				end)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local index = table.find(lobby, player)
		if index then
			table.remove(lobby, index)
		end
		local racer = byPlayer[player]
		if racer then
			markDNF(racer)
			byPlayer[player] = nil
		end
	end)
end

return RaceService
