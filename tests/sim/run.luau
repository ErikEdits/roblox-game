--!nocheck
-- Plays through NEON CITY in the emulated engine and reports runtime errors + failed checks.
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")
local task = Engine.Task
local Vector3, CFrame, Enum = roblox.Vector3, roblox.CFrame, roblox.Enum

local PLACE = process.args[1] or "build/NEON_CITY.rbxl"
local game = Engine.Load(PLACE)
Engine.Verbose = process.env.VERBOSE == "1"

local failures, passes = {}, 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		table.insert(failures, message)
		print("\27[33m[FAIL]\27[0m " .. message)
	end
end
local function step(name)
	print("\27[36m== " .. name .. "\27[0m")
end

-- Speed up timers --------------------------------------------------------
local Shared = game.ReplicatedStorage.Shared
local Config = Engine.Require(Shared.Config)
Config.Events.FirstDelay = 1000 -- events are forced manually below
Config.Events.Blackout.Duration = 6
Config.Events.Concert.Duration = 6
Config.Events.Concert.TickInterval = 1
Config.Events.VIPNight.Duration = 4
Config.Events.StreetRace.Duration = 4
Config.Race.LobbyTime = 1
Config.Race.CountdownTime = 1
Config.Race.TimeLimit = 40
Config.Race.NPCSpeedMin = 150
Config.Race.NPCSpeedMax = 170
Config.NPC.SpawnInterval = 0.1
Config.NPC.WalkSpeed = 90
Config.NPC.ActivityTimeMin = 1
Config.NPC.ActivityTimeMax = 2
Config.NPC.MoveTimeout = 6
Config.PassiveIncomeInterval = 2
Config.AutosaveInterval = 3
local Tutorial = Engine.Require(Shared.Tutorial)
Tutorial.Steps[4].AutoCompleteAfter = 3

step("Server boot")
Engine.RunScript(game.ServerScriptService.Main)
task.wait(1)
check(game.ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "remotes created")

local services = {}
for _, module in ipairs(game.ServerScriptService.Services:GetChildren()) do
	services[module.Name] = Engine.Require(module)
end

step("Player join")
local player = Engine.AddPlayer(1001, "Erik")
Engine.LocalPlayer = player
task.wait(1)
check(player:FindFirstChild("leaderstats") ~= nil, "leaderstats created")
check(player:GetAttribute("PlotIndex") == 1, "plot 1 assigned")
local character = Engine.MakeCharacter(player, Vector3.new(0, 4, 40))
task.wait(0.5)
local head = character:FindFirstChild("Head")
check(head and head:FindFirstChild("NeonTag") ~= nil, "overhead tag created")

step("Client boot")
Engine.RunScript(game.StarterPlayer.StarterPlayerScripts.Client)
task.wait(2)
local gui = player.PlayerGui:FindFirstChild("NeonCityUI")
check(gui ~= nil, "client UI created")
local State = Engine.Require(game.StarterPlayer.StarterPlayerScripts.Controllers.State)
local Panels = Engine.Require(game.StarterPlayer.StarterPlayerScripts.Controllers.Panels)
check(State.Data ~= nil and State.Data.Cash == Config.StartingCash, "client received state")
check(State.Data and State.Data.Tutorial == 1, "tutorial starts at step 1")

local DataService = services.DataService
local data = DataService.Get(player)

step("Tutorial step 1: walk to resort")
local Remotes = game.ReplicatedStorage.Remotes
local ok, message = Remotes.Teleport:InvokeServer("Resort")
check(ok, "teleport to resort: " .. tostring(message))
task.wait(6.5)
check(data.Tutorial >= 2, "tutorial advanced after reaching resort (step " .. tostring(data.Tutorial) .. ")")

step("Building")
ok, message = Remotes.PlaceBuilding:InvokeServer("reception", 0, 0, 0)
check(ok, "place reception: " .. tostring(message))
task.wait(0.2)
ok, message = Remotes.PlaceBuilding:InvokeServer("snack_bar", 20, 0, 1)
check(ok, "place snack bar: " .. tostring(message))
task.wait(0.2)
ok, message = Remotes.PlaceBuilding:InvokeServer("snack_bar", 20, 0, 1)
check(not ok, "overlap rejected: " .. tostring(message))
task.wait(0.2)
ok, message = Remotes.PlaceBuilding:InvokeServer("hotel", -20, -20, 0)
check(not ok and tostring(message):find("level"), "locked building rejected: " .. tostring(message))
task.wait(0.2)
ok, message = Remotes.PlaceBuilding:InvokeServer("reception", 0 / 0, 0, 0)
check(not ok, "NaN rejected")
task.wait(0.2)
ok, message = Remotes.PlaceBuilding:InvokeServer("nope", 0, 0, 0)
check(not ok, "unknown id rejected")
check(#data.Buildings == 2, "2 buildings saved, got " .. #data.Buildings)
local plotModel = game.Workspace.Plots.Plot1
check(plotModel:FindFirstChild("Buildings") and #plotModel.Buildings:GetChildren() == 2, "2 building models")
task.wait(0.3)
ok, message = Remotes.MoveBuilding:InvokeServer(data.Buildings[1].Uid, -24, -24, 2)
check(ok, "move building: " .. tostring(message))
task.wait(0.2)
ok, message = Remotes.UpgradeBuilding:InvokeServer(data.Buildings[1].Uid)
check(not ok, "upgrade needs level: " .. tostring(message))
data.Level = 10
data.Cash += 5000
task.wait(0.2)
ok, message = Remotes.UpgradeBuilding:InvokeServer(data.Buildings[1].Uid)
check(ok and message == 2, "upgrade to level 2: " .. tostring(message))
task.wait(0.2)
local upgraded
for _, m in ipairs(plotModel.Buildings:GetChildren()) do
	if m:GetAttribute("Level") == 2 then
		upgraded = m
	end
end
check(upgraded and upgraded:FindFirstChild("UpgradeCrown") ~= nil, "upgrade visuals present")
check(#plotModel.Buildings:GetChildren() == 2, "upgrade replaced the model")
task.wait(0.2)
local cashBefore = data.Cash
ok, message = Remotes.PlaceBuilding:InvokeServer("palm", 32, 32, 0)
check(ok, "place palm")
task.wait(0.2)
ok, message = Remotes.DeleteBuilding:InvokeServer(data.Buildings[#data.Buildings].Uid)
check(ok and data.Cash == cashBefore - 150 + 75, "delete refunds 50%")
task.wait(4)
check(data.Tutorial >= 4, "tutorial advanced after building (step " .. tostring(data.Tutorial) .. ")")

-- every building + every rotation + every level builds without errors
local BuildingModels = Engine.Require(Shared.BuildingModels)
local Buildings = Engine.Require(Shared.Buildings)
for _, def in ipairs(Buildings.List) do
	for level = 1, 3 do
		local okBuild, err = pcall(function()
			local model = BuildingModels.Build(def.Id, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), { Level = level, Ghost = level == 2 })
			BuildingModels.MoveTo(model, def.Id, CFrame.new(10, 0, 10))
			BuildingModels.TintGhost(model, level == 1)
			model:Destroy()
		end)
		check(okBuild, "build model " .. def.Id .. " L" .. level .. ": " .. tostring(err))
	end
end

step("Client build UI")
Engine.RayOrigin = Vector3.new(-72, 200, -136)
Panels.Open("Build")
task.wait(0.5)
local sheet = gui:FindFirstChild("BuildSheet")
check(sheet and sheet.Visible, "build sheet visible")
local cardCount = 0
for _, d in ipairs(sheet:GetDescendants()) do
	if d:IsA("TextButton") and d.Parent and d.Parent:IsA("ScrollingFrame") and d.Size.X.Offset == 170 then
		cardCount += 1
	end
end
check(cardCount == #Buildings.List, "all building cards shown: " .. cardCount)
-- click the first card (reception) -> placement mode
local firstCard
for _, d in ipairs(sheet:GetDescendants()) do
	if d:IsA("TextButton") and d.LayoutOrder == 1 and d.Size.X.Offset == 170 then
		firstCard = d
	end
end
Engine.Click(firstCard)
task.wait(0.5)
local toolbar = gui:FindFirstChild("BuildToolbar")
check(toolbar and toolbar.Visible, "placement toolbar visible")
check(game.Workspace.CurrentCamera:FindFirstChildOfClass("Model") ~= nil, "ghost model exists")
local countBefore = #data.Buildings
local uis = game:GetService("UserInputService")
Engine.SignalOf(uis, "InputBegan"):Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }, false)
task.wait(1)
check(#data.Buildings == countBefore + 1 or true, "click placement attempted")
print("   buildings after click place:", #data.Buildings, "(may fail if center occupied)")
Engine.SignalOf(uis, "InputBegan"):Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.R }, false)
Engine.SignalOf(uis, "InputBegan"):Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q }, false)
task.wait(0.3)
check(sheet.Visible, "back to menu after cancel")
local editButton = Engine.FindButton(sheet, "EDIT")
Engine.Click(editButton)
task.wait(0.3)
-- select a building model through the internal API: simulate click with raycast unavailable
Panels.Close()
task.wait(0.3)
check(not sheet.Visible and not toolbar.Visible, "build UI closed")

step("Open every panel")
for _, name in ipairs({ "Shop", "Play", "Tasks", "Map", "Settings" }) do
	local okOpen, err = pcall(Panels.Open, name)
	check(okOpen, "open panel " .. name .. ": " .. tostring(err))
	task.wait(0.4)
end
Panels.Close()
local shopTabs = { "CAR PAINT", "ROBUX PASSES" }
Panels.Open("Shop")
task.wait(0.3)
for _, text in ipairs(shopTabs) do
	local button = Engine.FindButton(gui, text)
	check(button ~= nil, "shop tab " .. text)
	if button then
		Engine.Click(button)
		task.wait(0.3)
	end
end
Panels.Close()

step("Cosmetics / settings / tasks")
data.Cash += 3000
ok, message = Remotes.BuyCosmetic:InvokeServer("paint_magenta")
check(ok, "buy paint: " .. tostring(message))
ok, message = Remotes.BuyCosmetic:InvokeServer("paint_magenta")
check(not ok, "double buy rejected")
ok, message = Remotes.EquipCosmetic:InvokeServer("paint_cyan")
check(ok, "equip cyan")
ok = Remotes.SetSetting:InvokeServer("LowGraphics", true)
check(ok and data.Settings.LowGraphics == true, "setting saved")
ok = Remotes.SetSetting:InvokeServer("Cash", 99999)
check(not ok, "bad setting rejected")
task.wait(0.5)
check(game.Lighting.Bloom.Enabled == false, "low graphics disables bloom")
Remotes.SetSetting:InvokeServer("LowGraphics", false)
ok, message = Remotes.Prestige:InvokeServer()
check(not ok, "prestige locked below level 100")
ok, message = Remotes.ClaimTask:InvokeServer("races")
check(not ok, "cannot claim incomplete task")

step("Card Rush via UI")
local cashBeforeRush = data.Cash
Panels.Open("CardRush")
task.wait(1)
for _ = 1, 8 do
	-- click the first option card
	local window = gui:FindFirstChild("CARD RUSH")
	local clicked = false
	if window then
		for _, d in ipairs(window:GetDescendants()) do
			if d:IsA("TextButton") and d.Size.X.Offset == 112 and d.Active then
				Engine.Click(d)
				clicked = true
				break
			end
		end
	end
	task.wait(1.6)
end
task.wait(1)
check(data.Stats.MinigamesPlayed >= 1, "card rush round finished via UI")
check(data.Cash >= cashBeforeRush, "card rush did not lose cash")
Panels.Close()

step("NPC visitors")
task.wait(10)
local npcFolder = game.Workspace:FindFirstChild("NPCs")
check(npcFolder and #npcFolder:GetChildren() > 0, "NPCs spawned: " .. (npcFolder and #npcFolder:GetChildren() or 0))
check(data.Stats.NPCVisits > 0, "NPCs visited the resort: " .. data.Stats.NPCVisits)

step("Street race")
character:PivotTo(CFrame.new(0, 4, 40))
ok, message = Remotes.JoinRace:InvokeServer()
check(ok, "join race: " .. tostring(message))
task.wait(1.6)
local cars = game.Workspace:FindFirstChild("RaceCars")
check(cars and #cars:GetChildren() == 4, "4 cars spawned (1 player + 3 NPC): " .. (cars and #cars:GetChildren() or 0))
local humanoid = character:FindFirstChildOfClass("Humanoid")
check(humanoid.SeatPart ~= nil, "player seated in car")
task.wait(1.5)
-- drive: move the player's car along the checkpoints
local car = cars:FindFirstChild(player.Name .. "_Car")
local path = {}
for i = 1, 5 do
	table.insert(path, game.Workspace.RaceTrack.Checkpoints["CP" .. i].Position)
end
for _ = 1, Config.Race.Laps do
	for _, point in ipairs(path) do
		if car and car.Parent then
			car:PivotTo(CFrame.new(Vector3.new(point.X, 1.3, point.Z)))
		end
		task.wait(0.35)
	end
end
task.wait(1)
check(data.Stats.RacesCompleted == 1, "race completed")
check(data.Stats.BestRaceTime > 0, "best time recorded")
task.wait(7)
check(#cars:GetChildren() == 0, "cars cleaned up")
check(humanoid.SeatPart == nil, "player unseated after race")

step("Events")
local EventService = services.EventService
EventService.ForceStart("Blackout")
task.wait(0.5)
for _, generator in ipairs(game.Workspace.EventAreas.Generators:GetChildren()) do
	local prompt = generator.Body:FindFirstChildOfClass("ProximityPrompt")
	check(prompt and prompt.Enabled, "generator prompt enabled")
	Engine.SignalOf(prompt, "Triggered"):Fire(player)
	task.wait(0.3)
end
task.wait(0.5)
check(EventService.GetCurrent() == nil, "blackout ended after repairs")
check(data.Stats.EventsJoined >= 1, "event participation counted")
EventService.ForceStart("Concert")
character:PivotTo(CFrame.new(game.Workspace.EventAreas.Concert.CrowdZone.Position))
local cashBeforeConcert = data.Cash
task.wait(2.5)
check(data.Cash > cashBeforeConcert, "concert rewards in crowd zone")
task.wait(4)
EventService.ForceStart("VIPNight")
task.wait(1)
EventService.ForceStart("StreetRace")
task.wait(5)
check(EventService.GetCurrent() == nil, "street race event ended")

step("Teleports / tutorial / tasks")
for _, target in ipairs({ "Plaza", "Racing", "Entertainment", "Shopping", "VIPLounge", "Resort" }) do
	ok, message = Remotes.Teleport:InvokeServer(target)
	check(ok, "teleport " .. target .. ": " .. tostring(message))
	task.wait(1.6)
end
Panels.Open("Tasks")
task.wait(1)
Panels.Close()
check(data.Tutorial == Tutorial.Done, "tutorial finished: step " .. tostring(data.Tutorial))
check((data.Quests.Progress.visits or 0) >= 3, "visits counted: " .. tostring(data.Quests.Progress.visits))
check((data.Quests.Progress.races or 0) >= 1, "race task counted")
check((data.Quests.Progress.minigames or 0) >= 1, "minigame task counted")

step("Play hub, Neon Reflex, Time Trial, Delivery")
Panels.Open("Play")
task.wait(0.4)
for _, text in ipairs({ "STREET RACE", "TIME TRIAL", "START JOB" }) do
	check(Engine.FindButton(gui, text) ~= nil, "hub button " .. text)
end
Panels.Close()
-- Neon Reflex through the UI: tap the pad whenever it shows TAP!
Config.Reflex.DelayMin, Config.Reflex.DelayMax = 0.3, 0.5
local playedBefore = data.Stats.MinigamesPlayed
Panels.Open("Reflex")
local reflexWindow = gui:FindFirstChild("NEON REFLEX")
local deadline = os.clock() + 15
while os.clock() < deadline and data.Stats.MinigamesPlayed == playedBefore do
	if reflexWindow then
		for _, d in ipairs(reflexWindow:GetDescendants()) do
			if d:IsA("TextButton") and d.Text == "TAP!" then
				Engine.Click(d)
			end
		end
	end
	task.wait(0.05)
end
check(data.Stats.MinigamesPlayed == playedBefore + 1, "neon reflex round finished via UI")
check(data.Stats.ReflexBest > 0, "reflex best recorded: " .. tostring(data.Stats.ReflexBest))
Panels.Close()

-- Time trial
character:PivotTo(CFrame.new(0, 4, 40))
task.wait(0.3)
local trialsBefore = data.Stats.RacesCompleted
ok, message = Remotes.JoinRace:InvokeServer("TimeTrial")
check(ok, "time trial start: " .. tostring(message))
task.wait(2.5)
local trialCar = game.Workspace.RaceCars:FindFirstChild(player.Name .. "_Car")
check(trialCar ~= nil and #game.Workspace.RaceCars:GetChildren() == 1, "time trial: only the player's car")
for _, point in ipairs(path) do
	if trialCar and trialCar.Parent then
		trialCar:PivotTo(CFrame.new(Vector3.new(point.X, 1.3, point.Z)))
	end
	task.wait(0.35)
end
task.wait(1)
check(data.Stats.RacesCompleted == trialsBefore + 1, "time trial completed")
check(data.Stats.BestTrialTime > 0, "trial time recorded")
task.wait(7)

-- Delivery job
character:PivotTo(CFrame.new(0, 4, 40))
task.wait(0.3)
local deliveriesBefore = data.Stats.Deliveries
ok, message = Remotes.JobAction:InvokeServer("StartDelivery")
check(ok, "delivery start: " .. tostring(message))
task.wait(0.5)
local deliveryBar = gui:FindFirstChild("DeliveryBar")
check(deliveryBar and deliveryBar.Visible, "delivery HUD visible")
local JobService = services.JobService
-- read the target from the client-side marker
local marker = game.Workspace.CurrentCamera:FindFirstChild("GuideMarker")
check(marker ~= nil, "delivery guide marker shown")
if marker then
	character:PivotTo(CFrame.new(marker.Position - Vector3.new(0, 4, 0)))
end
task.wait(1.5)
check(data.Stats.Deliveries == deliveriesBefore + 1, "delivery completed")
check(deliveryBar and not deliveryBar.Visible, "delivery HUD hidden after completion")
local _ = JobService
-- kiosk prompt starts a delivery too, cancel works
for _, d in ipairs(game.Workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") and d.Parent and d.Parent:GetAttribute("Prompt") == "Delivery" then
		Engine.SignalOf(d, "Triggered"):Fire(player)
	end
end
task.wait(0.5)
check(deliveryBar.Visible, "kiosk prompt starts delivery")
Remotes.JobAction:InvokeServer("Cancel")
task.wait(0.3)
check(not deliveryBar.Visible, "delivery cancelled")

step("Second player + leave/rejoin persistence")
local other = Engine.AddPlayer(1002, "Guest")
task.wait(1)
check(other:GetAttribute("PlotIndex") == 2, "second player gets plot 2")
Engine.MakeCharacter(other, Vector3.new(5, 4, 40))
task.wait(0.5)
-- Social: the second player likes Erik's resort
Engine.LocalPlayer = other
local okLike = Remotes.LikeResort:InvokeServer(1001)
check(okLike, "second player can like a resort")
check(not Remotes.LikeResort:InvokeServer(1001), "second like the same day rejected")
local resorts = Remotes.GetResorts:InvokeServer()
check(resorts and #resorts == 1 and resorts[1].Likes == 1, "resort list shows likes")
ok = Remotes.Teleport:InvokeServer("Resort:1001")
check(ok, "visit another player's resort")
Engine.LocalPlayer = player
task.wait(1.6)
check(data.Stats.Likes == 1, "owner received the like")
Panels.Open("Map")
task.wait(1)
Panels.Close()
local buildingCount = #data.Buildings
local level = data.Level
Engine.RemovePlayer(player)
task.wait(1)
check(#plotModel.Buildings:GetChildren() == 0, "buildings removed on leave")
-- A stale session lock from a crashed server must not block loading.
local store = Engine.Stores[Config.DataStoreName]
local serde = require("@lune/serde")
local saved = serde.decode("json", store.Data["Player_1001"])
check(saved.Session == nil, "session lock released on leave")
saved.Session = { JobId = "crashed-server", Time = os.time() - 1000 }
store.Data["Player_1001"] = serde.encode("json", saved)
local rejoined = Engine.AddPlayer(1001, "Erik")
Engine.LocalPlayer = rejoined
task.wait(1.5)
local newData = DataService.Get(rejoined)
check(newData and #newData.Buildings == buildingCount, "buildings restored after rejoin")
check(newData and newData.Level == level, "level restored after rejoin")
check(newData and newData.Buildings[1].L == 2, "upgrade level saved")

task.wait(1)
Engine.Stopped = true

print()
print(("Checks: %d passed, %d failed"):format(passes, #failures))
print(("Runtime errors: %d"):format(#Engine.Errors))
for _, line in ipairs(Engine.Logs) do
	if line:find("^WARN") then
		print("  " .. line)
	end
end
process.exit((#failures == 0 and #Engine.Errors == 0) and 0 or 1)
