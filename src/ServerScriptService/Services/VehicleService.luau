-- VehicleService: free-roam cars. Players can spawn their own car to cruise the city.
-- Uses the same car as races (identical stats for everyone; paint/body are cosmetic).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local CarFactory = require(script.Parent.CarFactory)

local VehicleService = {}

local services
local cars = {} -- [player] = { Model, EmptySince }
local lastSpawn = {}
local folder

local EMPTY_DESPAWN = 45 -- seconds a free-roam car may stand without a driver

local function despawn(player)
	local entry = cars[player]
	if entry then
		cars[player] = nil
		if entry.Model.Parent then
			local seat = entry.Model:FindFirstChild("DriverSeat")
			local weld = seat and seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			entry.Model:Destroy()
		end
	end
end

function VehicleService.Despawn(player)
	despawn(player)
end

local function paintFor(player)
	local data = services.DataService.Get(player)
	local paint = Config.Cosmetics[1].Color
	local body = "standard"
	if data then
		for _, cosmetic in ipairs(Config.Cosmetics) do
			if cosmetic.Id == data.Cosmetics.Paint and not cosmetic.IsBody then
				paint = cosmetic.Color
			end
		end
		if data.Cosmetics.Body == "hyper" and services.MonetizationService.HasPass(player, "HyperCar") then
			body = "hyper"
		end
	end
	return paint, body
end

local function spawnCar(player)
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < 3 then
		return false, "Wait a moment"
	end
	if services.RaceService.IsRacing(player) then
		return false, "You are in a race"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, "No character"
	end
	lastSpawn[player] = now
	despawn(player)

	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local position = root.Position + flat * 10
	local cframe = CFrame.lookAt(Vector3.new(position.X, 0.5, position.Z), Vector3.new(position.X, 0.5, position.Z) + flat)

	local paint, body = paintFor(player)
	local car = CarFactory.Build(cframe, { Color = paint, Body = body, Name = player.Name .. "_Cruiser" })
	car:SetAttribute("OwnerId", player.UserId)
	car.Parent = folder
	cars[player] = { Model = car }

	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	local seat = car:FindFirstChild("DriverSeat")
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
	pcall(function()
		car.PrimaryPart:SetNetworkOwner(player)
	end)
	services.AnalyticsService.Log(player, "CarSpawned")
	return true
end

function VehicleService.Init(allServices)
	services = allServices
	folder = Instance.new("Folder")
	folder.Name = "CruiseCars"
	folder.Parent = workspace

	Remotes.Get("CarAction").OnServerInvoke = function(player, action)
		if action == "Spawn" then
			return spawnCar(player)
		elseif action == "Despawn" then
			despawn(player)
			return true
		end
		return false, "Unknown action"
	end

	Players.PlayerRemoving:Connect(function(player)
		despawn(player)
		lastSpawn[player] = nil
	end)
end

function VehicleService.Start()
	while true do
		task.wait(2)
		local now = os.clock()
		for player, entry in pairs(cars) do
			local seat = entry.Model:FindFirstChild("DriverSeat")
			local occupant = seat and seat.Occupant
			local character = player.Character
			local ownerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
			if occupant and occupant ~= ownerHumanoid then
				-- Only the owner drives their car.
				local weld = seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
				occupant = nil
			end
			if occupant then
				entry.EmptySince = nil
				if entry.Model.PrimaryPart and entry.Model.PrimaryPart.Position.Y < -30 then
					despawn(player) -- fell off the world
				end
			else
				entry.EmptySince = entry.EmptySince or now
				if now - entry.EmptySince > EMPTY_DESPAWN or not entry.Model.Parent then
					despawn(player)
				end
			end
		end
	end
end

return VehicleService
