-- PlayPanel: activity hub (Card Rush + Street Race) and the Card Rush game screen.
-- Card Rush is a skill game: no stakes, no betting, rewards only for correct & fast answers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayPanel = {}

local ctx, UI, C

local FEEDBACK_DELAY = 1.2 -- must match MinigameService
local SUITS = { "♠", "♥", "♦", "♣" }
local RANKS = { [11] = "J", [12] = "Q", [13] = "K", [14] = "A" }

local hub, hubContent
local game_, promptLabel, scoreLabel, headerRow, optionRow, setTimer, resultFrame, resultLabel
local session = nil -- { Question, Answered, Token }

local function cardText(card)
	if card.R == 0 then
		return "?"
	end
	return (RANKS[card.R] or tostring(card.R)) .. "\n" .. (SUITS[card.S] or "")
end

local function cardColor(card)
	if card.S == 2 or card.S == 3 then
		return Color3.fromRGB(215, 20, 50)
	end
	return Color3.fromRGB(20, 20, 30)
end

local function makeCard(card, size, parent, clickable)
	local button = UI.New(clickable and "TextButton" or "TextLabel", {
		Size = size,
		BackgroundColor3 = card.R == 0 and Color3.fromRGB(60, 50, 90) or Color3.fromRGB(250, 250, 255),
		Text = cardText(card),
		TextColor3 = card.R == 0 and C.Gold or cardColor(card),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Parent = parent,
	}, { UI.Corner(10), UI.Stroke(C.Magenta, 2), UI.Padding(10) })
	if clickable then
		button.AutoButtonColor = true
	end
	return button
end

----------------------------------------------------------------------
-- Card Rush game
----------------------------------------------------------------------
local showQuestion

local function showResult(final)
	session = nil
	UI.Clear(headerRow)
	UI.Clear(optionRow)
	setTimer(0, "")
	resultFrame.Visible = true
	local lines = {
		("Score: %d / %d"):format(final.Score, final.Total),
		("+%s   +%d XP"):format(Format.Money(final.Cash), final.XP),
	}
	if final.Perfect then
		table.insert(lines, "PERFECT ROUND!")
	end
	resultLabel.Text = table.concat(lines, "\n")
	promptLabel.Text = "Round complete"
end

local function answer(choice, buttons)
	if not session or session.Answered then
		return
	end
	session.Answered = true
	for _, button in ipairs(buttons) do
		button.Active = false
		button.AutoButtonColor = false
	end
	local question = session.Question
	local result = Remotes.Get("CardRushAnswer"):InvokeServer(question.Index, choice)
	if not session then
		return
	end
	if not result then
		-- Too fast / out of sync: let the player try again.
		session.Answered = false
		for _, button in ipairs(buttons) do
			button.Active = true
			button.AutoButtonColor = true
		end
		return
	end
	for _, index in ipairs(result.CorrectOptions or {}) do
		local button = buttons[index]
		if button then
			button:FindFirstChildOfClass("UIStroke").Color = C.Lime
			button:FindFirstChildOfClass("UIStroke").Thickness = 6
		end
	end
	if not result.Correct and buttons[choice] then
		buttons[choice]:FindFirstChildOfClass("UIStroke").Color = C.Red
		buttons[choice]:FindFirstChildOfClass("UIStroke").Thickness = 6
	end
	promptLabel.Text = result.Correct and "CORRECT!" or (choice == 0 and "TIME UP!" or "WRONG!")
	promptLabel.TextColor3 = result.Correct and C.Lime or C.Red
	scoreLabel.Text = ("Score %d"):format(result.Score)
	task.wait(FEEDBACK_DELAY)
	if not session then
		return
	end
	if result.Final then
		showResult(result.Final)
	elseif result.Next then
		showQuestion(result.Next)
	end
end

function showQuestion(question)
	resultFrame.Visible = false
	session = { Question = question, Answered = false }
	local token = {}
	session.Token = token
	promptLabel.Text = question.Prompt
	promptLabel.TextColor3 = C.Text
	scoreLabel.Text = ("Question %d / %d   |   Score %d"):format(question.Index, question.Total, question.Score)

	UI.Clear(headerRow)
	if question.Header then
		headerRow.Visible = true
		for _, card in ipairs(question.Header) do
			makeCard(card, UDim2.fromOffset(70, 96), headerRow, false)
		end
	else
		headerRow.Visible = false
	end

	UI.Clear(optionRow)
	local buttons = {}
	for index, card in ipairs(question.Options) do
		local button = makeCard(card, UDim2.fromOffset(112, 156), optionRow, true)
		button.LayoutOrder = index
		buttons[index] = button
		button.Activated:Connect(function()
			answer(index, buttons)
		end)
	end

	task.spawn(function()
		local started = os.clock()
		while session and session.Token == token and not session.Answered do
			local left = question.Time - (os.clock() - started)
			setTimer(left / question.Time, string.format("%.1fs", math.max(0, left)))
			if left <= 0 then
				answer(0, buttons)
				return
			end
			task.wait(0.05)
		end
	end)
end

local function startCardRush()
	resultFrame.Visible = false
	promptLabel.Text = "Get ready..."
	promptLabel.TextColor3 = C.Text
	local question = Remotes.Get("CardRushStart"):InvokeServer()
	if not question then
		promptLabel.Text = "Card Rush is not available right now."
		return
	end
	showQuestion(question)
end

----------------------------------------------------------------------
-- Hub
----------------------------------------------------------------------
local function renderHub()
	UI.Clear(hubContent)
	local data = ctx.State.Data
	local stats = data and data.Stats or {}

	local function activity(order, title, color, lines, buttonText, callback)
		local card = UI.New("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(0.5, -8, 1, 0),
			BackgroundColor3 = C.Panel,
			Parent = hubContent,
		}, { UI.Corner(14), UI.Stroke(color, 2), UI.Padding(14) })
		UI.Label(title, {
			Size = UDim2.new(1, 0, 0, 40),
			Font = Enum.Font.GothamBlack,
			TextColor3 = color,
			MaxTextSize = 32,
			Parent = card,
		})
		UI.Label(table.concat(lines, "\n"), {
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 1, -130),
			Font = Enum.Font.GothamMedium,
			TextColor3 = C.SubText,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxTextSize = 18,
			Parent = card,
		})
		local button = UI.Button(buttonText, color, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 64),
			Parent = card,
		})
		button.Activated:Connect(callback)
	end

	activity(1, "CARD RUSH", C.Magenta, {
		"Fast card skill game. No betting - only skill.",
		("%d questions. Faster answers = more cash."):format(Config.CardRush.Questions),
		"",
		("Best score: %d / %d"):format(stats.CardRushBest or 0, Config.CardRush.Questions),
		("Rounds played: %d"):format(stats.MinigamesPlayed or 0),
	}, "PLAY", function()
		ctx.Panels.Open("CardRush")
	end)

	activity(2, "STREET RACE", C.Red, {
		"Race other players and NPC drivers.",
		("%d laps. Top 3 win big rewards."):format(Config.Race.Laps),
		"All cars have identical speed.",
		"",
		("Best time: %s"):format((stats.BestRaceTime or 0) > 0 and Format.RaceTime(stats.BestRaceTime) or "-"),
		("Races won: %d"):format(stats.RacesWon or 0),
	}, "JOIN RACE", function()
		ctx.Panels.Close()
		local ok, message = Remotes.Get("JoinRace"):InvokeServer()
		if not ok and message then
			ctx.HUD.Notify(tostring(message), "warning")
		end
	end)
end

function PlayPanel.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	-- Hub window
	local close
	hub, hubContent, close = UI.Window(ctx.Gui, "PLAY", C.Magenta, UDim2.fromOffset(780, 470))
	UI.List(Enum.FillDirection.Horizontal, 16).Parent = hubContent
	close.Activated:Connect(function()
		ctx.Panels.Close()
	end)
	ctx.Panels.Register("Play", {
		Open = function()
			renderHub()
			hub.Visible = true
		end,
		Close = function()
			hub.Visible = false
		end,
	})

	-- Card Rush window
	local content, closeGame
	game_, content, closeGame = UI.Window(ctx.Gui, "CARD RUSH", C.Magenta, UDim2.fromOffset(780, 520))
	closeGame.Activated:Connect(function()
		ctx.Panels.Close()
	end)
	promptLabel = UI.Label("", {
		Size = UDim2.new(1, 0, 0, 44),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 34,
		Parent = content,
	})
	scoreLabel = UI.Label("", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = C.SubText,
		MaxTextSize = 18,
		Parent = content,
	})
	local timerBar
	timerBar, setTimer = UI.Bar(C.Magenta, {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = content,
	})
	local _ = timerBar
	headerRow = UI.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 0, 100),
		Parent = content,
	}, { UI.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	optionRow = UI.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 160),
		Parent = content,
	}, { UI.List(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center) })
	resultFrame = UI.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 110),
		Size = UDim2.new(1, 0, 1, -110),
		Visible = false,
		Parent = content,
	})
	resultLabel = UI.Label("", {
		Size = UDim2.new(1, 0, 0, 150),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Gold,
		MaxTextSize = 36,
		Parent = resultFrame,
	})
	local again = UI.Button("PLAY AGAIN", C.Magenta, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(260, 64),
		Parent = resultFrame,
	})
	again.Activated:Connect(startCardRush)

	ctx.Panels.Register("CardRush", {
		Open = function()
			game_.Visible = true
			task.spawn(startCardRush)
		end,
		Close = function()
			session = nil
			game_.Visible = false
		end,
	})
end

return PlayPanel
