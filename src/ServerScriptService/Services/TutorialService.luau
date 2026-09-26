-- TutorialService: guides new players through the core loop once (resort -> build -> earn -> tasks).
-- Steps only advance on server-side events, so rewards cannot be farmed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Tutorial = require(Shared.Tutorial)

local TutorialService = {}

local services
local stepStartedAt = {} -- [player] = os.clock()

local function currentStep(data)
	return data.Tutorial or 1
end

local function complete(player, data)
	local index = currentStep(data)
	local step = Tutorial.Steps[index]
	if not step then
		return
	end
	data.Tutorial = index + 1
	stepStartedAt[player] = os.clock()
	services.EconomyService.Reward(player, step.Cash, step.XP, "Tutorial step done")
	services.AnalyticsService.Log(player, "TutorialStep" .. index)
	if data.Tutorial == Tutorial.Done then
		services.EconomyService.Notify(player, "Tutorial complete! The city is yours - check NEXT GOAL any time.", "levelup")
	end
	services.DataService.MarkDirty(player)
	-- Some steps may already be satisfied (e.g. returning players with buildings).
	task.defer(TutorialService.Check, player)
end

-- Called by other services when something tutorial-relevant happens.
function TutorialService.Event(player, stepId)
	local data = services.DataService.Get(player)
	if not data then
		return
	end
	local step = Tutorial.Steps[currentStep(data)]
	if step and step.Id == stepId then
		complete(player, data)
	end
end

-- Re-evaluates state-based steps.
function TutorialService.Check(player)
	local data = services.DataService.Get(player)
	if not data then
		return
	end
	local step = Tutorial.Steps[currentStep(data)]
	if not step then
		return
	end
	local done = (step.Id == "FirstBuilding" and #data.Buildings >= 1)
		or (step.Id == "SecondBuilding" and #data.Buildings >= 2)
		or (step.Id == "GoToResort" and services.ZoneService.GetZone(player) == "resort:self")
	if done then
		complete(player, data)
	end
end

function TutorialService.Init(allServices)
	services = allServices

	services.DataService.PlayerLoaded:Connect(function(player, data)
		if data.Tutorial == nil then
			-- Existing saves from before the tutorial existed skip it.
			data.Tutorial = (#data.Buildings > 0) and Tutorial.Done or 1
		end
		stepStartedAt[player] = os.clock()
	end)

	services.DataService.AddSnapshotProvider(function(player, snapshot)
		local data = services.DataService.Get(player)
		snapshot.Tutorial = data and data.Tutorial or Tutorial.Done
	end)

	Remotes.Get("TutorialAction").OnServerInvoke = function(player, action)
		local data = services.DataService.Get(player)
		if not data then
			return false
		end
		if action == "Skip" then
			data.Tutorial = Tutorial.Done
			services.DataService.MarkDirty(player)
			return true
		elseif action == "TasksOpened" then
			TutorialService.Event(player, "OpenTasks")
			return true
		end
		return false
	end

	Players.PlayerRemoving:Connect(function(player)
		stepStartedAt[player] = nil
	end)
end

function TutorialService.Start()
	-- Time-based auto completion (e.g. waiting for the first visitor).
	while true do
		task.wait(5)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = services.DataService.Get(player)
			local step = data and Tutorial.Steps[currentStep(data)]
			if step then
				if step.AutoCompleteAfter and os.clock() - (stepStartedAt[player] or os.clock()) > step.AutoCompleteAfter then
					complete(player, data)
				else
					TutorialService.Check(player)
				end
			end
		end
	end
end

return TutorialService
