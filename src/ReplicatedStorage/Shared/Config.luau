-- NEON CITY: central game configuration.
-- Every tunable number lives here so balancing never requires touching gameplay code.

local Config = {}

Config.Version = "0.2.0"

-- Extra admin user IDs for the live game (Studio and the experience creator are always admins).
Config.Admins = {}
Config.MaxPlayers = 15 -- set the same value in Game Settings > Places on the Roblox website

----------------------------------------------------------------------
-- Economy / progression
----------------------------------------------------------------------
Config.StartingCash = 1000
Config.MaxLevel = 100
Config.GridSize = 4
Config.PlotSize = 80 -- buildable square in studs
Config.MaxBuildingsPerPlot = 40
Config.SellRefund = 0.5 -- share of the price refunded when deleting a building
Config.PassiveIncomeInterval = 60 -- seconds between "resort operations" payouts
Config.PlaceXPDivisor = 12 -- XP for placing = cost / divisor (capped)
Config.PlaceXPCap = 400

-- Neon accent colors players can pick for each building ("simple customization").
Config.AccentColors = {
	Color3.fromRGB(0, 235, 255),
	Color3.fromRGB(255, 40, 200),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(140, 255, 60),
	Color3.fromRGB(150, 80, 255),
	Color3.fromRGB(255, 120, 30),
	Color3.fromRGB(255, 60, 60),
	Color3.fromRGB(245, 245, 255),
}

-- Building upgrades (only buildings that earn money from visitors can be upgraded).
Config.Upgrades = {
	MaxLevel = 3,
	CostMultiplier = { [2] = 1.5, [3] = 3 }, -- price of the upgrade = building cost * multiplier
	IncomeMultiplier = { 1, 1.6, 2.5 }, -- visitor spend + passive income
	AppealMultiplier = { 1, 1.25, 1.5 }, -- how strongly NPCs are attracted
	RatingMultiplier = { 1, 1.5, 2.2 }, -- resort rating contribution
	ExtraLevelRequired = { [2] = 2, [3] = 6 }, -- player level needed = building level + this
}

----------------------------------------------------------------------
-- Data
----------------------------------------------------------------------
Config.DataStoreName = "NeonCity_PlayerData_v1"
Config.LeaderboardStoreName = "NeonCity_BestTrial_v1"
Config.AutosaveInterval = 120

----------------------------------------------------------------------
-- NPC visitors
----------------------------------------------------------------------
Config.NPC = {
	MaxActive = 28,
	MinActive = 8,
	SpawnInterval = 2.5,
	WalkSpeed = 12,
	VisitsMin = 1,
	VisitsMax = 3,
	ActivityTimeMin = 6,
	ActivityTimeMax = 12,
	MoveTimeout = 25,
	LabelDistance = 60,
	FamilyGroupChance = 0.6, -- families spawn with 1-2 kids that follow them

	-- Weight = how often this type spawns. Colors tint the NPC so types are readable at a glance.
	Types = {
		Tourist = { Weight = 40, Color = Color3.fromRGB(255, 170, 60), Icon = "Tourist", SpendMultiplier = 1.0 },
		Luxury = { Weight = 10, Color = Color3.fromRGB(255, 215, 90), Icon = "Luxury", SpendMultiplier = 2.2 },
		Racer = { Weight = 15, Color = Color3.fromRGB(255, 70, 70), Icon = "Racer", SpendMultiplier = 1.2 },
		Family = { Weight = 20, Color = Color3.fromRGB(90, 220, 120), Icon = "Family", SpendMultiplier = 1.1 },
		Business = { Weight = 10, Color = Color3.fromRGB(80, 150, 255), Icon = "Business", SpendMultiplier = 1.6 },
		Event = { Weight = 5, Color = Color3.fromRGB(190, 110, 255), Icon = "Event Fan", SpendMultiplier = 1.3 },
	},
}

----------------------------------------------------------------------
-- Card Rush (skill game, no betting)
----------------------------------------------------------------------
Config.CardRush = {
	Questions = 8,
	TimeStart = 6.0, -- seconds for the first question
	TimeEnd = 3.5, -- seconds for the last question
	MinAnswerTime = 0.3, -- anything faster is ignored as input spam
	CashPerCorrect = 30,
	XPPerCorrect = 12,
	SpeedBonusCash = 20, -- max bonus per question for instant answers
	PerfectBonusCash = 150,
	PerfectBonusXP = 60,
}

----------------------------------------------------------------------
-- Neon Reflex (reaction skill game)
----------------------------------------------------------------------
Config.Reflex = {
	Rounds = 5,
	DelayMin = 1.2,
	DelayMax = 3.2,
	-- Measured time includes network latency, so thresholds are generous.
	Tiers = {
		{ Time = 0.45, Cash = 45, Label = "LIGHTNING" },
		{ Time = 0.65, Cash = 30, Label = "FAST" },
		{ Time = 0.9, Cash = 15, Label = "OK" },
	},
	XPPerRound = 8,
	Timeout = 3,
}

----------------------------------------------------------------------
-- Optional jobs (never required to progress)
----------------------------------------------------------------------
Config.Jobs = {
	Delivery = {
		BaseCash = 60,
		CashPerStud = 0.35,
		BaseXP = 20,
		XPPerStud = 0.05,
		BaseTime = 25,
		SecondsPerStud = 1 / 14,
		ArriveRadius = 16,
		MinDistance = 150,
	},
}

----------------------------------------------------------------------
-- Racing
----------------------------------------------------------------------
Config.Race = {
	Laps = 2,
	LobbyTime = 12,
	CountdownTime = 3,
	TimeLimit = 150,
	MaxParticipants = 8,
	MinRacers = 4, -- NPC racers fill up to this number
	CheckpointRadius = 28,
	CarMaxSpeed = 85,
	CarReverseSpeed = 30,
	CarAcceleration = 40,
	CarBraking = 90,
	CarCoastDecel = 18,
	CarTurnRate = 2.1, -- radians per second at full steer
	NPCSpeedMin = 58,
	NPCSpeedMax = 74,
	Rewards = {
		{ Cash = 700, XP = 180 },
		{ Cash = 450, XP = 130 },
		{ Cash = 300, XP = 100 },
	},
	FinishReward = { Cash = 180, XP = 60 },
	TimeTrialReward = { Cash = 120, XP = 40 },
	TimeTrialRecordBonus = { Cash = 300, XP = 80 },
	EventMultiplier = 2,
}

----------------------------------------------------------------------
-- Server events
----------------------------------------------------------------------
Config.Events = {
	FirstDelay = 75,
	IntervalMin = 150,
	IntervalMax = 240,
	Blackout = { Duration = 120, RepairCash = 200, RepairXP = 50, AllRepairedBonusCash = 400, AllRepairedBonusXP = 100 },
	Concert = { Duration = 110, TickInterval = 5, TickCash = 35, TickXP = 8, NPCShare = 0.55 },
	VIPNight = { Duration = 120, Resorts = 2, SpawnWeight = 4, SpendMultiplier = 2 },
	StreetRace = { Duration = 120 },
	LostAndFound = { Duration = 120, Items = 6, Cash = 120, XP = 25, AllFoundBonusCash = 300 },
}

----------------------------------------------------------------------
-- Daily tasks (reset at 00:00 UTC)
----------------------------------------------------------------------
Config.DailyTaskCount = 5
-- Every day the same 5 tasks are picked for everyone from this pool (all doable alone).
Config.DailyTaskPool = {
	{ Id = "races", Text = "Complete 3 races", Goal = 3, Cash = 1500, XP = 250 },
	{ Id = "visits", Text = "Visit 5 resorts or districts", Goal = 5, Cash = 800, XP = 150 },
	{ Id = "earn", Text = "Earn $10,000", Goal = 10000, Cash = 2000, XP = 300 },
	{ Id = "event", Text = "Participate in an event", Goal = 1, Cash = 1000, XP = 200 },
	{ Id = "minigames", Text = "Play 2 minigames", Goal = 2, Cash = 800, XP = 150 },
	{ Id = "deliveries", Text = "Complete 2 deliveries", Goal = 2, Cash = 1200, XP = 200 },
	{ Id = "upgrade", Text = "Upgrade a building", Goal = 1, Cash = 1500, XP = 250 },
	{ Id = "win", Text = "Win a Street Race", Goal = 1, Cash = 2000, XP = 300 },
	{ Id = "build", Text = "Place 3 buildings", Goal = 3, Cash = 1000, XP = 200 },
	{ Id = "npcvisits", Text = "Get 25 NPC visits at your resort", Goal = 25, Cash = 1500, XP = 250 },
	{ Id = "cardrush", Text = "Score 6+ in one Card Rush round", Goal = 1, Cash = 1200, XP = 200 },
}

----------------------------------------------------------------------
-- Cosmetics (car paints). Pure visuals, identical car stats for everyone.
----------------------------------------------------------------------
Config.Cosmetics = {
	{ Id = "paint_cyan", Name = "Cyber Cyan", Price = 0, Color = Color3.fromRGB(0, 235, 255) },
	{ Id = "paint_magenta", Name = "Hot Magenta", Price = 2000, Color = Color3.fromRGB(255, 40, 200) },
	{ Id = "paint_lime", Name = "Acid Lime", Price = 5000, Color = Color3.fromRGB(140, 255, 60) },
	{ Id = "paint_sunset", Name = "Sunset Orange", Price = 12000, Color = Color3.fromRGB(255, 120, 30) },
	{ Id = "paint_violet", Name = "Chrome Violet", Price = 30000, Color = Color3.fromRGB(150, 80, 255) },
	{ Id = "paint_gold", Name = "VIP Gold", Price = 0, Color = Color3.fromRGB(255, 200, 60), RequiresPass = "VIP" },
	{ Id = "body_muscle", Name = "Muscle Car body", Price = 15000, Color = Color3.fromRGB(200, 200, 215), IsBody = true, Style = "muscle" },
	{ Id = "body_drift", Name = "Drift Coupe body", Price = 40000, Color = Color3.fromRGB(200, 200, 215), IsBody = true, Style = "drift" },
	{ Id = "body_hyper", Name = "Neon Hyper Car body", Price = 0, Color = Color3.fromRGB(255, 255, 255), RequiresPass = "HyperCar", IsBody = true, Style = "hyper" },
}

----------------------------------------------------------------------
-- Monetization: clearly defined content only. No gambling, no pay-to-win.
-- Create the game passes on the Roblox website and paste their IDs here.
----------------------------------------------------------------------
Config.Monetization = {
	Passes = {
		VIP = {
			Id = 0,
			Name = "VIP Pass",
			PriceText = "399 R$",
			Perks = { "VIP overhead tag", "VIP Lounge access", "VIP Gold car paint", "VIP Neon Sign building" },
		},
		CyberPack = {
			Id = 0,
			Name = "Cyberpunk Pack",
			PriceText = "199 R$",
			Perks = { "Neon Sofa, Neon Arch, Cyber Lamp, Holo Sign", "Resort decorations only (no gameplay advantage)" },
		},
		HyperCar = {
			Id = 0,
			Name = "Neon Hyper Car",
			PriceText = "249 R$",
			Perks = { "Exclusive hyper car body (same speed as every car)" },
		},
	},
	-- When true, every pass counts as owned inside Roblox Studio so perks can be tested.
	GrantAllInStudio = true,
}

----------------------------------------------------------------------
-- Social
----------------------------------------------------------------------
Config.Social = {
	LikeCash = 100, -- the resort owner receives this per like
	LikeXP = 20,
	LikerXP = 5,
}

----------------------------------------------------------------------
-- Prestige
----------------------------------------------------------------------
Config.Prestige = {
	RequiredLevel = 100,
	-- Permanent reward: +10% resort income per prestige (capped), prestige star and titles.
	IncomeBonusPerPrestige = 0.1,
	MaxIncomeBonus = 1.0,
	Titles = { "Rising Star", "City Icon", "Neon Tycoon", "Resort Legend", "Neon Legend" },
}

----------------------------------------------------------------------
-- Player settings (booleans only, whitelisted)
----------------------------------------------------------------------
Config.DefaultSettings = {
	LowGraphics = false,
	ShowNPCLabels = true,
	Notifications = true,
	SoundEffects = true,
}

return Config
