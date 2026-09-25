-- MinigameService: Card Rush, a fast card-themed SKILL game.
-- Casino look, zero gambling: nothing is staked, rewards depend only on correct and fast answers.
-- The server generates every question, keeps the answers secret and times the responses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local MinigameService = {}

local services
local sessions = {} -- [player] = session

local FEEDBACK_DELAY = 1.2 -- must match the client's feedback pause

local SUITS = { "Spades", "Hearts", "Diamonds", "Clubs" }
local SUIT_SYMBOL = { "♠", "♥", "♦", "♣" }
local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function distinctRanks(count, low, high)
	local pool = {}
	for rank = low, high do
		table.insert(pool, rank)
	end
	shuffle(pool)
	return { table.unpack(pool, 1, count) }
end

local function card(rank, suit)
	return { R = rank, S = suit or math.random(4) }
end

-- Each generator returns { Prompt, Header?, Options, Correct = set of option indices }
local Generators = {}

function Generators.Highest()
	local ranks = distinctRanks(4, 2, 14)
	local options, best = {}, 1
	for i, rank in ipairs(ranks) do
		options[i] = card(rank)
		if rank > ranks[best] then
			best = i
		end
	end
	return { Prompt = "Tap the HIGHEST card", Options = options, Correct = { [best] = true } }
end

function Generators.Lowest()
	local ranks = distinctRanks(4, 2, 14)
	local options, lowest = {}, 1
	for i, rank in ipairs(ranks) do
		options[i] = card(rank)
		if rank < ranks[lowest] then
			lowest = i
		end
	end
	return { Prompt = "Tap the LOWEST card", Options = options, Correct = { [lowest] = true } }
end

function Generators.Pair()
	local ranks = distinctRanks(4, 2, 14)
	local suits = shuffle({ 1, 2, 3, 4 })
	local options = {
		card(ranks[1], suits[1]),
		card(ranks[1], suits[2]),
		card(ranks[2]),
		card(ranks[3]),
		card(ranks[4]),
	}
	local order = shuffle({ 1, 2, 3, 4, 5 })
	local shuffled, correct = {}, {}
	for newIndex, oldIndex in ipairs(order) do
		shuffled[newIndex] = options[oldIndex]
		if oldIndex <= 2 then
			correct[newIndex] = true
		end
	end
	return { Prompt = "Tap a card from the PAIR", Options = shuffled, Correct = correct }
end

function Generators.Suit()
	local target = math.random(4)
	local others = {}
	for suit = 1, 4 do
		if suit ~= target then
			table.insert(others, suit)
		end
	end
	local ranks = distinctRanks(4, 2, 14)
	local answer = math.random(4)
	local options = {}
	for i = 1, 4 do
		options[i] = card(ranks[i], i == answer and target or others[math.random(#others)])
	end
	return { Prompt = "Tap the " .. SUIT_SYMBOL[target] .. " " .. string.upper(SUITS[target]) .. " card", Options = options, Correct = { [answer] = true } }
end

function Generators.Color()
	local wantRed = math.random() < 0.5
	local ranks = distinctRanks(4, 2, 14)
	local answer = math.random(4)
	local options = {}
	for i = 1, 4 do
		local suit
		if (i == answer) == wantRed then
			suit = math.random() < 0.5 and 2 or 3
		else
			suit = math.random() < 0.5 and 1 or 4
		end
		options[i] = card(ranks[i], suit)
	end
	return { Prompt = "Tap the only " .. (wantRed and "RED" or "BLACK") .. " card", Options = options, Correct = { [answer] = true } }
end

function Generators.Straight()
	local start = math.random(2, 10)
	local missing = math.random(0, 3)
	local header = {}
	for i = 0, 3 do
		if i == missing then
			table.insert(header, { R = 0, S = 0 }) -- placeholder shown as "?"
		else
			table.insert(header, card(start + i))
		end
	end
	local answerRank = start + missing
	local pool = {}
	for rank = 2, 14 do
		if rank ~= answerRank then
			table.insert(pool, rank)
		end
	end
	shuffle(pool)
	local answer = math.random(4)
	local options, used = {}, 1
	for i = 1, 4 do
		if i == answer then
			options[i] = card(answerRank)
		else
			options[i] = card(pool[used])
			used += 1
		end
	end
	return { Prompt = "Complete the STRAIGHT", Header = header, Options = options, Correct = { [answer] = true } }
end

function Generators.Sum()
	local a = math.random(2, 6)
	local b = math.random(2, 10 - a)
	local total = a + b
	local pool = {}
	for rank = 2, 10 do
		if rank ~= total then
			table.insert(pool, rank)
		end
	end
	shuffle(pool)
	local answer = math.random(4)
	local options, used = {}, 1
	for i = 1, 4 do
		if i == answer then
			options[i] = card(total)
		else
			options[i] = card(pool[used])
			used += 1
		end
	end
	return { Prompt = ("Tap the card worth %d + %d"):format(a, b), Options = options, Correct = { [answer] = true } }
end

local GENERATOR_ORDER = { "Highest", "Suit", "Color", "Lowest", "Pair", "Sum", "Straight" }

local function timeFor(index)
	local cfg = Config.CardRush
	local t = (index - 1) / math.max(1, cfg.Questions - 1)
	return cfg.TimeStart + (cfg.TimeEnd - cfg.TimeStart) * t
end

local function publicQuestion(session)
	local question = session.Questions[session.Index]
	return {
		Index = session.Index,
		Total = #session.Questions,
		Prompt = question.Prompt,
		Header = question.Header,
		Options = question.Options,
		Time = question.Time,
		Score = session.Score,
	}
end

local function start(player)
	local data = services.DataService.Get(player)
	if not data then
		return nil
	end
	if services.RaceService.IsRacing(player) then
		return nil
	end
	local questions = {}
	for i = 1, Config.CardRush.Questions do
		local kind = i <= 2 and GENERATOR_ORDER[i] or GENERATOR_ORDER[math.random(#GENERATOR_ORDER)]
		local question = Generators[kind]()
		question.Time = timeFor(i)
		table.insert(questions, question)
	end
	local session = { Questions = questions, Index = 1, Score = 0, Cash = 0, StartedAt = os.clock() }
	sessions[player] = session
	return publicQuestion(session)
end

local function finish(player, session)
	sessions[player] = nil
	local cfg = Config.CardRush
	local total = #session.Questions
	local cash = session.Cash
	local xp = session.Score * cfg.XPPerCorrect
	local perfect = session.Score == total
	if perfect then
		cash += cfg.PerfectBonusCash
		xp += cfg.PerfectBonusXP
	end
	local data = services.DataService.Get(player)
	if data then
		data.Stats.MinigamesPlayed += 1
		data.Stats.CardRushBest = math.max(data.Stats.CardRushBest, session.Score)
	end
	services.QuestService.Increment(player, "minigames", 1)
	services.TutorialService.Event(player, "PlayMinigame")
	services.AnalyticsService.Log(player, "CardRushFinished", { Score = session.Score })
	if cash > 0 or xp > 0 then
		services.EconomyService.Reward(player, cash, xp, "Card Rush")
	end
	return { Finished = true, Score = session.Score, Total = total, Cash = math.floor(cash), XP = math.floor(xp), Perfect = perfect }
end

local function answer(player, index, choice)
	local session = sessions[player]
	if not session or type(index) ~= "number" or index ~= session.Index then
		return nil
	end
	local question = session.Questions[session.Index]
	local elapsed = os.clock() - session.AskedAt
	if elapsed < Config.CardRush.MinAnswerTime then
		return nil -- input spam, ignore
	end
	local inTime = elapsed <= question.Time + 0.75 -- small latency grace
	local correct = inTime and type(choice) == "number" and question.Correct[choice] == true
	if correct then
		session.Score += 1
		local speed = math.clamp(1 - elapsed / question.Time, 0, 1)
		session.Cash += Config.CardRush.CashPerCorrect + Config.CardRush.SpeedBonusCash * speed
	end
	local correctList = {}
	for optionIndex in pairs(question.Correct) do
		table.insert(correctList, optionIndex)
	end

	session.Index += 1
	local result = { Correct = correct, CorrectOptions = correctList, Score = session.Score }
	if session.Index > #session.Questions then
		result.Final = finish(player, session)
	else
		result.Next = publicQuestion(session)
		-- The client shows feedback for FEEDBACK_DELAY seconds before the next question appears.
		session.AskedAt = os.clock() + FEEDBACK_DELAY
	end
	return result
end

function MinigameService.Init(allServices)
	services = allServices

	Remotes.Get("CardRushStart").OnServerInvoke = function(player)
		local question = start(player)
		if question then
			sessions[player].AskedAt = os.clock()
		end
		return question
	end

	Remotes.Get("CardRushAnswer").OnServerInvoke = answer

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return MinigameService
