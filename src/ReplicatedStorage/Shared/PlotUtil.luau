-- NEON CITY: plot coordinate helpers (shared).
-- Plot-local space: origin = center of the plot's top surface, local -Z faces the avenue.

local Config = require(script.Parent.Config)

local PlotUtil = {}

function PlotUtil.Origin(plotModel)
	local base = plotModel:FindFirstChild("Base")
	local facing = plotModel:GetAttribute("Facing") or 0
	local top = base.Position + Vector3.new(0, base.Size.Y / 2, 0)
	return CFrame.new(top) * CFrame.Angles(0, math.rad(facing), 0)
end

function PlotUtil.BuildingCFrame(plotModel, x, z, rot)
	return PlotUtil.Origin(plotModel) * CFrame.new(x, 0, z) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

function PlotUtil.ToLocal(plotModel, worldPosition)
	local p = PlotUtil.Origin(plotModel):PointToObjectSpace(worldPosition)
	return p.X, p.Z
end

function PlotUtil.Contains(plotModel, worldPosition, margin)
	local x, z = PlotUtil.ToLocal(plotModel, worldPosition)
	local half = Config.PlotSize / 2 + (margin or 0)
	return math.abs(x) <= half and math.abs(z) <= half
end

-- Point on the avenue side of the plot, just outside its edge.
function PlotUtil.Entrance(plotModel)
	return (PlotUtil.Origin(plotModel) * CFrame.new(0, 0, -Config.PlotSize / 2 - 3)).Position
end

return PlotUtil
