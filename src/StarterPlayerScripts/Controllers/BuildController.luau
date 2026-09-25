-- BuildController: build menu + placement tools (place, move, rotate, delete, copy, grid snap).
-- PC: mouse to aim, click to place, R rotate, Q/Esc cancel.
-- Mobile: tap the ground to position, big ROTATE / PLACE / CANCEL buttons.
-- The client only previews; the server validates and performs every change.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingModels = require(Shared.BuildingModels)
local Buildings = require(Shared.Buildings)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Placement = require(Shared.Placement)
local PlotUtil = require(Shared.PlotUtil)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local BuildController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ctx, UI, C

local sheet, itemScroll, tabRow, toolbar, toolbarHint
local toolbarButtons = {}
local category = "All"

local mode = "Closed" -- Closed | Menu | Placing | Edit
local placing = nil -- { Id, Rot, Uid?, Ghost, X, Z, Valid, Reason }
local selected = nil -- { Uid, Model, Highlight }
local pointer = nil -- last world point on the plot plane
local busy = false
local deleteArmed = false

local function getPlotModel()
	local data = ctx.State.Data
	if not data or not data.PlotIndex then
		return nil
	end
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. data.PlotIndex)
end

local function screenToPlot(screenPosition)
	local plotModel = getPlotModel()
	if not plotModel then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local planeY = PlotUtil.Origin(plotModel).Position.Y
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function buildingAtScreen(screenPosition)
	local plotModel = getPlotModel()
	local folder = plotModel and plotModel:FindFirstChild("Buildings")
	if not folder then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if not result then
		return nil
	end
	local instance = result.Instance
	while instance and instance.Parent ~= folder do
		instance = instance.Parent
	end
	return instance
end

----------------------------------------------------------------------
-- Toolbar
----------------------------------------------------------------------
local function setToolbar(hint, buttonList)
	toolbarHint.Text = hint
	for _, button in ipairs(toolbarButtons) do
		button:Destroy()
	end
	toolbarButtons = {}
	for index, entry in ipairs(buttonList) do
		local button = UI.Button(entry.Text, entry.Color, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(entry.Width or 150, 60),
			Parent = toolbar.Buttons,
		})
		button.Activated:Connect(entry.Callback)
		table.insert(toolbarButtons, button)
	end
	toolbar.Visible = true
end

local enterMenu, enterEdit, startPlacing, stopPlacing

local function clearSelection()
	if selected then
		if selected.Highlight then
			selected.Highlight:Destroy()
		end
		selected = nil
	end
	deleteArmed = false
end

----------------------------------------------------------------------
-- Placement
----------------------------------------------------------------------
local function refreshGhost()
	if not placing then
		return
	end
	local plotModel = getPlotModel()
	local data = ctx.State.Data
	if not plotModel or not data then
		return
	end
	local def = Buildings.Get(placing.Id)
	local x, z = placing.X, placing.Z
	if pointer then
		local lx, lz = PlotUtil.ToLocal(plotModel, pointer)
		x, z = Placement.Normalize(def, lx, lz, placing.Rot)
	end
	local changed = x ~= placing.X or z ~= placing.Z or placing.Dirty
	placing.X, placing.Z = x, z
	if not changed then
		return
	end
	placing.Dirty = false
	BuildingModels.MoveTo(placing.Ghost, placing.Id, PlotUtil.BuildingCFrame(plotModel, x, z, placing.Rot))
	local valid, reason = Placement.IsValid(def, x, z, placing.Rot, data.Buildings, placing.Uid)
	if valid and not placing.Uid and data.Cash < def.Cost then
		valid, reason = false, "Not enough cash"
	end
	placing.Valid, placing.Reason = valid, reason
	BuildingModels.TintGhost(placing.Ghost, valid)
	toolbarHint.Text = valid and (placing.Uid and "Move: " or "Place: ") .. def.Name .. (placing.Uid and "" or "  " .. Format.Money(def.Cost))
		or ("Can't place here: " .. tostring(reason))
end

local function rotate()
	if placing then
		placing.Rot = (placing.Rot + 1) % 4
		placing.Dirty = true
		refreshGhost()
	end
end

local function confirmPlacement()
	if not placing or busy then
		return
	end
	refreshGhost()
	if not placing.Valid then
		ctx.HUD.Notify(placing.Reason or "Can't place here", "warning")
		return
	end
	busy = true
	local ok, result
	if placing.Uid then
		ok, result = Remotes.Get("MoveBuilding"):InvokeServer(placing.Uid, placing.X, placing.Z, placing.Rot)
	else
		ok, result = Remotes.Get("PlaceBuilding"):InvokeServer(placing.Id, placing.X, placing.Z, placing.Rot)
	end
	busy = false
	if not ok then
		ctx.HUD.Notify(tostring(result), "warning")
		return
	end
	if placing and placing.Uid then
		stopPlacing()
		enterEdit()
	elseif placing then
		-- Keep placing the same item (fast building), unless it is no longer affordable.
		local def = Buildings.Get(placing.Id)
		task.wait(0.3)
		if placing and ctx.State.Data and ctx.State.Data.Cash < def.Cost then
			stopPlacing()
			enterMenu()
		elseif placing then
			placing.Dirty = true
		end
	end
end

function startPlacing(id, uid, rot)
	local plotModel = getPlotModel()
	if not plotModel then
		ctx.HUD.Notify("You don't have a plot yet.", "warning")
		return
	end
	stopPlacing()
	clearSelection()
	mode = "Placing"
	sheet.Visible = false
	local def = Buildings.Get(id)
	local ghost = BuildingModels.Build(id, PlotUtil.BuildingCFrame(plotModel, 0, 0, rot or 0), { Ghost = true })
	ghost.Parent = camera
	placing = { Id = id, Uid = uid, Rot = rot or 0, Ghost = ghost, X = 0, Z = 0, Dirty = true }

	-- Start near the player (or at the plot center).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and PlotUtil.Contains(plotModel, root.Position, 0) then
		pointer = root.Position + root.CFrame.LookVector * 16
	else
		pointer = PlotUtil.Origin(plotModel).Position
	end
	refreshGhost()

	local buttons = {
		{ Text = "ROTATE", Color = C.Cyan, Callback = rotate },
		{ Text = uid and "MOVE HERE" or "PLACE", Color = C.Lime, Callback = confirmPlacement },
		{ Text = "CANCEL", Color = C.Red, Callback = function()
			local wasMove = placing and placing.Uid
			stopPlacing()
			if wasMove then
				enterEdit()
			else
				enterMenu()
			end
		end },
	}
	setToolbar(def.Name, buttons)
	if not UI.IsMobile() then
		toolbarHint.Text = def.Name .. "  |  Click = place   R = rotate   Q = cancel"
	end
end

function stopPlacing()
	if placing then
		placing.Ghost:Destroy()
		placing = nil
	end
end

----------------------------------------------------------------------
-- Edit mode
----------------------------------------------------------------------
local function findEntry(uid)
	local data = ctx.State.Data
	if data then
		for _, entry in ipairs(data.Buildings) do
			if entry.Uid == uid then
				return entry
			end
		end
	end
	return nil
end

local function showEditToolbar()
	if not selected then
		setToolbar(UI.IsMobile() and "Tap one of your buildings" or "Click one of your buildings", {
			{ Text = "BACK", Color = C.Cyan, Callback = function()
				enterMenu()
			end },
		})
		return
	end
	local entry = findEntry(selected.Uid)
	if not entry then
		clearSelection()
		showEditToolbar()
		return
	end
	local def = Buildings.Get(entry.Id)
	local refund = math.floor(def.Cost * Config.SellRefund)
	setToolbar(def.Name, {
		{ Text = "MOVE", Color = C.Cyan, Callback = function()
			startPlacing(entry.Id, entry.Uid, entry.R)
		end },
		{ Text = "COPY", Color = C.Gold, Callback = function()
			startPlacing(entry.Id, nil, entry.R)
		end },
		{ Text = deleteArmed and "CONFIRM?" or ("DELETE +" .. Format.ShortMoney(refund)), Color = C.Red, Width = 190, Callback = function()
			if not deleteArmed then
				deleteArmed = true
				showEditToolbar()
				return
			end
			if busy then
				return
			end
			busy = true
			local ok, result = Remotes.Get("DeleteBuilding"):InvokeServer(entry.Uid)
			busy = false
			if not ok then
				ctx.HUD.Notify(tostring(result), "warning")
			end
			clearSelection()
			showEditToolbar()
		end },
		{ Text = "DONE", Color = C.Lime, Callback = function()
			clearSelection()
			showEditToolbar()
		end },
	})
end

local function selectBuilding(model)
	clearSelection()
	local uid = model:GetAttribute("Uid")
	if not uid then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillColor = C.Cyan
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = C.Cyan
	highlight.Parent = camera
	selected = { Uid = uid, Model = model, Highlight = highlight }
	showEditToolbar()
end

function enterEdit()
	stopPlacing()
	clearSelection()
	mode = "Edit"
	sheet.Visible = false
	showEditToolbar()
end

----------------------------------------------------------------------
-- Menu
----------------------------------------------------------------------
local function renderItems()
	UI.Clear(itemScroll)
	local data = ctx.State.Data
	if not data then
		return
	end
	local order = 0
	for _, def in ipairs(Buildings.List) do
		if category == "All" or def.Category == category then
			order += 1
			local allowed, reason = Progression.CanUseBuilding(def, data.Level, data.Prestige, data.Passes)
			local affordable = data.Cash >= def.Cost
			local accent = allowed and (affordable and C.Lime or C.Orange) or C.Disabled
			local card = UI.New("TextButton", {
				Text = "",
				AutoButtonColor = allowed,
				LayoutOrder = order,
				Size = UDim2.fromOffset(170, 150),
				BackgroundColor3 = C.Panel,
				Parent = itemScroll,
			}, { UI.Corner(12), UI.Stroke(accent, 2) })
			UI.Label(def.Name, {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 26),
				Font = Enum.Font.GothamBlack,
				TextColor3 = allowed and C.Text or C.SubText,
				MaxTextSize = 20,
				Parent = card,
			})
			UI.Label(def.Cost > 0 and Format.Money(def.Cost) or "FREE", {
				Position = UDim2.fromOffset(8, 36),
				Size = UDim2.new(1, -16, 0, 24),
				Font = Enum.Font.GothamBlack,
				TextColor3 = affordable and C.Gold or C.Orange,
				MaxTextSize = 22,
				Parent = card,
			})
			UI.Label(allowed and def.Description or reason, {
				Position = UDim2.fromOffset(8, 64),
				Size = UDim2.new(1, -16, 0, 50),
				Font = Enum.Font.GothamMedium,
				TextColor3 = allowed and C.SubText or C.Red,
				TextYAlignment = Enum.TextYAlignment.Top,
				MaxTextSize = 14,
				Parent = card,
			})
			local income = def.Spend > 0 and ("~" .. Format.ShortMoney(def.Spend) .. "/visit") or ("+" .. def.Rating .. " rating")
			UI.Label(income .. "  " .. def.Size[1] .. "x" .. def.Size[2], {
				Position = UDim2.new(0, 8, 1, -30),
				Size = UDim2.new(1, -16, 0, 22),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.Cyan,
				MaxTextSize = 14,
				Parent = card,
			})
			card.Activated:Connect(function()
				if not allowed then
					ctx.HUD.Notify(reason, "warning")
				elseif not affordable then
					ctx.HUD.Notify("Not enough cash for " .. def.Name .. " (" .. Format.Money(def.Cost) .. ")", "warning")
				else
					startPlacing(def.Id, nil, 0)
				end
			end)
		end
	end
end

local function renderTabs()
	UI.Clear(tabRow)
	local categories = { "All" }
	for _, name in ipairs(Buildings.Categories) do
		table.insert(categories, name)
	end
	for index, name in ipairs(categories) do
		local button = UI.Button(string.upper(name), name == category and C.Gold or C.Cyan, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(name == "All" and 70 or 128, 38),
			Parent = tabRow,
		})
		button.Activated:Connect(function()
			category = name
			renderTabs()
			renderItems()
		end)
	end
end

function enterMenu()
	stopPlacing()
	clearSelection()
	mode = "Menu"
	toolbar.Visible = false
	sheet.Visible = true
	renderTabs()
	renderItems()
end

local function open()
	ctx.HUD.SetMainButtonsVisible(false)
	-- Bring the player to their plot if they are far away.
	local plotModel = getPlotModel()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if plotModel and root and (root.Position - PlotUtil.Origin(plotModel).Position).Magnitude > 140 then
		task.spawn(function()
			Remotes.Get("Teleport"):InvokeServer("Resort")
		end)
	end
	enterMenu()
end

local function close()
	stopPlacing()
	clearSelection()
	mode = "Closed"
	sheet.Visible = false
	toolbar.Visible = false
	ctx.HUD.SetMainButtonsVisible(true)
end

----------------------------------------------------------------------
-- Start
----------------------------------------------------------------------
function BuildController.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	sheet = UI.New("Frame", {
		Name = "BuildSheet",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(1000, 250),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = ctx.Gui,
	}, { UI.Corner(16), UI.Stroke(C.Gold, 3) })

	tabRow = UI.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -250, 0, 46),
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = sheet,
	})
	UI.List(Enum.FillDirection.Horizontal, 6).Parent = tabRow

	local edit = UI.Button("EDIT", C.Cyan, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -120, 0, 10),
		Size = UDim2.fromOffset(100, 40),
		Parent = sheet,
	})
	edit.Activated:Connect(enterEdit)
	local closeButton = UI.Button("CLOSE", C.Red, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(100, 40),
		Parent = sheet,
	})
	closeButton.Activated:Connect(function()
		ctx.Panels.Close()
	end)

	itemScroll = UI.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(1, -24, 1, -74),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Gold,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = sheet,
	})
	UI.List(Enum.FillDirection.Horizontal, 10).Parent = itemScroll

	toolbar = UI.New("Frame", {
		Name = "BuildToolbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(760, 118),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = ctx.Gui,
	}, { UI.Corner(16), UI.Stroke(C.Gold, 3) })
	toolbarHint = UI.Label("", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 30),
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Gold,
		MaxTextSize = 20,
		Parent = toolbar,
	})
	UI.New("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 0, 62),
		Parent = toolbar,
	}, { UI.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })

	ctx.Panels.Register("Build", { Open = open, Close = close })

	local lastSignature = nil
	ctx.State.Changed:Connect(function(data)
		if mode == "Menu" then
			-- Only rebuild the cards when affordability or unlocks changed (keeps scroll position).
			local affordable = {}
			for _, def in ipairs(Buildings.List) do
				affordable[#affordable + 1] = data.Cash >= def.Cost
			end
			local signature = HttpService:JSONEncode({ data.Level, data.Prestige, data.Passes or {}, affordable })
			if signature ~= lastSignature then
				lastSignature = signature
				renderItems()
			end
		elseif mode == "Edit" then
			showEditToolbar()
		elseif mode == "Placing" and placing then
			placing.Dirty = true
		end
	end)

	-- Input -----------------------------------------------------------
	UserInputService.InputBegan:Connect(function(input, processed)
		if mode == "Placing" then
			if input.KeyCode == Enum.KeyCode.R and not processed then
				rotate()
			elseif (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape) and not processed then
				local wasMove = placing and placing.Uid
				stopPlacing()
				if wasMove then
					enterEdit()
				else
					enterMenu()
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
				confirmPlacement()
			end
		elseif mode == "Edit" and input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			local model = buildingAtScreen(UserInputService:GetMouseLocation())
			if model then
				selectBuilding(model)
			end
		end
	end)

	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if processed then
			return
		end
		if mode == "Placing" then
			pointer = screenToPlot(position)
			refreshGhost()
		elseif mode == "Edit" then
			local model = buildingAtScreen(position)
			if model then
				selectBuilding(model)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if mode ~= "Placing" or not placing then
			return
		end
		if UserInputService.MouseEnabled and not UI.IsMobile() then
			-- GetMouseLocation is in viewport space, matching ViewportPointToRay.
			pointer = screenToPlot(UserInputService:GetMouseLocation()) or pointer
		end
		refreshGhost()
	end)
end

return BuildController
