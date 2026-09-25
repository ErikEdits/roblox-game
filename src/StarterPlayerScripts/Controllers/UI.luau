-- UI: tiny helper library for building the NEON CITY interface in code.
-- Mobile-first: everything is designed for a 1280x720 canvas and scaled with a UIScale.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = {}

----------------------------------------------------------------------
-- Sounds (built-in client sound so no uploaded audio is needed)
----------------------------------------------------------------------
UI.SoundsEnabled = true
local SOUND_ID = "rbxasset://sounds/electronicpingshort.wav"
local SOUNDS = {
	Click = { Speed = 2.2, Volume = 0.25 },
	Reward = { Speed = 1.2, Volume = 0.45 },
	LevelUp = { Speed = 0.8, Volume = 0.6 },
	Error = { Speed = 0.6, Volume = 0.35 },
}
local soundCache = {}

function UI.PlaySound(name)
	if not UI.SoundsEnabled then
		return
	end
	local spec = SOUNDS[name]
	if not spec then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "UI_" .. name
		sound.SoundId = SOUND_ID
		sound.Volume = spec.Volume
		sound.PlaybackSpeed = spec.Speed
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	pcall(function()
		SoundService:PlayLocalSound(sound)
	end)
end

-- Small "pop" when a window becomes visible.
function UI.Pop(guiObject)
	local scale = guiObject:FindFirstChild("PopScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PopScale"
		scale.Parent = guiObject
	end
	scale.Scale = 0.88
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

UI.Colors = {
	Background = Color3.fromRGB(14, 12, 26),
	Panel = Color3.fromRGB(22, 19, 40),
	PanelLight = Color3.fromRGB(34, 30, 60),
	Text = Color3.fromRGB(245, 245, 255),
	SubText = Color3.fromRGB(170, 170, 205),
	Cyan = Color3.fromRGB(0, 235, 255),
	Magenta = Color3.fromRGB(255, 40, 200),
	Gold = Color3.fromRGB(255, 200, 60),
	Lime = Color3.fromRGB(140, 255, 60),
	Red = Color3.fromRGB(255, 70, 70),
	Violet = Color3.fromRGB(150, 80, 255),
	Orange = Color3.fromRGB(255, 130, 40),
	Disabled = Color3.fromRGB(70, 70, 90),
}

function UI.IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- UI.New("Frame", { Size = ..., Parent = ... }, { child1, child2 })
function UI.New(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.Corner(radius)
	return UI.New("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UI.Stroke(color, thickness, transparency)
	return UI.New("UIStroke", {
		Color = color or UI.Colors.Cyan,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.Padding(all, horizontal)
	return UI.New("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, horizontal or all),
		PaddingRight = UDim.new(0, horizontal or all),
	})
end

function UI.List(direction, padding, horizontalAlign, verticalAlign)
	return UI.New("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = horizontalAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = verticalAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.Label(text, props)
	props = props or {}
	local label = UI.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text or "",
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 24),
	})
	local parent = nil
	for key, value in pairs(props) do
		if key == "Parent" then
			parent = value
		elseif key ~= "MaxTextSize" then
			label[key] = value
		end
	end
	if label.TextScaled then
		UI.New("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 40, Parent = label })
	end
	if parent then
		label.Parent = parent
	end
	return label
end

function UI.Button(text, color, props)
	color = color or UI.Colors.Cyan
	local button = UI.New("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(color.R * 0.25, color.G * 0.25, color.B * 0.25),
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		Size = UDim2.fromOffset(140, 48),
	}, {
		UI.Corner(10),
		UI.Stroke(color, 2),
		UI.Padding(6, 10),
		UI.New("UITextSizeConstraint", { MaxTextSize = 26 }),
	})
	for key, value in pairs(props or {}) do
		button[key] = value
	end
	button.Activated:Connect(function()
		UI.PlaySound("Click")
	end)
	return button
end

function UI.SetButtonEnabled(button, enabled, color)
	button.Active = enabled
	button.AutoButtonColor = enabled
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = enabled and (color or UI.Colors.Cyan) or UI.Colors.Disabled
	end
	button.TextTransparency = enabled and 0 or 0.4
end

-- Horizontal progress bar. Returns frame, setter(fraction, text?)
function UI.Bar(color, props)
	local fill = UI.New("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, { UI.Corner(6) })
	local text = UI.Label("", {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		ZIndex = 3,
		MaxTextSize = 18,
	})
	local frame = UI.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(8, 8, 16),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 16),
	}, { UI.Corner(6), fill, text })
	for key, value in pairs(props or {}) do
		frame[key] = value
	end
	local function set(fraction, label)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		text.Text = label or ""
	end
	return frame, set
end

-- Modal window with title and close button. Returns window, content frame, close button.
function UI.Window(parent, title, color, size)
	color = color or UI.Colors.Cyan
	local window = UI.New("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size or UDim2.fromOffset(760, 500),
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	}, { UI.Corner(16), UI.Stroke(color, 3) })

	UI.Label(title, {
		Name = "Title",
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -100, 0, 40),
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 34,
		Parent = window,
	})
	local close = UI.Button("X", UI.Colors.Red, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(52, 48),
		Parent = window,
	})
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			UI.Pop(window)
		end
	end)
	local content = UI.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 1, -82),
		Parent = window,
	})
	return window, content, close
end

function UI.Scroll(props)
	local scroll = UI.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Colors.Cyan,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	for key, value in pairs(props or {}) do
		scroll[key] = value
	end
	return scroll
end

function UI.Clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return UI
