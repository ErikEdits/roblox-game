-- NEON CITY: placement math on a plot (pure functions, shared by server and client).
-- Coordinates are plot-local studs: (0, 0) is the plot center, X/Z in [-PlotSize/2, PlotSize/2].

local Config = require(script.Parent.Config)
local Buildings = require(script.Parent.Buildings)

local Placement = {}

-- Snaps a footprint center so that the footprint edges land on the grid.
function Placement.Snap(value, footprintSize)
	local grid = Config.GridSize
	local half = footprintSize / 2
	local edge = math.floor((value - half) / grid + 0.5) * grid
	return edge + half
end

function Placement.Clamp(value, footprintSize)
	local limit = Config.PlotSize / 2 - footprintSize / 2
	return math.clamp(value, -limit, limit)
end

-- Snap + clamp a desired position into a valid grid position inside the plot.
function Placement.Normalize(def, x, z, rot)
	local w, d = Buildings.Footprint(def, rot)
	x = Placement.Snap(Placement.Clamp(x, w), w)
	z = Placement.Snap(Placement.Clamp(z, d), d)
	return x, z
end

local function overlaps(ax, az, aw, ad, bx, bz, bw, bd)
	return math.abs(ax - bx) * 2 < (aw + bw) and math.abs(az - bz) * 2 < (ad + bd)
end

-- existing: array of { Id, X, Z, R, Uid }
function Placement.IsValid(def, x, z, rot, existing, ignoreUid)
	if rot ~= 0 and rot ~= 1 and rot ~= 2 and rot ~= 3 then
		return false, "Invalid rotation"
	end
	local w, d = Buildings.Footprint(def, rot)
	local half = Config.PlotSize / 2
	if math.abs(x) + w / 2 > half + 0.01 or math.abs(z) + d / 2 > half + 0.01 then
		return false, "Outside your plot"
	end
	for _, other in ipairs(existing) do
		if other.Uid ~= ignoreUid then
			local otherDef = Buildings.Get(other.Id)
			if otherDef then
				local ow, od = Buildings.Footprint(otherDef, other.R)
				if overlaps(x, z, w, d, other.X, other.Z, ow, od) then
					return false, "Overlaps " .. otherDef.Name
				end
			end
		end
	end
	return true, nil
end

return Placement
