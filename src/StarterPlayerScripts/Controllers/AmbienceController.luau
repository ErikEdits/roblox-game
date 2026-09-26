-- AmbienceController: cheap client-side life for the city (runs at ~20 Hz, not per frame).
--   Anim = "Blink" : antenna lights blink
--   Anim = "Pulse" : billboard frames pulse
--   Anim = "Spin"  : holograms rotate
-- Hologram buildings placed by players pulse too. Disabled with the Low graphics setting.

local AmbienceController = {}

local CollectionTargets = {}

local ctx
local enabled = true

local function register(part)
	local anim = part:GetAttribute("Anim")
	if anim then
		table.insert(CollectionTargets, { Part = part, Anim = anim, Base = part.CFrame, Transparency = part.Transparency, Phase = math.random() * 6 })
	end
end

local function scan(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			register(descendant)
		end
	end
end

function AmbienceController.Start(context)
	ctx = context
	local city = workspace:WaitForChild("City", 10)
	if city then
		scan(city)
	end
	ctx.State.Changed:Connect(function(data)
		enabled = not (data and data.Settings and data.Settings.LowGraphics)
		local plaza = city and city:FindFirstChild("Plaza")
		local column = plaza and plaza:FindFirstChild("FountainColumn")
		local spray = column and column:FindFirstChild("Spray", true)
		if spray then
			spray.Enabled = enabled
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.05)
			if enabled then
				local t = os.clock()
				for index = #CollectionTargets, 1, -1 do
					local target = CollectionTargets[index]
					local part = target.Part
					if not part.Parent then
						table.remove(CollectionTargets, index)
					elseif target.Anim == "Blink" then
						part.Transparency = (math.floor(t + target.Phase) % 2 == 0) and 0 or 0.85
					elseif target.Anim == "Pulse" then
						part.Transparency = 0.35 + 0.35 * math.sin(t * 2.5 + target.Phase)
					elseif target.Anim == "Spin" then
						part.CFrame = target.Base * CFrame.Angles(0, (t * 0.8) % (math.pi * 2), 0)
					end
				end
			end
		end
	end)

	-- Event items (e.g. lost wallets) appear directly in workspace.
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") and child:GetAttribute("Anim") then
			register(child)
		end
	end)

	-- Hologram buildings placed by players: pulse their orb locally.
	local plots = workspace:WaitForChild("Plots", 10)
	if plots then
		plots.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") and descendant.Name == "Orb" then
				task.defer(function()
					local model = descendant:FindFirstAncestorOfClass("Model")
					if model and model:GetAttribute("BuildingId") then
						descendant:SetAttribute("Anim", "Pulse")
						register(descendant)
					end
				end)
			end
		end)
	end
end

return AmbienceController
