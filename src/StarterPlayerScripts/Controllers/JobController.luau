-- JobController: HUD + guide beam for the optional delivery job.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Guide = require(script.Parent.Guide)

local JobController = {}

local ctx, UI, C
local bar, label
local current = nil

local function onState(info)
	if info.Phase == "Active" then
		current = info
		bar.Visible = true
		Guide.Show(info.Target, C.Orange)
	else
		current = nil
		bar.Visible = false
		Guide.Hide()
	end
end

function JobController.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	bar = UI.New("Frame", {
		Name = "DeliveryBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 150),
		Size = UDim2.fromOffset(300, 92),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = ctx.Gui,
	}, { UI.Corner(12), UI.Stroke(C.Orange, 3) })
	label = UI.Label("", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 44),
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Orange,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = bar,
	})
	local cancel = UI.Button("CANCEL", C.Red, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(110, 32),
		Parent = bar,
	})
	cancel.Activated:Connect(function()
		Remotes.Get("JobAction"):InvokeServer("Cancel")
	end)

	Remotes.Get("JobState").OnClientEvent:Connect(onState)

	task.spawn(function()
		while true do
			if current then
				local left = current.EndsAt - workspace:GetServerTimeNow()
				label.Text = ("DELIVER TO: %s\n%s left  |  reward %s"):format(current.Name, Format.Time(left), Format.Money(current.Cash))
			end
			task.wait(0.25)
		end
	end)
end

return JobController
