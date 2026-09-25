-- AnalyticsService: lightweight gameplay analytics.
-- Sends custom events to Roblox's analytics dashboard (Creator Hub > Analytics > Custom) and keeps
-- per-server counters that are printed in Studio for quick balancing checks.

local RobloxAnalytics = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local AnalyticsService = {}

local counters = {}

-- name: short CamelCase event name, e.g. "BuildingPlaced". fields: optional table (Studio print only).
function AnalyticsService.Log(player, name, fields)
	counters[name] = (counters[name] or 0) + 1
	if RunService:IsStudio() then
		return
	end
	if player and player.Parent then
		pcall(function()
			RobloxAnalytics:LogCustomEvent(player, name, 1)
		end)
	end
	local _ = fields
end

function AnalyticsService.Counters()
	return counters
end

function AnalyticsService.Start()
	if not RunService:IsStudio() then
		return
	end
	-- Studio: print a compact summary every 5 minutes.
	while true do
		task.wait(300)
		local parts = {}
		for name, count in pairs(counters) do
			table.insert(parts, name .. "=" .. count)
		end
		table.sort(parts)
		if #parts > 0 then
			print("[Analytics] " .. table.concat(parts, "  "))
		end
	end
end

return AnalyticsService
