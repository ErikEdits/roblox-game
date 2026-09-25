-- HUD: cash/level, main buttons, notifications, event banner, city stats, next goal hint.
-- Always answers the question "What can I do next?".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared.Buildings)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local HUD = {}

local player = Players.LocalPlayer
local ctx
local UI
local C

local mainBar
local mainButtons = {}
local goalFrame
local toastHolder
local toasts = {}
local popupCount = 0

local KIND_COLORS

----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------
function HUD.Notify(text, kind)
	kind = kind or "info"
	local settings = ctx.State.Data and ctx.State.Data.Settings
	if settings and settings.Notifications == false and (kind == "reward" or kind == "info") then
		return
	end
	local color = KIND_COLORS[kind] or C.Cyan
	local toast = UI.New("Frame", {
		Size = UDim2.fromOffset(520, 44),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Parent = toastHolder,
	}, {
		UI.Corner(10),
		UI.Stroke(color, 2),
		UI.Label(text, {
			Size = UDim2.new(1, -20, 1, -8),
			Position = UDim2.fromOffset(10, 4),
			TextColor3 = color,
			MaxTextSize = 22,
		}),
	})
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
	if kind == "reward" or kind == "quest" then
		UI.PlaySound("Reward")
	elseif kind == "levelup" then
		UI.PlaySound("LevelUp")
	elseif kind == "error" or kind == "warning" then
		UI.PlaySound("Error")
	end
	table.insert(toasts, toast)
	while #toasts > 4 do
		table.remove(toasts, 1):Destroy()
	end
	task.delay(kind == "levelup" and 6 or 4, function()
		local index = table.find(toasts, toast)
		if index then
			table.remove(toasts, index)
		end
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

local function moneyPopup(position, text, color)
	if popupCount > 14 or typeof(position) ~= "Vector3" then
		return
	end
	popupCount += 1
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = workspace.CurrentCamera
	local gui = UI.New("BillboardGui", {
		Size = UDim2.fromOffset(160, 40),
		AlwaysOnTop = true,
		MaxDistance = 250,
		LightInfluence = 0,
		Parent = anchor,
	})
	local label = UI.Label(text, {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextColor3 = typeof(color) == "Color3" and color or C.Gold,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 32,
		Parent = gui,
	})
	TweenService:Create(gui, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		anchor:Destroy()
		popupCount -= 1
	end)
end

----------------------------------------------------------------------
-- Next goal hint
----------------------------------------------------------------------
local function computeGoal(data)
	if not data then
		return "Loading your resort..."
	end
	local event = ctx.State.Event
	if event and event.Id then
		return "EVENT: " .. event.Name .. " - " .. (event.Hint or "")
	end
	for _, def in ipairs(data.DailyTasks or {}) do
		if (data.Quests.Progress[def.Id] or 0) >= def.Goal and not data.Quests.Claimed[def.Id] then
			return "A daily task is complete! Claim it in TASKS."
		end
	end
	if #data.Buildings == 0 then
		return "Open BUILD and place a Reception Kiosk on your plot."
	end
	if #data.Buildings < 3 then
		return "Add a Snack Bar or Neon Motel - NPC visitors will spend money there."
	end
	if data.Level >= Config.Prestige.RequiredLevel then
		return "You can PRESTIGE in TASKS for a permanent income bonus!"
	end
	-- Suggest the best building the player can afford right now.
	local best = nil
	for _, def in ipairs(Buildings.List) do
		local allowed = Progression.CanUseBuilding(def, data.Level, data.Prestige, data.Passes)
		if allowed and def.Cost > 0 and def.Cost <= data.Cash and def.Spend > 0 then
			if not best or def.Cost > best.Cost then
				best = def
			end
		end
	end
	if best and best.Cost >= 1000 then
		return ("You can afford a %s (%s). Build it!"):format(best.Name, Format.Money(best.Cost))
	end
	for _, def in ipairs(Buildings.List) do
		if def.Level > data.Level and not def.Pass and not def.Prestige then
			return ("Earn XP to reach level %d and unlock the %s. Try a Street Race or Card Rush!"):format(def.Level, def.Name)
		end
	end
	return "Play Card Rush or join a Street Race to earn more cash."
end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------
function HUD.GetMainButton(name)
	return mainButtons[name]
end

function HUD.SetGoalVisible(visible)
	if goalFrame then
		goalFrame.Visible = visible
	end
end

function HUD.SetMainButtonsVisible(visible)
	if mainBar then
		mainBar.Visible = visible
	end
end

function HUD.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors
	KIND_COLORS = {
		info = C.Cyan,
		reward = C.Gold,
		levelup = C.Magenta,
		quest = C.Lime,
		event = C.Violet,
		race = C.Red,
		warning = C.Orange,
		error = C.Red,
	}
	local gui = ctx.Gui

	-- Top-left: cash, level, zone -------------------------------------
	local info = UI.New("Frame", {
		Name = "Info",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(300, 150),
		Parent = gui,
	}, { UI.List(nil, 6) })

	local cashFrame = UI.New("Frame", {
		Size = UDim2.fromOffset(300, 58),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = 1,
		Parent = info,
	}, { UI.Corner(12), UI.Stroke(C.Gold, 2) })
	local cashLabel = UI.Label("$0", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 1, -12),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 38,
		Parent = cashFrame,
	})

	local levelFrame = UI.New("Frame", {
		Size = UDim2.fromOffset(300, 50),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = 2,
		Parent = info,
	}, { UI.Corner(12), UI.Stroke(C.Magenta, 2) })
	local levelLabel = UI.Label("LV 1", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(90, 38),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Magenta,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 28,
		Parent = levelFrame,
	})
	local xpBar, setXP = UI.Bar(C.Magenta, {
		Position = UDim2.fromOffset(104, 15),
		Size = UDim2.new(1, -116, 0, 20),
		Parent = levelFrame,
	})
	local _ = xpBar

	local zoneLabel = UI.Label("Neon City", {
		Size = UDim2.fromOffset(300, 24),
		TextColor3 = C.Cyan,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5,
		MaxTextSize = 20,
		LayoutOrder = 3,
		Parent = info,
	})

	-- Next goal -----------------------------------------------------------
	goalFrame = UI.New("Frame", {
		Name = "NextGoal",
		Position = UDim2.new(0, 14, 0, 176),
		Size = UDim2.fromOffset(300, 86),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, { UI.Corner(12), UI.Stroke(C.Lime, 2, 0.3) })
	UI.Label("NEXT GOAL", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Lime,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = goalFrame,
	})
	local goalLabel = UI.Label("", {
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 1, -32),
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 18,
		Parent = goalFrame,
	})

	-- City stats (top-right) --------------------------------------------
	local city = UI.New("Frame", {
		Name = "City",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(230, 124),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, { UI.Corner(12), UI.Stroke(C.Cyan, 2, 0.3), UI.Padding(8), UI.List(nil, 4) })
	local citySetters = {}
	for index, stat in ipairs({ { "Power", C.Gold }, { "Tourism", C.Cyan }, { "Security", C.Lime }, { "Popularity", C.Magenta } }) do
		local row = UI.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = index, Parent = city })
		UI.Label(stat[1], {
			Size = UDim2.new(0.42, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = stat[2],
			MaxTextSize = 16,
			Parent = row,
		})
		local _, set = UI.Bar(stat[2], { Position = UDim2.fromScale(0.44, 0.1), Size = UDim2.fromScale(0.56, 0.8), Parent = row })
		citySetters[stat[1]] = set
	end
	local function updateCity(stats)
		for name, set in pairs(citySetters) do
			local value = stats[name] or 0
			set(value / 100, value .. "%")
		end
	end
	updateCity(ctx.State.City)
	ctx.State.CityChanged:Connect(updateCity)
	if UI.IsMobile() then
		city.Visible = false -- keep phones uncluttered; stats are on the plaza board
	end

	-- Event banner (top-center) -----------------------------------------
	local banner = UI.New("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(520, 74),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { UI.Corner(14), UI.Stroke(C.Violet, 3) })
	local bannerTitle = UI.Label("", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Violet,
		MaxTextSize = 28,
		Parent = banner,
	})
	local bannerHint = UI.Label("", {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 28),
		Font = Enum.Font.GothamMedium,
		MaxTextSize = 18,
		Parent = banner,
	})
	local nextPill = UI.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(240, 30),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
	}, { UI.Corner(15), UI.Stroke(C.Violet, 1, 0.4) })
	local nextLabel = UI.Label("", {
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		TextColor3 = C.SubText,
		MaxTextSize = 16,
		Parent = nextPill,
	})

	toastHolder = UI.New("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(520, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.List(nil, 6, Enum.HorizontalAlignment.Center) })

	-- Main buttons ---------------------------------------------------
	local mobile = UI.IsMobile()
	local buttons = {
		{ "Build", "BUILD", C.Gold },
		{ "Shop", "SHOP", C.Cyan },
		{ "Play", "PLAY", C.Magenta },
		{ "Tasks", "TASKS", C.Lime },
		{ "Map", "MAP", C.Violet },
		{ "Settings", "SETTINGS", C.SubText },
	}
	if mobile then
		mainBar = UI.New("Frame", {
			Name = "MainButtons",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.42, 0),
			Size = UDim2.fromOffset(236, 296),
			BackgroundTransparency = 1,
			Parent = gui,
		}, {
			UI.New("UIGridLayout", {
				CellSize = UDim2.fromOffset(112, 92),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	else
		mainBar = UI.New("Frame", {
			Name = "MainButtons",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.fromOffset(6 * 112 + 5 * 10, 84),
			BackgroundTransparency = 1,
			Parent = gui,
		}, { UI.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	end
	for index, entry in ipairs(buttons) do
		local button = UI.Button(entry[2], entry[3], {
			Name = entry[1],
			LayoutOrder = index,
			Size = UDim2.fromOffset(112, 84),
			Parent = mainBar,
		})
		button.Activated:Connect(function()
			ctx.Panels.Toggle(entry[1])
		end)
		mainButtons[entry[1]] = button
	end

	-- Level-up celebration ---------------------------------------------
	local celebration = UI.Label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(700, 120),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Magenta,
		TextStrokeTransparency = 0.2,
		MaxTextSize = 90,
		Visible = false,
		Parent = gui,
	})
	local function celebrate(text)
		celebration.Text = text
		celebration.Visible = true
		celebration.TextTransparency = 0
		UI.Pop(celebration)
		task.delay(2.2, function()
			TweenService:Create(celebration, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.55)
			celebration.Visible = false
			celebration.TextStrokeTransparency = 0.2
		end)
	end

	-- Rolling cash counter.
	local shownCash = nil
	local cashToken = nil
	local function animateCash(target)
		if not shownCash then
			shownCash = target
			cashLabel.Text = Format.Money(target)
			return
		end
		local from = shownCash
		local token = {}
		cashToken = token
		task.spawn(function()
			local started = os.clock()
			while cashToken == token do
				local t = math.min(1, (os.clock() - started) / 0.45)
				shownCash = from + (target - from) * t
				cashLabel.Text = Format.Money(shownCash)
				if t >= 1 then
					break
				end
				task.wait(0.03)
			end
		end)
	end

	-- Updates -------------------------------------------------------------
	local lastLevel = nil
	local function refresh(data)
		if not data then
			return
		end
		UI.SoundsEnabled = data.Settings.SoundEffects ~= false
		animateCash(data.Cash)
		if lastLevel and data.Level > lastLevel then
			celebrate("LEVEL " .. data.Level .. "!")
		end
		lastLevel = data.Level
		local prestige = data.Prestige > 0 and (" P" .. data.Prestige) or ""
		levelLabel.Text = "LV " .. data.Level .. prestige
		if data.Level >= Config.MaxLevel then
			setXP(1, "MAX LEVEL")
		else
			setXP(data.XP / data.XPNeeded, ("%d / %d XP"):format(data.XP, data.XPNeeded))
		end
		goalLabel.Text = computeGoal(data)
	end
	ctx.State.Changed:Connect(refresh)
	refresh(ctx.State.Data)

	player:GetAttributeChangedSignal("Zone"):Connect(function()
		zoneLabel.Text = player:GetAttribute("Zone") or "Neon City"
	end)

	task.spawn(function()
		while true do
			local event = ctx.State.Event
			local now = workspace:GetServerTimeNow()
			if event and event.Id then
				banner.Visible = true
				nextPill.Visible = false
				bannerTitle.Text = string.upper(event.Name) .. "  " .. Format.Time((event.EndsAt or now) - now)
				bannerHint.Text = event.Description or event.Hint or ""
			else
				banner.Visible = false
				nextPill.Visible = event ~= nil and event.NextAt ~= nil and event.NextAt > now
				if nextPill.Visible then
					nextLabel.Text = "Next city event in " .. Format.Time(event.NextAt - now)
				end
			end
			task.wait(0.5)
		end
	end)
	ctx.State.EventChanged:Connect(function()
		goalLabel.Text = computeGoal(ctx.State.Data)
	end)

	Remotes.Get("Notify").OnClientEvent:Connect(HUD.Notify)
	Remotes.Get("MoneyPopup").OnClientEvent:Connect(moneyPopup)
end

return HUD
