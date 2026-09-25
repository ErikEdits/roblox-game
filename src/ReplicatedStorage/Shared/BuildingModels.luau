-- NEON CITY: procedural, low-part building models.
-- Phase 1 art direction: simple shapes, strong silhouettes, neon accents, no meshes.
-- Used by the server (real buildings) and the client (placement ghost), so both always match.
-- Swap a style builder for a detailed model later without touching gameplay code.

local Buildings = require(script.Parent.Buildings)

local BuildingModels = {}

local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis upright

local function darken(color, factor)
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function newPart(ctx, name, size, localCFrame, color, material, extra)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = ctx.Origin * localCFrame
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CastShadow = false
	if extra then
		for key, value in pairs(extra) do
			part[key] = value
		end
	end
	part.Parent = ctx.Model
	return part
end

local function addLabel(ctx, part, text, face, color)
	if ctx.Ghost then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Parent = gui
	gui.Parent = part
end

----------------------------------------------------------------------
-- Style builders. Local space: ground center at (0, 0, 0), front faces -Z.
----------------------------------------------------------------------
local Styles = {}

function Styles.box(ctx, def, w, d, h)
	newPart(ctx, "Body", Vector3.new(w - 0.4, h, d - 0.4), CFrame.new(0, h / 2, 0), def.Color)
	newPart(ctx, "Roof", Vector3.new(w, 0.8, d), CFrame.new(0, h + 0.4, 0), darken(def.Color, 0.6))
	newPart(ctx, "NeonBand", Vector3.new(w, 0.6, d), CFrame.new(0, h * 0.82, 0), def.Accent, Enum.Material.Neon)
	newPart(ctx, "Windows", Vector3.new(w * 0.8, h * 0.22, 0.3), CFrame.new(0, h * 0.5, -d / 2 + 0.05), Color3.fromRGB(60, 200, 255), Enum.Material.Glass, { Transparency = 0.25 })
	newPart(ctx, "Door", Vector3.new(math.min(6, w * 0.4), 7, 0.3), CFrame.new(0, 3.5, -d / 2 + 0.05), Color3.fromRGB(20, 30, 45), Enum.Material.Glass, { Transparency = 0.2 })
	local sign = newPart(ctx, "Sign", Vector3.new(w * 0.7, 2.4, 0.4), CFrame.new(0, h * 0.5 + h * 0.11 + 1.6, -d / 2 - 0.1), darken(def.Accent, 0.25))
	addLabel(ctx, sign, string.upper(def.Name), Enum.NormalId.Front, def.Accent)
end

function Styles.tower(ctx, def, w, d, h)
	newPart(ctx, "Body", Vector3.new(w - 0.6, h, d - 0.6), CFrame.new(0, h / 2, 0), def.Color)
	local floors = math.clamp(math.floor(h / 8), 1, 8)
	for i = 1, floors do
		local y = (i - 0.5) * (h / floors)
		newPart(ctx, "Floor" .. i, Vector3.new(w - 0.2, 1.4, d - 0.2), CFrame.new(0, y, 0), Color3.fromRGB(70, 190, 255), Enum.Material.Glass, { Transparency = 0.3 })
	end
	newPart(ctx, "Crown", Vector3.new(w, 1, d), CFrame.new(0, h + 0.5, 0), def.Accent, Enum.Material.Neon)
	newPart(ctx, "Spire", Vector3.new(1, h * 0.25, 1), CFrame.new(0, h + h * 0.125, 0), def.Accent, Enum.Material.Neon)
	newPart(ctx, "Door", Vector3.new(8, 8, 0.3), CFrame.new(0, 4, -d / 2 + 0.2), Color3.fromRGB(20, 30, 45), Enum.Material.Glass, { Transparency = 0.2 })
	local sign = newPart(ctx, "Sign", Vector3.new(w * 0.8, 3, 0.4), CFrame.new(0, 10.5, -d / 2), darken(def.Accent, 0.25))
	addLabel(ctx, sign, string.upper(def.Name), Enum.NormalId.Front, def.Accent)
end

function Styles.garage(ctx, def, w, d, h)
	newPart(ctx, "Body", Vector3.new(w - 0.4, h, d - 0.4), CFrame.new(0, h / 2, 0), def.Color, Enum.Material.Metal)
	newPart(ctx, "Roof", Vector3.new(w, 0.8, d), CFrame.new(0, h + 0.4, 0), darken(def.Color, 0.6))
	newPart(ctx, "RollDoor", Vector3.new(w * 0.7, h * 0.65, 0.3), CFrame.new(0, h * 0.325, -d / 2 + 0.05), Color3.fromRGB(90, 90, 100), Enum.Material.DiamondPlate)
	newPart(ctx, "Stripe", Vector3.new(w, 0.8, d), CFrame.new(0, h * 0.8, 0), def.Accent, Enum.Material.Neon)
	local sign = newPart(ctx, "Sign", Vector3.new(w * 0.6, 2.2, 0.4), CFrame.new(0, h * 0.8 + 1.8, -d / 2 - 0.1), darken(def.Accent, 0.25))
	addLabel(ctx, sign, "GARAGE", Enum.NormalId.Front, def.Accent)
end

function Styles.parking(ctx, def, w, d, _h)
	newPart(ctx, "Asphalt", Vector3.new(w, 0.3, d), CFrame.new(0, 0.15, 0), def.Color, Enum.Material.Asphalt)
	local lines = math.max(2, math.floor(w / 5))
	for i = 1, lines - 1 do
		local x = -w / 2 + i * (w / lines)
		newPart(ctx, "Line" .. i, Vector3.new(0.3, 0.05, d * 0.45), CFrame.new(x, 0.32, d * 0.2), def.Accent)
	end
	newPart(ctx, "Pole", Vector3.new(0.5, 7, 0.5), CFrame.new(-w / 2 + 1, 3.5, -d / 2 + 1), Color3.fromRGB(60, 60, 70))
	local sign = newPart(ctx, "PSign", Vector3.new(3, 3, 0.4), CFrame.new(-w / 2 + 1, 8, -d / 2 + 1), Color3.fromRGB(0, 110, 255), Enum.Material.Neon)
	addLabel(ctx, sign, "P", Enum.NormalId.Front, Color3.new(1, 1, 1))
end

function Styles.palm(ctx, def, _w, _d, h)
	newPart(ctx, "Trunk", Vector3.new(h, 1.2, 1.2), CFrame.new(0, h / 2, 0) * VERTICAL, def.Color, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	for i = 0, 2 do
		newPart(ctx, "Leaf" .. i, Vector3.new(9, 0.3, 1.6), CFrame.new(0, h, 0) * CFrame.Angles(0, i * math.pi / 3, math.rad(-12)), def.Accent, Enum.Material.Neon)
	end
end

function Styles.lamp(ctx, def, _w, _d, h)
	newPart(ctx, "Base", Vector3.new(1.6, 0.6, 1.6), CFrame.new(0, 0.3, 0), def.Color)
	newPart(ctx, "Pole", Vector3.new(0.5, h, 0.5), CFrame.new(0, h / 2, 0), def.Color, Enum.Material.Metal)
	newPart(ctx, "Head", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, h + 0.6, 0), def.Accent, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
end

function Styles.sign(ctx, def, w, _d, h)
	newPart(ctx, "PostL", Vector3.new(0.6, h, 0.6), CFrame.new(-w / 2 + 1, h / 2, 0), def.Color, Enum.Material.Metal)
	newPart(ctx, "PostR", Vector3.new(0.6, h, 0.6), CFrame.new(w / 2 - 1, h / 2, 0), def.Color, Enum.Material.Metal)
	local panel = newPart(ctx, "Panel", Vector3.new(w, 4, 0.6), CFrame.new(0, h - 2, 0), def.Color)
	newPart(ctx, "Frame", Vector3.new(w + 0.4, 4.4, 0.4), CFrame.new(0, h - 2, 0), def.Accent, Enum.Material.Neon)
	addLabel(ctx, panel, def.SignText or "NEON", Enum.NormalId.Front, def.Accent)
	addLabel(ctx, panel, def.SignText or "NEON", Enum.NormalId.Back, def.Accent)
end

function Styles.fountain(ctx, def, w, _d, h)
	newPart(ctx, "Basin", Vector3.new(h * 0.5, w, w), CFrame.new(0, h * 0.25, 0) * VERTICAL, def.Color, Enum.Material.Marble, { Shape = Enum.PartType.Cylinder })
	newPart(ctx, "Water", Vector3.new(0.2, w - 1.5, w - 1.5), CFrame.new(0, h * 0.5 + 0.05, 0) * VERTICAL, def.Accent, Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.3 })
	newPart(ctx, "Column", Vector3.new(h * 1.5, 1.6, 1.6), CFrame.new(0, h * 0.75, 0) * VERTICAL, def.Color, Enum.Material.Marble, { Shape = Enum.PartType.Cylinder })
	newPart(ctx, "Glow", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, h * 1.5 + 0.8, 0), def.Accent, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
end

function Styles.pool(ctx, def, w, d, _h)
	newPart(ctx, "Deck", Vector3.new(w, 1, d), CFrame.new(0, 0.5, 0), def.Color, Enum.Material.Concrete)
	newPart(ctx, "Water", Vector3.new(w - 3, 0.2, d - 3), CFrame.new(0, 1.05, 0), def.Accent, Enum.Material.Glass, { Transparency = 0.2 })
	newPart(ctx, "Glow", Vector3.new(w - 2.6, 0.1, d - 2.6), CFrame.new(0, 0.95, 0), def.Accent, Enum.Material.Neon)
end

function Styles.hologram(ctx, def, w, _d, h)
	newPart(ctx, "Pedestal", Vector3.new(2, w, w), CFrame.new(0, 1, 0) * VERTICAL, def.Color, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	newPart(ctx, "Ring", Vector3.new(0.4, w + 0.4, w + 0.4), CFrame.new(0, 2.1, 0) * VERTICAL, def.Accent, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })
	newPart(ctx, "Beam", Vector3.new(h - 6, 1.2, 1.2), CFrame.new(0, 2 + (h - 6) / 2, 0) * VERTICAL, def.Accent, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.5 })
	newPart(ctx, "Orb", Vector3.new(w * 0.7, w * 0.7, w * 0.7), CFrame.new(0, h - w * 0.35, 0), def.Accent, Enum.Material.Neon, { Shape = Enum.PartType.Ball, Transparency = 0.35 })
end

function Styles.arena(ctx, def, w, d, h)
	newPart(ctx, "Floor", Vector3.new(w, 0.4, d), CFrame.new(0, 0.2, 0), darken(def.Color, 0.7), Enum.Material.Concrete)
	newPart(ctx, "Field", Vector3.new(w * 0.55, 0.1, d * 0.55), CFrame.new(0, 0.45, 0), def.Accent, Enum.Material.Neon, { Transparency = 0.4 })
	local wall = 2
	local gap = 10
	local seg = (w - gap) / 2
	newPart(ctx, "WallN", Vector3.new(w, h, wall), CFrame.new(0, h / 2, d / 2 - wall / 2), def.Color)
	newPart(ctx, "WallE", Vector3.new(wall, h, d), CFrame.new(w / 2 - wall / 2, h / 2, 0), def.Color)
	newPart(ctx, "WallW", Vector3.new(wall, h, d), CFrame.new(-w / 2 + wall / 2, h / 2, 0), def.Color)
	newPart(ctx, "WallS1", Vector3.new(seg, h, wall), CFrame.new(-w / 2 + seg / 2, h / 2, -d / 2 + wall / 2), def.Color)
	newPart(ctx, "WallS2", Vector3.new(seg, h, wall), CFrame.new(w / 2 - seg / 2, h / 2, -d / 2 + wall / 2), def.Color)
	newPart(ctx, "Rim", Vector3.new(w + 0.4, 0.8, d + 0.4), CFrame.new(0, h + 0.4, 0), def.Accent, Enum.Material.Neon, { Transparency = 0 })
end

function Styles.helipad(ctx, def, w, _d, h)
	newPart(ctx, "Pad", Vector3.new(h, w, w), CFrame.new(0, h / 2, 0) * VERTICAL, def.Color, Enum.Material.Concrete, { Shape = Enum.PartType.Cylinder })
	newPart(ctx, "Ring", Vector3.new(0.2, w - 2, w - 2), CFrame.new(0, h + 0.05, 0) * VERTICAL, def.Accent, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })
	newPart(ctx, "Inner", Vector3.new(0.22, w - 3, w - 3), CFrame.new(0, h + 0.06, 0) * VERTICAL, def.Color, Enum.Material.Concrete, { Shape = Enum.PartType.Cylinder })
	newPart(ctx, "H1", Vector3.new(1.2, 0.1, 7), CFrame.new(-2.5, h + 0.2, 0), def.Accent, Enum.Material.Neon)
	newPart(ctx, "H2", Vector3.new(1.2, 0.1, 7), CFrame.new(2.5, h + 0.2, 0), def.Accent, Enum.Material.Neon)
	newPart(ctx, "H3", Vector3.new(4, 0.1, 1.2), CFrame.new(0, h + 0.2, 0), def.Accent, Enum.Material.Neon)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

-- Rotation (0..3 quarter turns) as a CFrame.
function BuildingModels.RotationCFrame(rot)
	return CFrame.Angles(0, rot * math.pi / 2, 0)
end

-- Builds a model whose ground-center is at `origin` (a CFrame that already includes rotation).
-- options.Ghost = true makes a see-through, non-colliding preview.
function BuildingModels.Build(id, origin, options)
	options = options or {}
	local def = Buildings.Get(id)
	assert(def, "Unknown building " .. tostring(id))

	local model = Instance.new("Model")
	model.Name = def.Name

	local w, d, h = def.Size[1], def.Size[2], def.Height
	local ctx = { Model = model, Origin = origin, Ghost = options.Ghost }

	local root = newPart(ctx, "Root", Vector3.new(w, math.max(h, 1), d), CFrame.new(0, math.max(h, 1) / 2, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
	})
	model.PrimaryPart = root

	local builder = Styles[def.Style] or Styles.box
	builder(ctx, def, w, d, h)

	if options.Ghost then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				if descendant ~= root then
					descendant.Transparency = math.max(descendant.Transparency, 0.45)
				end
			end
		end
	end

	return model
end

-- Moves an existing model built by Build() to a new ground-center origin.
function BuildingModels.MoveTo(model, id, origin)
	local def = Buildings.Get(id)
	model:PivotTo(origin * CFrame.new(0, math.max(def.Height, 1) / 2, 0))
end

-- Tints a ghost model green (valid) or red (invalid).
function BuildingModels.TintGhost(model, valid)
	local color = valid and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 70, 70)
	local highlight = model:FindFirstChild("GhostHighlight")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "GhostHighlight"
		highlight.FillTransparency = 0.6
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end
	highlight.FillColor = color
	highlight.OutlineColor = color
end

return BuildingModels
