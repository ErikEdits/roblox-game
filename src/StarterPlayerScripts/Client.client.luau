-- NEON CITY client bootstrap. Builds the UI and starts every controller.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local controllers = script.Parent:WaitForChild("Controllers")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local UI = require(controllers.UI)
local State = require(controllers.State)
local Panels = require(controllers.Panels)
local HUD = require(controllers.HUD)

local gui = Instance.new("ScreenGui")
gui.Name = "NeonCityUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Scale the 1280x720 design canvas to any screen (phones included).
local scale = Instance.new("UIScale")
scale.Parent = gui
local function updateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.25)
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local ctx = { UI = UI, State = State, Panels = Panels, HUD = HUD, Gui = gui }

State.Start()
HUD.Start(ctx)
for _, name in ipairs({ "BuildController", "PlayPanel", "ShopPanel", "Menus", "RaceHUD", "VehicleController", "TutorialController", "ReflexPanel", "JobController", "AmbienceController" }) do
	local ok, err = pcall(function()
		require(controllers[name]).Start(ctx)
	end)
	if not ok then
		warn("[NEON CITY] controller " .. name .. " failed: " .. tostring(err))
	end
end

-- World prompts (kiosks) open panels.
Remotes.Get("OpenUI").OnClientEvent:Connect(function(panel)
	if type(panel) == "string" then
		Panels.Open(panel)
	end
end)
