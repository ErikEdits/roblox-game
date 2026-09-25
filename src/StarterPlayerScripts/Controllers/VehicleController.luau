-- VehicleController: arcade driving for NEON CITY race cars.
-- The server gives the driver network ownership, so the driver's client steers the car by
-- updating the car's LinearVelocity / AngularVelocity constraints. Input comes from the
-- VehicleSeat (WASD / arrow keys / gamepad / mobile thumbstick via the default controls).
-- All cars share Config.Race values: cosmetics never change speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local VehicleController = {}

local player = Players.LocalPlayer
local connection = nil

local function moveToward(value, target, maxDelta)
	if value < target then
		return math.min(value + maxDelta, target)
	end
	return math.max(value - maxDelta, target)
end

local function stopDriving(seat)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local chassis = seat and seat.Parent and seat.Parent:FindFirstChild("Chassis")
	if chassis then
		local drive = chassis:FindFirstChild("Drive")
		local turn = chassis:FindFirstChild("Turn")
		if drive then
			drive.PlaneVelocity = Vector2.zero
		end
		if turn then
			turn.AngularVelocity = Vector3.zero
		end
	end
end

local function startDriving(seat)
	stopDriving(nil)
	local chassis = seat.Parent:FindFirstChild("Chassis")
	local drive = chassis and chassis:FindFirstChild("Drive")
	local turn = chassis and chassis:FindFirstChild("Turn")
	if not drive or not turn then
		return
	end
	local race = Config.Race
	connection = RunService.Heartbeat:Connect(function(dt)
		if not seat.Parent or not chassis.Parent then
			stopDriving(nil)
			return
		end
		local look = chassis.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			return
		end
		flat = flat.Unit

		local locked = seat:GetAttribute("Locked") == true or chassis.Anchored
		local throttle = locked and 0 or seat.ThrottleFloat
		local steer = locked and 0 or seat.SteerFloat

		local forward = chassis.AssemblyLinearVelocity:Dot(flat)
		local target = 0
		if throttle > 0 then
			target = throttle * race.CarMaxSpeed
		elseif throttle < 0 then
			target = throttle * race.CarReverseSpeed
		end
		local rate
		if throttle == 0 then
			rate = race.CarCoastDecel
		elseif math.sign(target) ~= math.sign(forward) and math.abs(forward) > 1 then
			rate = race.CarBraking
		else
			rate = race.CarAcceleration
		end
		if locked then
			rate = race.CarBraking
		end
		forward = moveToward(forward, target, rate * dt)

		local velocity = flat * forward
		drive.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
		local grip = math.clamp(math.abs(forward) / 25, 0, 1)
		local direction = forward >= 0 and 1 or -1
		turn.AngularVelocity = Vector3.new(0, -steer * race.CarTurnRate * grip * direction, 0)
	end)
end

local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(function(active, seat)
		if active and seat and seat:IsA("VehicleSeat") and seat:GetAttribute("NeonCar") then
			startDriving(seat)
		else
			stopDriving(seat)
		end
	end)
end

function VehicleController.Start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return VehicleController
