-- JobService: optional activities (design doc section 14). Currently: Delivery.
-- Pick up a package at the plaza, bring it across the city before the timer runs out.
-- Never required for progression; just another way to earn and explore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PlotUtil = require(Shared.PlotUtil)
local Remotes = require(Shared.Remotes)

local JobService = {}

local services
local stateRemote
local active = {} -- [player] = job

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function destinations(player)
	local list = {}
	for _, part in ipairs(workspace:WaitForChild("Attractions"):GetChildren()) do
		table.insert(list, { Name = part.Name:gsub("(%l)(%u)", "%1 %2"), Position = Vector3.new(part.Position.X, 0, part.Position.Z) })
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local plot = other ~= player and services.PlotService.GetPlot(other)
		if plot then
			table.insert(list, { Name = other.DisplayName .. "'s Resort", Position = PlotUtil.Entrance(plot.Model) })
		end
	end
	table.insert(list, { Name = "Train Station", Position = Vector3.new(-440, 0, 30) })
	table.insert(list, { Name = "Hotel District", Position = Vector3.new(0, 0, -820) })
	return list
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function send(player, payload)
	if player.Parent then
		stateRemote:FireClient(player, payload)
	end
end

function JobService.StartDelivery(player)
	if active[player] then
		return false, "You already carry a package"
	end
	if services.RaceService.IsRacing(player) then
		return false, "Finish your race first"
	end
	local root = rootOf(player)
	if not root then
		return false, "No character"
	end
	local cfg = Config.Jobs.Delivery
	local options = {}
	for _, destination in ipairs(destinations(player)) do
		if flatDistance(destination.Position, root.Position) >= cfg.MinDistance then
			table.insert(options, destination)
		end
	end
	if #options == 0 then
		return false, "No destination available"
	end
	local destination = options[math.random(#options)]
	local distance = flatDistance(destination.Position, root.Position)
	local duration = math.floor(cfg.BaseTime + distance * cfg.SecondsPerStud)
	local job = {
		Name = destination.Name,
		Target = destination.Position,
		Cash = math.floor(cfg.BaseCash + distance * cfg.CashPerStud),
		XP = math.floor(cfg.BaseXP + distance * cfg.XPPerStud),
		EndsAtClock = os.clock() + duration,
		EndsAt = workspace:GetServerTimeNow() + duration,
	}
	active[player] = job
	send(player, { Phase = "Active", Name = job.Name, Target = job.Target, EndsAt = job.EndsAt, Cash = job.Cash })
	services.EconomyService.Notify(player, ("Delivery: bring the package to %s within %ds!"):format(job.Name, duration), "event")
	return true
end

function JobService.Cancel(player)
	if active[player] then
		active[player] = nil
		send(player, { Phase = "Idle" })
	end
end

function JobService.Init(allServices)
	services = allServices
	stateRemote = Remotes.Get("JobState")
	Remotes.Get("JobAction").OnServerInvoke = function(player, action)
		if action == "StartDelivery" then
			return JobService.StartDelivery(player)
		elseif action == "Cancel" then
			JobService.Cancel(player)
			return true
		end
		return false, "Unknown action"
	end
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
	end)
end

function JobService.Start()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for player, job in pairs(active) do
			local root = rootOf(player)
			if not player.Parent then
				active[player] = nil
			elseif root and flatDistance(root.Position, job.Target) <= Config.Jobs.Delivery.ArriveRadius then
				active[player] = nil
				local data = services.DataService.Get(player)
				if data then
					data.Stats.Deliveries += 1
				end
				services.QuestService.Increment(player, "deliveries", 1)
				services.EconomyService.Reward(player, job.Cash, job.XP, "Delivery complete")
				services.EconomyService.Popup(player, root.Position + Vector3.new(0, 5, 0), "+$" .. job.Cash, Color3.fromRGB(255, 130, 40))
				services.AnalyticsService.Log(player, "DeliveryComplete")
				send(player, { Phase = "Done" })
			elseif now > job.EndsAtClock then
				active[player] = nil
				services.EconomyService.Notify(player, "Delivery failed - too slow! Try again at the Delivery kiosk.", "warning")
				send(player, { Phase = "Failed" })
			end
		end
	end
end

return JobService
