-- ReflexPanel: Neon Reflex - wait for green, then tap as fast as you can. Pure skill.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local ReflexPanel = {}

local ctx, UI, C
local window, pad, info, summary, again
local runToken = nil
local tapState = nil -- { Round, Tapped }

local function setPad(text, color)
	pad.Text = text
	pad.BackgroundColor3 = color
end

local function run()
	local token = {}
	runToken = token
	summary.Text = ""
	again.Visible = false
	local start = Remotes.Get("ReflexStart"):InvokeServer()
	if not start or runToken ~= token then
		info.Text = "Neon Reflex is not available right now."
		return
	end
	for round = 1, start.Rounds do
		info.Text = ("Round %d / %d  -  wait for GREEN, then tap!"):format(round, start.Rounds)
		setPad("WAIT...", Color3.fromRGB(120, 20, 40))
		tapState = { Round = round, Armed = false, Tapped = false }
		local go = Remotes.Get("ReflexReady"):InvokeServer(round)
		if runToken ~= token then
			return
		end
		if not go then
			info.Text = "Round skipped."
			break
		end
		tapState.Armed = true
		setPad("TAP!", Color3.fromRGB(30, 200, 90))
		local waited = 0
		while not tapState.Tapped and waited < Config.Reflex.Timeout + 0.5 and runToken == token do
			task.wait(0.01)
			waited += 0.01
		end
		if runToken ~= token then
			return
		end
		local result = Remotes.Get("ReflexTap"):InvokeServer(round)
		if result then
			local cash = result.Cash > 0 and ("  +" .. Format.Money(result.Cash)) or ""
			setPad(("%s\n%.3fs%s"):format(result.Label, result.Time, cash), result.Cash > 0 and Color3.fromRGB(40, 40, 90) or Color3.fromRGB(60, 40, 40))
			if result.Final then
				local final = result.Final
				local average = final.Average and ("%.3fs"):format(final.Average) or "-"
				summary.Text = ("Average: %s   Hits: %d/%d\n+%s   +%d XP"):format(average, final.Hits, start.Rounds, Format.Money(final.Cash), final.XP)
			end
		end
		task.wait(1.1)
	end
	tapState = nil
	info.Text = "Round complete!"
	again.Visible = true
end

function ReflexPanel.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	local content, close
	window, content, close = UI.Window(ctx.Gui, "NEON REFLEX", C.Lime, UDim2.fromOffset(700, 500))
	close.Activated:Connect(function()
		ctx.Panels.Close()
	end)
	info = UI.Label("", {
		Size = UDim2.new(1, 0, 0, 30),
		MaxTextSize = 22,
		Parent = content,
	})
	pad = UI.New("TextButton", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 230),
		BackgroundColor3 = Color3.fromRGB(120, 20, 40),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		AutoButtonColor = false,
		Parent = content,
	}, { UI.Corner(18), UI.Stroke(C.Lime, 3), UI.Padding(20), UI.New("UITextSizeConstraint", { MaxTextSize = 80 }) })
	pad.Activated:Connect(function()
		if not tapState then
			return
		end
		if not tapState.Armed then
			info.Text = "Too early! Wait for GREEN."
			return
		end
		tapState.Tapped = true
	end)
	summary = UI.Label("", {
		Position = UDim2.fromOffset(0, 282),
		Size = UDim2.new(1, 0, 0, 70),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Gold,
		MaxTextSize = 28,
		Parent = content,
	})
	again = UI.Button("PLAY AGAIN", C.Lime, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(260, 60),
		Visible = false,
		Parent = content,
	})
	again.Activated:Connect(function()
		task.spawn(run)
	end)

	ctx.Panels.Register("Reflex", {
		Open = function()
			window.Visible = true
			task.spawn(run)
		end,
		Close = function()
			runToken = nil
			tapState = nil
			window.Visible = false
		end,
	})
end

return ReflexPanel
