-- RaceHUD: countdown, lap / position / time, checkpoint marker and results.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local RaceHUD = {}

local ctx, UI, C
local bar, barLabel, big, results, resultsLabel, marker

local function showBig(text, color, duration)
	big.Text = text
	big.TextColor3 = color or C.Gold
	big.Visible = true
	local token = {}
	big:SetAttribute("Token", tostring(token))
	task.delay(duration or 1, function()
		if big:GetAttribute("Token") == tostring(token) then
			big.Visible = false
		end
	end)
end

local function setMarker(position)
	if not position then
		if marker then
			marker.Parent = nil
		end
		return
	end
	if not marker then
		marker = Instance.new("Part")
		marker.Name = "NextCheckpoint"
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.4, 30, 30)
		marker.Material = Enum.Material.Neon
		marker.Color = C.Lime
		marker.Transparency = 0.55
	end
	marker.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	marker.Parent = workspace.CurrentCamera
end

local function onState(info)
	local phase = info.Phase
	if phase == "Lobby" then
		-- The server already sent a "joined" notification; the bar appears at the countdown.
		results.Visible = false
	elseif phase == "Countdown" then
		ctx.Panels.Close()
		ctx.HUD.SetMainButtonsVisible(false)
		bar.Visible = true
		barLabel.Text = "Use W/S (or the thumbstick) to drive, A/D to steer"
		showBig(tostring(info.Count), C.Gold, 0.9)
	elseif phase == "Go" then
		showBig("GO!", C.Lime, 1.2)
	elseif phase == "Racing" or phase == "Finished" then
		bar.Visible = true
		local text = ("LAP %d/%d   POS %d/%d   %s   CP %d/%d"):format(
			info.Lap, info.Laps, info.Position, info.Count, Format.RaceTime(info.Time), info.Checkpoint, info.Checkpoints)
		if phase == "Finished" then
			text = ("FINISHED  P%d   %s  - waiting for others"):format(info.Position, Format.RaceTime(info.Time))
		elseif info.OutOfCar then
			text = ("GET BACK IN YOUR CAR! %ds"):format(math.ceil(info.OutOfCar))
		end
		barLabel.Text = text
		setMarker(phase == "Racing" and info.NextCheckpoint or nil)
	elseif phase == "DNF" then
		setMarker(nil)
		barLabel.Text = "Did not finish."
	elseif phase == "Results" then
		setMarker(nil)
		bar.Visible = false
		results.Visible = true
		local lines = {}
		for _, entry in ipairs(info.Standings or {}) do
			table.insert(lines, ("%d. %s  %s"):format(entry.Place, entry.Name, entry.Time))
		end
		local header = info.Place and ("You finished P%d  (%s)"):format(info.Place, info.Time) or "You did not finish"
		local reward = (info.Cash or 0) > 0 and ("\n+%s  +%d XP"):format(Format.Money(info.Cash), info.XP) or ""
		resultsLabel.Text = header .. reward .. "\n\n" .. table.concat(lines, "\n")
		if info.Place == 1 then
			showBig("WINNER!", C.Gold, 2)
		end
	elseif phase == "Idle" then
		setMarker(nil)
		bar.Visible = false
		results.Visible = false
		ctx.HUD.SetMainButtonsVisible(true)
	end
end

function RaceHUD.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	bar = UI.New("Frame", {
		Name = "RaceBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24), -- main buttons are hidden while racing
		Size = UDim2.fromOffset(640, 52),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = ctx.Gui,
	}, { UI.Corner(12), UI.Stroke(C.Red, 3) })
	barLabel = UI.Label("", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 26,
		Parent = bar,
	})
	big = UI.Label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(500, 160),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.2,
		MaxTextSize = 140,
		Visible = false,
		Parent = ctx.Gui,
	})
	results = UI.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 400),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = ctx.Gui,
	}, { UI.Corner(16), UI.Stroke(C.Red, 3), UI.Padding(18) })
	UI.Label("RACE RESULTS", {
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Red,
		MaxTextSize = 32,
		Parent = results,
	})
	resultsLabel = UI.Label("", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		Font = Enum.Font.GothamBold,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 22,
		Parent = results,
	})

	Remotes.Get("RaceState").OnClientEvent:Connect(onState)
end

return RaceHUD
