-- Guide: a glowing beam from the player to a world position plus a bobbing marker.
-- Used by the tutorial and the delivery job. Only one guide is visible at a time.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Guide = {}

local player = Players.LocalPlayer
local active = nil -- { Marker, Beam, Attachment0, Connection, Target, Color }

function Guide.Hide()
	if active then
		active.Connection:Disconnect()
		active.Attachment0:Destroy()
		active.Marker:Destroy()
		active = nil
	end
end

local function attach(target, color)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local marker = Instance.new("Part")
	marker.Name = "GuideMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Shape = Enum.PartType.Ball
	marker.Material = Enum.Material.Neon
	marker.Color = color
	marker.Size = Vector3.new(3, 3, 3)
	marker.Position = target + Vector3.new(0, 6, 0)
	marker.Parent = workspace.CurrentCamera

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.5
	ring.Size = Vector3.new(0.3, 16, 16)
	ring.CFrame = CFrame.new(target + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = marker

	local attachment1 = Instance.new("Attachment")
	attachment1.Parent = marker
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "GuideAttachment"
	attachment0.Parent = root

	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.FaceCamera = true
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	beam.Transparency = NumberSequence.new(0.3)
	beam.Segments = 12
	beam.Parent = marker

	local base = marker.Position
	local connection = RunService.RenderStepped:Connect(function()
		marker.Position = base + Vector3.new(0, math.sin(os.clock() * 3) * 1.2, 0)
	end)
	active = { Marker = marker, Beam = beam, Attachment0 = attachment0, Connection = connection, Target = target, Color = color }
	return true
end

-- Shows a guide to `target` (Vector3). Retries briefly if the character is not ready yet.
function Guide.Show(target, color)
	Guide.Hide()
	if typeof(target) ~= "Vector3" then
		return
	end
	color = color or Color3.fromRGB(0, 235, 255)
	task.spawn(function()
		for _ = 1, 20 do
			if attach(target, color) then
				return
			end
			task.wait(0.5)
		end
	end)
end

function Guide.IsShowing()
	return active ~= nil
end

function Guide.CurrentTarget()
	return active and active.Target or nil
end

-- Re-attach to the new character after respawning.
player.CharacterAdded:Connect(function()
	if active then
		local target, color = active.Target, active.Color
		task.wait(1)
		Guide.Show(target, color)
	end
end)

return Guide
