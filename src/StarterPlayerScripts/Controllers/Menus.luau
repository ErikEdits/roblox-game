-- Menus: Tasks (daily tasks, stats, prestige), Map (teleports) and Settings panels,
-- plus the local effects of settings (low graphics, NPC labels) and the VIP lounge door.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local Menus = {}

local ctx, UI, C

----------------------------------------------------------------------
-- Tasks
----------------------------------------------------------------------
local tasksWindow, tasksBody

local function renderTasks()
	if not tasksWindow.Visible then
		return
	end
	UI.Clear(tasksBody)
	local data = ctx.State.Data
	if not data then
		return
	end
	local scroll = UI.Scroll({ Parent = tasksBody })
	UI.List(nil, 8).Parent = scroll

	UI.Label(("DAILY TASKS  -  new tasks in %s"):format(Format.Time(data.QuestResetIn or 0)), {
		LayoutOrder = 0,
		Size = UDim2.new(1, -12, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Lime,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = scroll,
	})
	for index, def in ipairs(Config.DailyTasks) do
		local progress = data.Quests.Progress[def.Id] or 0
		local claimed = data.Quests.Claimed[def.Id] == true
		local done = progress >= def.Goal
		local row = UI.New("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -12, 0, 70),
			BackgroundColor3 = C.Panel,
			Parent = scroll,
		}, { UI.Corner(10), UI.Stroke(claimed and C.Disabled or (done and C.Lime or C.PanelLight), 2) })
		UI.Label((claimed and "[x] " or "[ ] ") .. def.Text, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -220, 0, 26),
			Font = Enum.Font.GothamBold,
			TextColor3 = claimed and C.SubText or C.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 20,
			Parent = row,
		})
		local _, set = UI.Bar(C.Lime, {
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.new(1, -220, 0, 18),
			Parent = row,
		})
		local goalText = def.Id == "earn" and (Format.ShortMoney(progress) .. " / " .. Format.ShortMoney(def.Goal)) or (progress .. " / " .. def.Goal)
		set(progress / def.Goal, goalText)
		local button = UI.Button(claimed and "CLAIMED" or ("+" .. Format.ShortMoney(def.Cash) .. " +" .. def.XP .. "XP"), done and not claimed and C.Lime or C.Disabled, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(190, 52),
			Parent = row,
		})
		UI.SetButtonEnabled(button, done and not claimed, C.Lime)
		button.Activated:Connect(function()
			if done and not claimed then
				local ok, message = Remotes.Get("ClaimTask"):InvokeServer(def.Id)
				if not ok and message then
					ctx.HUD.Notify(tostring(message), "warning")
				end
			end
		end)
	end

	-- Statistics
	local stats = data.Stats
	UI.Label("STATISTICS", {
		LayoutOrder = 20,
		Size = UDim2.new(1, -12, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Cyan,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = scroll,
	})
	local lines = {
		("Total earned: %s"):format(Format.Money(stats.TotalEarned)),
		("NPC visits to your resort: %d"):format(stats.NPCVisits),
		("Races completed: %d   Won: %d   Best: %s"):format(stats.RacesCompleted, stats.RacesWon, stats.BestRaceTime > 0 and Format.RaceTime(stats.BestRaceTime) or "-"),
		("Card Rush rounds: %d   Best: %d / %d"):format(stats.MinigamesPlayed, stats.CardRushBest, Config.CardRush.Questions),
		("Events joined: %d   Play time: %d min"):format(stats.EventsJoined, math.floor(stats.PlayTime / 60)),
	}
	UI.Label(table.concat(lines, "\n"), {
		LayoutOrder = 21,
		Size = UDim2.new(1, -12, 0, 130),
		Font = Enum.Font.GothamMedium,
		TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 18,
		Parent = scroll,
	})

	-- Prestige
	local canPrestige = data.Level >= Config.Prestige.RequiredLevel
	local nextBonus = math.floor((Progression.PrestigeIncomeMultiplier(data.Prestige + 1) - 1) * 100 + 0.5)
	local prestigeRow = UI.New("Frame", {
		LayoutOrder = 30,
		Size = UDim2.new(1, -12, 0, 96),
		BackgroundColor3 = C.Panel,
		Parent = scroll,
	}, { UI.Corner(10), UI.Stroke(C.Gold, 2) })
	UI.Label(("PRESTIGE %d   (%s)"):format(data.Prestige, Progression.PrestigeTitle(data.Prestige) or "no title yet"), {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -240, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = prestigeRow,
	})
	UI.Label(("Optional. At level %d: reset level & cash, KEEP buildings, get +%d%% resort income forever and a new title."):format(Config.Prestige.RequiredLevel, nextBonus), {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -240, 0, 48),
		Font = Enum.Font.GothamMedium,
		TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 16,
		Parent = prestigeRow,
	})
	local armed = false
	local prestigeButton = UI.Button(canPrestige and "PRESTIGE" or ("LEVEL " .. Config.Prestige.RequiredLevel), C.Gold, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(200, 56),
		Parent = prestigeRow,
	})
	UI.SetButtonEnabled(prestigeButton, canPrestige, C.Gold)
	prestigeButton.Activated:Connect(function()
		if not canPrestige then
			return
		end
		if not armed then
			armed = true
			prestigeButton.Text = "SURE? TAP AGAIN"
			return
		end
		local ok, message = Remotes.Get("Prestige"):InvokeServer()
		if not ok and message then
			ctx.HUD.Notify(tostring(message), "warning")
		end
	end)
end

----------------------------------------------------------------------
-- Map
----------------------------------------------------------------------
local function buildMap()
	local window, content, close = UI.Window(ctx.Gui, "CITY MAP", C.Violet, UDim2.fromOffset(800, 600))
	close.Activated:Connect(function()
		ctx.Panels.Close()
	end)
	local grid = UI.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 262),
		Parent = content,
	})
	UI.New("UIGridLayout", {
		CellSize = UDim2.new(0.25, -8, 0, 60),
		CellPadding = UDim2.fromOffset(10, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local destinations = {
		{ "Resort", "MY RESORT", C.Gold },
		{ "Plaza", "MAIN PLAZA", C.Cyan },
		{ "Racing", "RACING", C.Red },
		{ "Entertainment", "ARCADE & STAGE", C.Magenta },
		{ "Shopping", "SHOPPING", C.Lime },
		{ "VIPLounge", "VIP LOUNGE", C.Violet },
		{ "Beach", "NEON BEACH", C.Cyan },
	}
	local function teleport(target)
		ctx.Panels.Close()
		local ok, message = Remotes.Get("Teleport"):InvokeServer(target)
		if not ok and message then
			ctx.HUD.Notify(tostring(message), "warning")
		end
	end
	for index, entry in ipairs(destinations) do
		local button = UI.Button(entry[2], entry[3], { LayoutOrder = index, Parent = grid })
		button.Activated:Connect(function()
			teleport(entry[1])
		end)
	end

	UI.Label("PLAYER RESORTS", {
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.new(1, 0, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Violet,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = content,
	})
	local list = UI.Scroll({
		Position = UDim2.fromOffset(0, 302),
		Size = UDim2.new(1, 0, 1, -302),
		Parent = content,
	})
	UI.List(nil, 6).Parent = list

	local function renderResorts()
		UI.Clear(list)
		local resorts = Remotes.Get("GetResorts"):InvokeServer() or {}
		if #resorts == 0 then
			UI.Label("No other players yet - NPC visitors keep the city busy!", {
				Size = UDim2.new(1, -12, 0, 30),
				TextColor3 = C.SubText,
				MaxTextSize = 18,
				Parent = list,
			})
			return
		end
		for index, resort in ipairs(resorts) do
			local row = UI.New("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1, -12, 0, 56),
				BackgroundColor3 = C.Panel,
				Parent = list,
			}, { UI.Corner(10) })
			UI.Label(("%s's Resort  -  %s  |  %d buildings  |  %d likes"):format(
				resort.Name, string.rep("*", resort.ResortLevel), resort.Buildings, resort.Likes), {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -290, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 18,
				Parent = row,
			})
			local visit = UI.Button("VISIT", C.Cyan, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -144, 0.5, 0),
				Size = UDim2.fromOffset(120, 42),
				Parent = row,
			})
			visit.Activated:Connect(function()
				teleport("Resort:" .. resort.UserId)
			end)
			local likeButton = UI.Button(resort.LikedToday and "LIKED" or "LIKE", C.Magenta, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(120, 42),
				Parent = row,
			})
			UI.SetButtonEnabled(likeButton, not resort.LikedToday, C.Magenta)
			likeButton.Activated:Connect(function()
				if resort.LikedToday then
					return
				end
				local ok, message = Remotes.Get("LikeResort"):InvokeServer(resort.UserId)
				if not ok and message then
					ctx.HUD.Notify(tostring(message), "warning")
				end
				renderResorts()
			end)
		end
	end

	ctx.Panels.Register("Map", {
		Open = function()
			window.Visible = true
			task.spawn(renderResorts)
		end,
		Close = function()
			window.Visible = false
		end,
	})
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local settingsWindow, settingsBody
local SETTING_TEXT = {
	{ "LowGraphics", "Low graphics", "Turns off bloom, shadows and haze for more FPS." },
	{ "ShowNPCLabels", "NPC labels", "Show visitor type above NPC heads." },
	{ "Notifications", "Reward pop-ups", "Show small reward messages." },
	{ "SoundEffects", "Sound effects", "Button clicks and reward sounds." },
}

local function renderSettings()
	if not settingsWindow.Visible then
		return
	end
	UI.Clear(settingsBody)
	local data = ctx.State.Data
	if not data then
		return
	end
	UI.List(nil, 10).Parent = settingsBody
	for index, entry in ipairs(SETTING_TEXT) do
		local key = entry[1]
		local value = data.Settings[key]
		local row = UI.New("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = C.Panel,
			Parent = settingsBody,
		}, { UI.Corner(10) })
		UI.Label(entry[2], {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -200, 0, 28),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = row,
		})
		UI.Label(entry[3], {
			Position = UDim2.fromOffset(12, 36),
			Size = UDim2.new(1, -200, 0, 24),
			TextColor3 = C.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			Parent = row,
		})
		local button = UI.Button(value and "ON" or "OFF", value and C.Lime or C.Red, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 50),
			Parent = row,
		})
		button.Activated:Connect(function()
			Remotes.Get("SetSetting"):InvokeServer(key, not value)
		end)
	end
	UI.Label(("NEON CITY v%s  |  Progress saving: %s"):format(Config.Version, data.Saving and "ON" or "OFF (Studio)"), {
		LayoutOrder = 99,
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = C.SubText,
		MaxTextSize = 16,
		Parent = settingsBody,
	})
end

local defaultLighting = nil
local function applySettings(data)
	if not data then
		return
	end
	local low = data.Settings.LowGraphics
	if not defaultLighting then
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		defaultLighting = { Shadows = Lighting.GlobalShadows, Density = atmosphere and atmosphere.Density or 0 }
	end
	Lighting.GlobalShadows = not low and defaultLighting.Shadows
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("PostEffect") then
			effect.Enabled = not low
		elseif effect:IsA("Atmosphere") then
			effect.Density = low and 0 or defaultLighting.Density
		end
	end

	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		for _, descendant in ipairs(npcs:GetDescendants()) do
			if descendant:IsA("BillboardGui") and descendant.Name == "NPCLabel" then
				descendant.Enabled = data.Settings.ShowNPCLabels
			end
		end
	end

	-- VIP lounge door opens (locally) for VIP pass owners.
	local isVIP = data.Passes and data.Passes.VIP
	local city = workspace:FindFirstChild("City")
	local lounge = city and city:FindFirstChild("Shopping") and city.Shopping:FindFirstChild("VIPLounge")
	local door = lounge and lounge:FindFirstChild("VIPDoor")
	if door then
		door.CanCollide = not isVIP
		door.Transparency = isVIP and 0.75 or 0.3
	end
end

function Menus.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	local close
	tasksWindow, tasksBody, close = UI.Window(ctx.Gui, "TASKS & PROGRESS", C.Lime, UDim2.fromOffset(820, 540))
	close.Activated:Connect(function()
		ctx.Panels.Close()
	end)
	ctx.Panels.Register("Tasks", {
		Open = function()
			tasksWindow.Visible = true
			renderTasks()
		end,
		Close = function()
			tasksWindow.Visible = false
		end,
	})

	buildMap()

	local closeSettings
	settingsWindow, settingsBody, closeSettings = UI.Window(ctx.Gui, "SETTINGS", C.SubText, UDim2.fromOffset(680, 500))
	closeSettings.Activated:Connect(function()
		ctx.Panels.Close()
	end)
	ctx.Panels.Register("Settings", {
		Open = function()
			settingsWindow.Visible = true
			renderSettings()
		end,
		Close = function()
			settingsWindow.Visible = false
		end,
	})

	ctx.State.Changed:Connect(function(data)
		renderTasks()
		renderSettings()
		applySettings(data)
	end)
	applySettings(ctx.State.Data)

	-- New NPCs respect the label setting.
	task.spawn(function()
		local npcs = workspace:WaitForChild("NPCs", 30)
		if npcs then
			npcs.DescendantAdded:Connect(function(descendant)
				local data = ctx.State.Data
				if descendant:IsA("BillboardGui") and descendant.Name == "NPCLabel" and data then
					descendant.Enabled = data.Settings.ShowNPCLabels
				end
			end)
		end
	end)
end

return Menus
