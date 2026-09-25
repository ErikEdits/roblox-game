-- CarFactory: builds simple, performant neon cars (Phase 1 art: a handful of parts).
-- Every body style has IDENTICAL physics. Cosmetics never change speed (no pay-to-win).
--
-- Player cars: VehicleSeat + LinearVelocity/AngularVelocity driven by the owner's client
-- (see StarterPlayerScripts/Controllers/VehicleController).
-- NPC cars: AlignPosition/AlignOrientation targets set by the server.

local CarFactory = {}

local function weld(root, part)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = part
end

local function newPart(model, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Massless = true
	part.CastShadow = false
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

-- cframe: ground-level position/orientation of the car's center.
-- options: { Color = Color3, Body = "standard" | "hyper", NPC = bool, Name = string }
function CarFactory.Build(cframe, options)
	local model = Instance.new("Model")
	model.Name = options.Name or "NeonCar"
	local color = options.Color or Color3.fromRGB(0, 235, 255)
	local hyper = options.Body == "hyper"

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(7, 1.6, 12)
	chassis.CFrame = cframe * CFrame.new(0, 1.3, 0)
	chassis.Color = Color3.fromRGB(25, 25, 32)
	chassis.Material = Enum.Material.Metal
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	-- The flat chassis does not collide: rounded skids front/back glide over curbs and small steps.
	chassis.CanCollide = false
	chassis.Parent = model
	model.PrimaryPart = chassis

	if not options.NPC then
		for _, z in ipairs({ -4.6, 4.6 }) do
			local skid = Instance.new("Part")
			skid.Name = "Skid"
			skid.Shape = Enum.PartType.Cylinder
			skid.Size = Vector3.new(7, 1.6, 1.6) -- cylinder axis = X (across the car)
			skid.CFrame = chassis.CFrame * CFrame.new(0, 0, z)
			skid.Transparency = 1
			skid.CanCollide = true
			skid.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
			skid.Parent = model
			local skidWeld = Instance.new("WeldConstraint")
			skidWeld.Part0 = chassis
			skidWeld.Part1 = skid
			skidWeld.Parent = skid
		end
	end

	local base = chassis.CFrame
	local bodyHeight = hyper and 1.1 or 1.5
	local body = newPart(model, "Body", Vector3.new(6.6, bodyHeight, 11), base * CFrame.new(0, 0.8 + bodyHeight / 2, 0), color)
	local cabin = newPart(model, "Cabin", Vector3.new(5, hyper and 1.2 or 1.6, hyper and 4 or 5),
		base * CFrame.new(0, 0.8 + bodyHeight + (hyper and 0.6 or 0.8), hyper and 1 or 0.5),
		Color3.fromRGB(30, 40, 60), Enum.Material.Glass)
	cabin.Transparency = 0.3
	local glow = newPart(model, "Underglow", Vector3.new(6.4, 0.2, 10.5), base * CFrame.new(0, -0.85, 0), color, Enum.Material.Neon)
	local stripe = newPart(model, "Stripe", Vector3.new(1.2, 0.1, 11.1), base * CFrame.new(0, 0.8 + bodyHeight + 0.02, 0), Color3.new(1, 1, 1), Enum.Material.Neon)
	local parts = { body, cabin, glow, stripe }

	if hyper then
		table.insert(parts, newPart(model, "Spoiler", Vector3.new(6.8, 0.3, 1.6), base * CFrame.new(0, 3.1, 5.2), color, Enum.Material.Neon))
		table.insert(parts, newPart(model, "SpoilerL", Vector3.new(0.3, 1, 0.8), base * CFrame.new(-2.8, 2.5, 5.2), Color3.fromRGB(25, 25, 32)))
		table.insert(parts, newPart(model, "SpoilerR", Vector3.new(0.3, 1, 0.8), base * CFrame.new(2.8, 2.5, 5.2), Color3.fromRGB(25, 25, 32)))
	end
	table.insert(parts, newPart(model, "HeadlightL", Vector3.new(1.4, 0.5, 0.2), base * CFrame.new(-2.2, 1.3, -5.55), Color3.new(1, 1, 0.85), Enum.Material.Neon))
	table.insert(parts, newPart(model, "HeadlightR", Vector3.new(1.4, 0.5, 0.2), base * CFrame.new(2.2, 1.3, -5.55), Color3.new(1, 1, 0.85), Enum.Material.Neon))
	table.insert(parts, newPart(model, "TaillightL", Vector3.new(1.4, 0.5, 0.2), base * CFrame.new(-2.2, 1.3, 5.55), Color3.fromRGB(255, 30, 60), Enum.Material.Neon))
	table.insert(parts, newPart(model, "TaillightR", Vector3.new(1.4, 0.5, 0.2), base * CFrame.new(2.2, 1.3, 5.55), Color3.fromRGB(255, 30, 60), Enum.Material.Neon))

	for _, offset in ipairs({ Vector3.new(-3.6, 0.4, -3.8), Vector3.new(3.6, 0.4, -3.8), Vector3.new(-3.6, 0.4, 3.8), Vector3.new(3.6, 0.4, 3.8) }) do
		table.insert(parts, newPart(model, "Wheel", Vector3.new(1.2, 2.4, 2.4), base * CFrame.new(offset), Color3.fromRGB(15, 15, 18), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	end
	for _, part in ipairs(parts) do
		weld(chassis, part)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = chassis

	if options.NPC then
		local align = Instance.new("AlignPosition")
		align.Name = "Follow"
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.MaxForce = 1e7
		align.Responsiveness = 60
		align.Position = chassis.Position
		align.Parent = chassis

		local orient = Instance.new("AlignOrientation")
		orient.Name = "Face"
		orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orient.Attachment0 = attachment
		orient.MaxTorque = 1e7
		orient.Responsiveness = 40
		orient.CFrame = chassis.CFrame.Rotation
		orient.Parent = chassis
	else
		local seat = Instance.new("VehicleSeat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2, 1, 2)
		seat.CFrame = base * CFrame.new(0, 0.8 + bodyHeight + 0.5, 0.8)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Massless = true
		seat.HeadsUpDisplay = false
		seat.MaxSpeed = 0
		seat.Torque = 0
		seat:SetAttribute("NeonCar", true)
		seat.Parent = model
		weld(chassis, seat)

		local drive = Instance.new("LinearVelocity")
		drive.Name = "Drive"
		drive.Attachment0 = attachment
		drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		drive.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		drive.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		drive.RelativeTo = Enum.ActuatorRelativeTo.World
		drive.MaxForce = 2e5
		drive.PlaneVelocity = Vector2.new(0, 0)
		drive.Parent = chassis

		local turn = Instance.new("AngularVelocity")
		turn.Name = "Turn"
		turn.Attachment0 = attachment
		turn.RelativeTo = Enum.ActuatorRelativeTo.World
		turn.MaxTorque = 1e6
		turn.AngularVelocity = Vector3.new(0, 0, 0)
		turn.Parent = chassis
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = options.NPC and "GhostCars" or "Cars"
		end
	end
	return model
end

return CarFactory
