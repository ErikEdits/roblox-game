-- ShopPanel: car paints for in-game cash and clearly defined Robux game passes.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local ShopPanel = {}

local player = Players.LocalPlayer
local ctx, UI, C
local window, body, tab = nil, nil, "Paint"
local tabButtons = {}

local function renderPaints(data)
	local scroll = UI.Scroll({ Parent = body })
	UI.List(nil, 8).Parent = scroll
	for index, cosmetic in ipairs(Config.Cosmetics) do
		local owned = data.Cosmetics.Owned[cosmetic.Id] == true
		local passOwned = cosmetic.RequiresPass and data.Passes and data.Passes[cosmetic.RequiresPass]
		local usable = owned or passOwned
		local equipped
		if cosmetic.IsBody then
			local selected = data.Cosmetics.Body == "hyper" and "body_hyper" or data.Cosmetics.Body
			equipped = selected == cosmetic.Id
		else
			equipped = data.Cosmetics.Paint == cosmetic.Id
		end

		local row = UI.New("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -12, 0, 64),
			BackgroundColor3 = C.Panel,
			Parent = scroll,
		}, { UI.Corner(10), UI.Stroke(equipped and C.Lime or C.PanelLight, 2) })
		UI.New("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = cosmetic.Color,
			Parent = row,
		}, { UI.Corner(20) })
		UI.Label(cosmetic.Name, {
			Position = UDim2.fromOffset(66, 8),
			Size = UDim2.new(1, -300, 0, 26),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = row,
		})
		local sub
		if cosmetic.RequiresPass then
			sub = "Included with " .. Config.Monetization.Passes[cosmetic.RequiresPass].Name
		elseif cosmetic.Price == 0 then
			sub = "Free"
		else
			sub = Format.Money(cosmetic.Price)
		end
		UI.Label(sub, {
			Position = UDim2.fromOffset(66, 34),
			Size = UDim2.new(1, -300, 0, 22),
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 18,
			Parent = row,
		})

		local text, color, action
		if cosmetic.IsBody then
			if usable then
				text, color, action = equipped and "USING" or "USE", C.Lime, "Equip"
			elseif cosmetic.RequiresPass then
				text, color, action = "GET PASS", C.Violet, "Pass"
			else
				text, color, action = "BUY", C.Gold, "Buy"
			end
		elseif equipped then
			text, color = "EQUIPPED", C.Lime
		elseif usable then
			text, color, action = "EQUIP", C.Cyan, "Equip"
		elseif cosmetic.RequiresPass then
			text, color, action = "GET PASS", C.Violet, "Pass"
		else
			text, color, action = "BUY", C.Gold, "Buy"
		end
		local button = UI.Button(text, color, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 48),
			Parent = row,
		})
		button.Activated:Connect(function()
			if action == "Buy" then
				local ok, message = Remotes.Get("BuyCosmetic"):InvokeServer(cosmetic.Id)
				if not ok and message then
					ctx.HUD.Notify(tostring(message), "warning")
				end
			elseif action == "Equip" then
				Remotes.Get("EquipCosmetic"):InvokeServer(cosmetic.Id)
			elseif action == "Pass" then
				tab = "Robux"
				ShopPanel.Render()
			end
		end)
	end
end

local function renderPasses(data)
	UI.Label("Robux buy clearly defined content. No gambling, no random rewards, no pay-to-win.", {
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = C.SubText,
		MaxTextSize = 16,
		Parent = body,
	})
	local row = UI.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		Parent = body,
	}, { UI.List(Enum.FillDirection.Horizontal, 16) })
	for key, pass in pairs(Config.Monetization.Passes) do
		local owned = data.Passes and data.Passes[key]
		local style = ({ VIP = { C.Gold, 1 }, CyberPack = { C.Cyan, 2 }, HyperCar = { C.Magenta, 3 } })[key] or { C.Violet, 9 }
		local color = style[1]
		local passCount = 0
		for _ in pairs(Config.Monetization.Passes) do
			passCount += 1
		end
		local card = UI.New("Frame", {
			LayoutOrder = style[2],
			Size = UDim2.new(1 / passCount, -12, 1, 0),
			BackgroundColor3 = C.Panel,
			Parent = row,
		}, { UI.Corner(14), UI.Stroke(color, 2), UI.Padding(12) })
		UI.Label(pass.Name, {
			Size = UDim2.new(1, 0, 0, 36),
			Font = Enum.Font.GothamBlack,
			TextColor3 = color,
			MaxTextSize = 26,
			Parent = card,
		})
		UI.Label(pass.PriceText, {
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 0, 26),
			TextColor3 = C.Text,
			MaxTextSize = 22,
			Parent = card,
		})
		UI.Label("- " .. table.concat(pass.Perks, "\n- "), {
			Position = UDim2.fromOffset(0, 72),
			Size = UDim2.new(1, 0, 1, -150),
			Font = Enum.Font.GothamMedium,
			TextColor3 = C.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxTextSize = 18,
			Parent = card,
		})
		local button = UI.Button(owned and "OWNED" or "BUY", owned and C.Lime or color, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 60),
			Parent = card,
		})
		button.Activated:Connect(function()
			if owned then
				return
			end
			if pass.Id == 0 then
				ctx.HUD.Notify("This pass is not set up yet (add its ID in Config.Monetization).", "warning")
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	end
end

function ShopPanel.Render()
	if not window or not window.Visible then
		return
	end
	for name, button in pairs(tabButtons) do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		stroke.Color = name == tab and C.Gold or C.Cyan
	end
	UI.Clear(body)
	local data = ctx.State.Data
	if not data then
		return
	end
	if tab == "Paint" then
		renderPaints(data)
	else
		renderPasses(data)
	end
end

function ShopPanel.Start(context)
	ctx = context
	UI = ctx.UI
	C = UI.Colors

	local content, close
	window, content, close = UI.Window(ctx.Gui, "SHOP", C.Cyan, UDim2.fromOffset(780, 520))
	close.Activated:Connect(function()
		ctx.Panels.Close()
	end)
	local tabs = UI.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = content,
	}, { UI.List(Enum.FillDirection.Horizontal, 10) })
	for index, entry in ipairs({ { "Paint", "CAR STYLE" }, { "Robux", "ROBUX PASSES" } }) do
		local button = UI.Button(entry[2], C.Cyan, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(220, 44),
			Parent = tabs,
		})
		button.Activated:Connect(function()
			tab = entry[1]
			ShopPanel.Render()
		end)
		tabButtons[entry[1]] = button
	end
	body = UI.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		Parent = content,
	})

	ctx.Panels.Register("Shop", {
		Open = function()
			window.Visible = true
			ShopPanel.Render()
		end,
		Close = function()
			window.Visible = false
		end,
	})
	-- Re-render only when something shown in the shop changed (keeps the scroll position).
	local lastSignature = nil
	ctx.State.Changed:Connect(function(data)
		local signature = HttpService:JSONEncode({ data.Cosmetics, data.Passes or {} })
		if signature ~= lastSignature then
			lastSignature = signature
			ShopPanel.Render()
		end
	end)
end

return ShopPanel
