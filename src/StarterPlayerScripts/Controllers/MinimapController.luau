-- MinimapController: small top-down city map (PC only, bottom-right) drawn from the actual map
-- parts, with the player's position/heading, other players and the current guide target.

local Players = game:GetService("Players")

local Guide = require(script.Parent.Guide)

local MinimapController = {}

local player = Players.LocalPlayer
local ctx, UI, C

local BOUNDS = { MinX = -480, MaxX = 620, MinZ = -960, MaxZ = 640 }
local WIDTH = 170
local HEIGHT = math.floor(WIDTH * (BOUNDS.MaxZ - BOUNDS.MinZ) / (BOUNDS.MaxX - BOUNDS.MinX))

local function toMap(x, z)
	return (x - BOUNDS.MinX) / (BOUNDS.MaxX - BOUNDS.MinX), (z - BOUNDS.MinZ) / (BOUNDS.MaxZ - BOUNDS.MinZ)
end

local function drawRect(parent, part, color, transparency, zindex)
	local size = part.Size
	local position = part.Position
	-- Parts on the map are axis aligned (yaw 0/90); swap extents for 90 degree turns.
	local look = part.CFrame.LookVector
	local sx, sz = size.X, size.Z
	if math.abs(look.X) > 0.7 then
		sx, sz = sz, sx
	end
	local u, v = toMap(position.X - sx / 2, position.Z - sz / 2)
	local w = sx / (BOUNDS.MaxX - BOUNDS.MinX)
	local h = sz / (BOUNDS.MaxZ - BOUNDS.MinZ)
	return UI.New("Frame", {
		Position = UDim2.fromScale(u, v),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = zindex or 2,
		Parent = parent,
	})
end

function MinimapController.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors
	if UI.IsMobile() then
		return -- phones keep the screen free; the MAP panel covers navigation
	end

	local frame = UI.New("Frame", {
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = Color3.fromRGB(10, 9, 18),
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
		Parent = ctx.Gui,
	}, { UI.Corner(10), UI.Stroke(C.Cyan, 2, 0.3) })

	local city = workspace:WaitForChild("City", 10)
	local ground = city and city:FindFirstChild("Ground")
	if ground then
		for _, part in ipairs(ground:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "Ground" and math.max(part.Size.X, part.Size.Z) > 20 then
				local color = part.Name == "PlazaFloor" and C.Magenta or Color3.fromRGB(90, 90, 120)
				drawRect(frame, part, color, part.Name == "PlazaFloor" and 0.3 or 0.1, 2)
			end
		end
	end
	local racing = city and city:FindFirstChild("Racing")
	if racing then
		for _, part in ipairs(racing:GetChildren()) do
			if part:IsA("BasePart") and part.Name:sub(1, 5) == "Track" then
				drawRect(frame, part, C.Red, 0.35, 2)
			end
		end
	end
	local beach = city and city:FindFirstChild("Beach")
	if beach then
		for _, name in ipairs({ "Sand", "Water" }) do
			local part = beach:FindFirstChild(name)
			if part then
				drawRect(frame, part, name == "Sand" and Color3.fromRGB(214, 190, 140) or Color3.fromRGB(0, 120, 200), 0.3, 1)
			end
		end
	end
	local plotRects = {}
	local plots = workspace:WaitForChild("Plots", 10)
	if plots then
		for _, plotModel in ipairs(plots:GetChildren()) do
			local base = plotModel:FindFirstChild("Base")
			if base then
				plotRects[plotModel:GetAttribute("Index")] = drawRect(frame, base, Color3.fromRGB(60, 60, 85), 0.2, 2)
			end
		end
	end

	local function marker(text, color, size, zindex)
		return UI.New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = color,
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			TextStrokeTransparency = 0.3,
			ZIndex = zindex,
			Parent = frame,
		})
	end
	local me = marker("^", C.Gold, 18, 6)
	local target = marker("o", C.Orange, 14, 5)
	local others = {}

	task.spawn(function()
		while frame.Parent do
			-- Hidden while a big window (e.g. the build menu) is open.
			frame.Visible = ctx.Panels.Current() == nil
			-- Own plot highlight
			local data = ctx.State.Data
			for index, rect in pairs(plotRects) do
				rect.BackgroundColor3 = (data and data.PlotIndex == index) and C.Gold or Color3.fromRGB(60, 60, 85)
			end
			-- Me
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local u, v = toMap(root.Position.X, root.Position.Z)
				me.Position = UDim2.fromScale(u, v)
				local look = root.CFrame.LookVector
				me.Rotation = math.deg(math.atan2(look.X, -look.Z))
			end
			-- Guide target (delivery / tutorial)
			local goal = Guide.CurrentTarget()
			target.Visible = goal ~= nil
			if goal then
				local u, v = toMap(goal.X, goal.Z)
				target.Position = UDim2.fromScale(u, v)
			end
			-- Other players
			local seen = {}
			for _, other in ipairs(Players:GetPlayers()) do
				local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if otherRoot then
					seen[other] = true
					local dot = others[other]
					if not dot then
						dot = marker(".", C.Cyan, 22, 4)
						others[other] = dot
					end
					local u, v = toMap(otherRoot.Position.X, otherRoot.Position.Z)
					dot.Position = UDim2.fromScale(u, v)
				end
			end
			for other, dot in pairs(others) do
				if not seen[other] then
					dot:Destroy()
					others[other] = nil
				end
			end
			task.wait(0.2)
		end
	end)
end

return MinimapController
