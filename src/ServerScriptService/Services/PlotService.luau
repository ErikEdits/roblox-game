-- PlotService: every player receives one resort plot for the session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local PlotUtil = require(Shared.PlotUtil)
local Progression = require(Shared.Progression)

local PlotService = {}

local services
local plots = {} -- array of { Index, Model, Owner }
local byPlayer = {} -- [player] = plot

local function setSignText(plot, text)
	local sign = plot.Model:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("Label")
	local label = gui and gui:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = text
	end
end

function PlotService.UpdateSign(player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	local resortLevel = player:GetAttribute("ResortLevel") or 1
	local name = Progression.ResortLevelNames[resortLevel]
	setSignText(plot, ("%s'S\n%s\n%s"):format(string.upper(player.DisplayName), string.upper(name), string.rep("⭐", resortLevel)))
end

function PlotService.GetPlot(player)
	return byPlayer[player]
end

function PlotService.GetPlots()
	return plots
end

function PlotService.GetOwnerAt(worldPosition)
	for _, plot in ipairs(plots) do
		if plot.Owner and PlotUtil.Contains(plot.Model, worldPosition, 0) then
			return plot.Owner, plot
		end
	end
	return nil, nil
end

function PlotService.SpawnCFrame(player)
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	-- Stand just inside the avenue side of the plot, looking into the resort.
	local origin = PlotUtil.Origin(plot.Model)
	local spot = (origin * CFrame.new(0, 4, -Config.PlotSize / 2 + 6)).Position
	local center = origin.Position
	return CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
end

function PlotService.Init(allServices)
	services = allServices

	local folder = workspace:WaitForChild("Plots")
	for _, plotModel in ipairs(folder:GetChildren()) do
		table.insert(plots, { Index = plotModel:GetAttribute("Index") or 0, Model = plotModel, Owner = nil })
	end
	table.sort(plots, function(a, b)
		return a.Index < b.Index
	end)

	services.DataService.PlayerLoaded:Connect(function(player)
		for _, plot in ipairs(plots) do
			if not plot.Owner then
				plot.Owner = player
				byPlayer[player] = plot
				player:SetAttribute("PlotIndex", plot.Index)
				PlotService.UpdateSign(player)
				return
			end
		end
		services.EconomyService.Notify(player, "All plots are taken on this server.", "error")
	end)

	services.DataService.AddSnapshotProvider(function(player, snapshot)
		local plot = byPlayer[player]
		snapshot.PlotIndex = plot and plot.Index or nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		local plot = byPlayer[player]
		if plot then
			plot.Owner = nil
			byPlayer[player] = nil
			setSignText(plot, ("PLOT %d\nFREE"):format(plot.Index))
		end
	end)
end

return PlotService
