-- TutorialController: shows the current tutorial step, pulses the relevant button and draws a
-- glowing guide beam to the player's resort for the first step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotUtil = require(Shared.PlotUtil)
local Remotes = require(Shared.Remotes)
local Tutorial = require(Shared.Tutorial)

local Guide = require(script.Parent.Guide)

local TutorialController = {}

local ctx, UI, C
local card, stepLabel, textLabel
local currentIndex = nil
local pulseToken = nil

local showingGuide = false

local function removeGuide()
	if showingGuide then
		showingGuide = false
		Guide.Hide()
	end
end

local function plotEntrance()
	local data = ctx.State.Data
	local plots = workspace:FindFirstChild("Plots")
	local plotModel = data and data.PlotIndex and plots and plots:FindFirstChild("Plot" .. data.PlotIndex)
	return plotModel and PlotUtil.Entrance(plotModel)
end

local function pulse(buttonName)
	pulseToken = {}
	local token = pulseToken
	local button = buttonName and ctx.HUD.GetMainButton(buttonName)
	if not button then
		return
	end
	local stroke = button:FindFirstChildOfClass("UIStroke")
	task.spawn(function()
		while pulseToken == token and stroke.Parent do
			stroke.Thickness = 2 + (math.sin(os.clock() * 6) + 1) * 2.5
			task.wait(0.05)
		end
		stroke.Thickness = 2
	end)
end

local function render(data)
	local index = data and data.Tutorial or Tutorial.Done
	local step = Tutorial.Steps[index]
	if index == currentIndex then
		return
	end
	currentIndex = index
	removeGuide()
	pulseToken = nil
	if not step then
		card.Visible = false
		ctx.HUD.SetGoalVisible(true)
		return
	end
	card.Visible = true
	ctx.HUD.SetGoalVisible(false)
	stepLabel.Text = ("TUTORIAL  %d / %d"):format(index, #Tutorial.Steps)
	textLabel.Text = step.Text
	pulse(step.Button)
	if step.Guide == "Resort" then
		task.spawn(function()
			for _ = 1, 20 do
				local target = plotEntrance()
				if target then
					showingGuide = true
					Guide.Show(target, C.Cyan)
					return
				end
				task.wait(0.5)
			end
		end)
	end
end

function TutorialController.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	card = UI.New("Frame", {
		Name = "Tutorial",
		Position = UDim2.new(0, 14, 0, 176),
		Size = UDim2.fromOffset(300, 124),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = ctx.Gui,
	}, { UI.Corner(12), UI.Stroke(C.Cyan, 3) })
	stepLabel = UI.Label("", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -90, 0, 20),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Cyan,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = card,
	})
	textLabel = UI.Label("", {
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 1, -38),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 19,
		Parent = card,
	})
	local skip = UI.Button("SKIP", C.SubText, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 4),
		Size = UDim2.fromOffset(70, 26),
		Parent = card,
	})
	skip.Activated:Connect(function()
		Remotes.Get("TutorialAction"):InvokeServer("Skip")
	end)

	ctx.State.Changed:Connect(render)
	render(ctx.State.Data)

	ctx.Panels.Changed:Connect(function(name)
		local data = ctx.State.Data
		local step = data and Tutorial.Steps[data.Tutorial or Tutorial.Done]
		if name == "Tasks" and step and step.Id == "OpenTasks" then
			Remotes.Get("TutorialAction"):InvokeServer("TasksOpened")
		end
	end)
end

return TutorialController
