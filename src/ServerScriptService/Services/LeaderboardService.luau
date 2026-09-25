-- LeaderboardService: the plaza leaderboard (server top players + global best race times).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local LeaderboardService = {}

local services
local raceStore = nil
local globalRace = {} -- { { Name, Time } }
local nameCache = {}
local labels

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Player " .. userId)
	return nameCache[userId]
end

function LeaderboardService.SubmitRaceTime(player, seconds)
	if not raceStore then
		return
	end
	local centis = math.floor(seconds * 100)
	task.spawn(function()
		pcall(function()
			raceStore:UpdateAsync(tostring(player.UserId), function(old)
				if old and old <= centis then
					return nil -- keep the existing, faster time
				end
				return centis
			end)
		end)
	end)
end

local function refreshGlobal()
	if not raceStore then
		return
	end
	local ok, pages = pcall(function()
		return raceStore:GetSortedAsync(true, 5)
	end)
	if not ok then
		return
	end
	local list = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(list, { Name = nameFor(userId), Time = entry.value / 100 })
		end
	end
	globalRace = list
end

local function createBoard()
	local board = workspace:FindFirstChild("City") and workspace.City.Plaza:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local function label(name, position, size, color, font, alignment)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.Position = position
		text.Size = size
		text.BackgroundTransparency = 1
		text.TextColor3 = color
		text.Font = font
		text.TextScaled = true
		text.TextWrapped = true
		text.TextXAlignment = alignment or Enum.TextXAlignment.Center
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Text = ""
		text.Parent = gui
		return text
	end
	labels = {
		Title = label("Title", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.1), Color3.fromRGB(0, 235, 255), Enum.Font.GothamBlack),
		Server = label("Server", UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.88, 0.46), Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Left),
		RaceTitle = label("RaceTitle", UDim2.fromScale(0.05, 0.64), UDim2.fromScale(0.9, 0.07), Color3.fromRGB(255, 70, 70), Enum.Font.GothamBlack),
		Race = label("Race", UDim2.fromScale(0.06, 0.72), UDim2.fromScale(0.88, 0.26), Color3.fromRGB(255, 220, 150), Enum.Font.GothamBold, Enum.TextXAlignment.Left),
	}
	labels.Title.Text = "TOP RESORT OWNERS"
	labels.RaceTitle.Text = "FASTEST STREET RACE"
end

local function updateBoard()
	if not labels then
		return
	end
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = services.DataService.Get(player)
		if data then
			table.insert(entries, { Name = player.DisplayName, Prestige = data.Prestige, Level = data.Level, XP = data.XP, Rating = player:GetAttribute("ResortRating") or 0 })
		end
	end
	table.sort(entries, function(a, b)
		if a.Prestige ~= b.Prestige then
			return a.Prestige > b.Prestige
		elseif a.Level ~= b.Level then
			return a.Level > b.Level
		end
		return a.XP > b.XP
	end)
	local lines = {}
	for i = 1, math.min(8, #entries) do
		local e = entries[i]
		local stars = e.Prestige > 0 and (" P" .. e.Prestige) or ""
		table.insert(lines, ("%d. %s  Lv %d%s  (rating %d)"):format(i, e.Name, e.Level, stars, e.Rating))
	end
	labels.Server.Text = #lines > 0 and table.concat(lines, "\n") or "Waiting for players..."

	local raceLines = {}
	for i, entry in ipairs(globalRace) do
		table.insert(raceLines, ("%d. %s  %s"):format(i, entry.Name, Format.RaceTime(entry.Time)))
	end
	labels.Race.Text = #raceLines > 0 and table.concat(raceLines, "\n") or "No records yet - be the first!"
end

function LeaderboardService.Init(allServices)
	services = allServices
	if services.DataService.IsPersistent() then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
		end)
		if ok then
			raceStore = store
		end
	end
end

function LeaderboardService.Start()
	createBoard()
	local lastGlobal = -math.huge
	while true do
		if os.clock() - lastGlobal > 120 then
			lastGlobal = os.clock()
			task.spawn(refreshGlobal)
		end
		updateBoard()
		task.wait(15)
	end
end

return LeaderboardService
