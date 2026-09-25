--!nocheck
-- Minimal Roblox engine emulation on top of Lune's roblox library.
-- Real Instances + reflection-validated properties; events, services, humanoid movement,
-- remotes and datastores are emulated so server + client code can run in one process.

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local ltask = require("@lune/task")

local Engine = {}
Engine.Errors = {}
Engine.Logs = {}
Engine.Verbose = false

local function recordError(where, err)
	local message = tostring(where) .. ": " .. tostring(err)
	for _, existing in ipairs(Engine.Errors) do
		if existing == message then
			return
		end
	end
	table.insert(Engine.Errors, message)
	print("\27[31m[ERROR]\27[0m " .. message)
end
Engine.RecordError = recordError

local Instance = roblox.Instance
local impl = roblox.implementMethod

-- Lune userdata identity is not guaranteed across GC, so key per-instance state by an id attribute.
local nextId = 0
local function idOf(instance)
	local id = instance:GetAttribute("__SimId")
	if not id then
		nextId += 1
		id = nextId
		instance:SetAttribute("__SimId", id)
	end
	return id
end
Engine.IdOf = idOf
local prop = roblox.implementProperty

----------------------------------------------------------------------
-- task wrapper that records errors from spawned threads
----------------------------------------------------------------------
local function handler(err)
	local ok, trace = pcall(debug.traceback, tostring(err), 2)
	return ok and trace or tostring(err)
end
Engine.Handler = handler

local function guard(fn, label)
	return function(...)
		local ok, err = xpcall(fn, handler, ...)
		if not ok then
			recordError(label or "thread", err)
		end
	end
end

local Task = {}
function Task.spawn(fn, ...)
	if type(fn) == "thread" then
		return ltask.spawn(fn, ...)
	end
	return ltask.spawn(guard(fn, "task.spawn"), ...)
end
function Task.defer(fn, ...)
	if type(fn) == "thread" then
		return ltask.defer(fn, ...)
	end
	return ltask.defer(guard(fn, "task.defer"), ...)
end
function Task.delay(t, fn, ...)
	return ltask.delay(t, guard(fn, "task.delay"), ...)
end
function Task.wait(t)
	return ltask.wait(t or 0.03)
end
Task.cancel = ltask.cancel
Engine.Task = Task

----------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new(name)
	return setmetatable({ Name = name, Handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local entry = { Fn = fn, Connected = true }
	table.insert(self.Handlers, entry)
	local connection = { Connected = true }
	function connection.Disconnect()
		entry.Connected = false
		connection.Connected = false
	end
	connection.disconnect = connection.Disconnect
	return connection
end
Signal.connect = Signal.Connect
function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end
function Signal:Wait()
	local thread = coroutine.running()
	local done = false
	self:Once(function(...)
		if not done then
			done = true
			ltask.spawn(thread, ...)
		end
	end)
	return coroutine.yield()
end
function Signal:Fire(...)
	for _, entry in ipairs(table.clone(self.Handlers)) do
		if entry.Connected then
			ltask.spawn(guard(entry.Fn, "signal " .. tostring(self.Name)), ...)
		end
	end
end
Engine.Signal = Signal

local signalStore = {}
local function signalOf(instance, name)
	local key = idOf(instance)
	local bucket = signalStore[key]
	if not bucket then
		bucket = {}
		signalStore[key] = bucket
	end
	if not bucket[name] then
		bucket[name] = Signal.new(tostring(instance) .. "." .. name)
	end
	return bucket[name]
end
Engine.SignalOf = signalOf

local EVENTS = {
	Instance = { "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Destroying", "AttributeChanged", "Changed" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	Player = { "CharacterAdded", "CharacterRemoving" },
	BasePart = { "Touched", "TouchEnded" },
	ProximityPrompt = { "Triggered", "PromptShown", "PromptHidden" },
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	Humanoid = { "Running", "Seated", "MoveToFinished", "Died", "StateChanged" },
	RunService = { "Heartbeat", "RenderStepped", "Stepped" },
	MarketplaceService = { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished" },
	GuiButton = { "Activated", "MouseButton1Click" },
	UserInputService = { "InputBegan", "InputEnded", "InputChanged", "TouchTapInWorld" },
}
for class, names in pairs(EVENTS) do
	for _, name in ipairs(names) do
		prop(class, name, function(self)
			return signalOf(self, name)
		end)
	end
end

impl("Instance", "GetPropertyChangedSignal", function(self, name)
	return signalOf(self, "Prop:" .. name)
end)
impl("Instance", "GetAttributeChangedSignal", function(self, name)
	return signalOf(self, "Attr:" .. name)
end)
impl("Instance", "WaitForChild", function(self, name, timeout)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		local child = self:FindFirstChild(name)
		if child then
			return child
		end
		ltask.wait(0.05)
	end
	if timeout then
		return nil
	end
	recordError("WaitForChild", "infinite yield on " .. self:GetFullName() .. "." .. name)
	return nil
end)

----------------------------------------------------------------------
-- Properties that have no default value in the reflection database
----------------------------------------------------------------------
local storedProps = {}
function Engine.DefaultedProperty(class, name, default)
	prop(class, name, function(self)
		local bucket = storedProps[idOf(self)]
		local value = bucket and bucket[name]
		if value == nil then
			return default
		end
		return value
	end, function(self, value)
		local key = idOf(self)
		storedProps[key] = storedProps[key] or {}
		storedProps[key][name] = value
	end)
end
Engine.DefaultedProperty("Humanoid", "Health", 100)
Engine.DefaultedProperty("Humanoid", "MaxHealth", 100)

----------------------------------------------------------------------
-- Geometry helpers
----------------------------------------------------------------------
local CFrame, Vector3, Vector2 = roblox.CFrame, roblox.Vector3, roblox.Vector2

prop("BasePart", "Position", function(self)
	return self.CFrame.Position
end, function(self, value)
	self.CFrame = self.CFrame.Rotation + value
end)
prop("BasePart", "AssemblyLinearVelocity", function()
	return Vector3.new(0, 0, 0)
end, function() end)
prop("BasePart", "AssemblyAngularVelocity", function()
	return Vector3.new(0, 0, 0)
end, function() end)

local function modelParts(model)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function modelPivot(model)
	local primary = model.PrimaryPart
	if primary then
		return primary.CFrame
	end
	local parts = modelParts(model)
	if parts[1] then
		return parts[1].CFrame
	end
	return CFrame.new()
end
impl("Model", "GetPivot", modelPivot)
impl("Model", "PivotTo", function(self, target)
	local current = modelPivot(self)
	local delta = target * current:Inverse()
	for _, part in ipairs(modelParts(self)) do
		part.CFrame = delta * part.CFrame
	end
end)
impl("BasePart", "GetPivot", function(self)
	return self.CFrame
end)
impl("BasePart", "PivotTo", function(self, target)
	self.CFrame = target
end)
impl("BasePart", "SetNetworkOwner", function(self, owner)
	if self.Anchored then
		error("Cannot call SetNetworkOwner on an anchored part")
	end
end)
impl("BasePart", "GetMass", function(self)
	return self.Size.X * self.Size.Y * self.Size.Z
end)
impl("Model", "GetExtentsSize", function(self)
	return Vector3.new(4, 5, 2)
end)

----------------------------------------------------------------------
-- Humanoids: kinematic movement toward MoveTo targets
----------------------------------------------------------------------
local humanoidState = {} -- [id] = state (state.Humanoid = instance)
local function hstate(h)
	local key = idOf(h)
	local s = humanoidState[key]
	if not s then
		s = { Target = nil, SeatPart = nil, States = {}, Humanoid = h }
		humanoidState[key] = s
	end
	return s
end
impl("Humanoid", "MoveTo", function(self, target)
	hstate(self).Target = target
	hstate(self).Started = os.clock()
end)
impl("Humanoid", "SetStateEnabled", function(self, state, enabled)
	hstate(self).States[state] = enabled
end)
impl("Humanoid", "GetState", function()
	return roblox.Enum.HumanoidStateType.Running
end)
impl("Humanoid", "ChangeState", function() end)
impl("Humanoid", "TakeDamage", function(self, amount)
	self.Health -= amount
end)
prop("Humanoid", "SeatPart", function(self)
	return hstate(self).SeatPart
end, function() end)
prop("Humanoid", "Sit", function(self)
	return hstate(self).SeatPart ~= nil
end, function(self, value)
	if not value then
		Engine.Unseat(self)
	end
end)
prop("Humanoid", "RootPart", function(self)
	return self.Parent and self.Parent:FindFirstChild("HumanoidRootPart")
end, function() end)

local occupantById = {}
local seatOccupant = setmetatable({}, {
	__index = function(_, seat)
		return occupantById[idOf(seat)]
	end,
	__newindex = function(_, seat, value)
		occupantById[idOf(seat)] = value
	end,
})
prop("Seat", "Occupant", function(self)
	return seatOccupant[self]
end, function() end)
prop("VehicleSeat", "Occupant", function(self)
	return seatOccupant[self]
end, function() end)

function Engine.Unseat(humanoid)
	local seat = hstate(humanoid).SeatPart
	if seat then
		hstate(humanoid).SeatPart = nil
		pcall(function()
			seatOccupant[seat] = nil
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end)
		signalOf(humanoid, "Seated"):Fire(false, nil)
	end
end

local function sit(seat, humanoid)
	if seatOccupant[seat] then
		return
	end
	hstate(humanoid).SeatPart = seat
	seatOccupant[seat] = humanoid
	local weld = Instance.new("Weld")
	weld.Name = "SeatWeld"
	weld.Part0 = seat
	weld.Part1 = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	weld.Parent = seat
	signalOf(humanoid, "Seated"):Fire(true, seat)
end
impl("VehicleSeat", "Sit", sit)
impl("Seat", "Sit", sit)

local animTracks = {}
impl("Animator", "LoadAnimation", function(self, animation)
	local track = { Looped = false, IsPlaying = false }
	function track:Play()
		self.IsPlaying = true
	end
	function track:Stop()
		self.IsPlaying = false
	end
	function track:AdjustSpeed() end
	table.insert(animTracks, track)
	return track
end)

-- Detect removal of the SeatWeld (server destroys it to eject).
function Engine.StepHumanoids(dt)
	for _, s in pairs(humanoidState) do
		local humanoid = s.Humanoid
		local seat = s.SeatPart
		local seatGone = seat and (not seat.Parent or not pcall(function()
			assert(seat:FindFirstChild("SeatWeld"))
		end))
		if seatGone then
			s.SeatPart = nil
			pcall(function()
				seatOccupant[seat] = nil
			end)
			signalOf(humanoid, "Seated"):Fire(false, nil)
		end
		local model = humanoid.Parent
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if s.Target and root and model:IsDescendantOf(Engine.Game.Workspace) then
			local position = root.Position
			local flat = Vector3.new(s.Target.X - position.X, 0, s.Target.Z - position.Z)
			local distance = flat.Magnitude
			local step = humanoid.WalkSpeed * dt
			if distance <= math.max(step, 0.5) then
				model:PivotTo(CFrame.new(Vector3.new(s.Target.X, position.Y, s.Target.Z)))
				s.Target = nil
				signalOf(humanoid, "Running"):Fire(0)
				signalOf(humanoid, "MoveToFinished"):Fire(true)
			else
				local direction = flat.Unit
				local newPosition = position + direction * step
				model:PivotTo(CFrame.lookAt(newPosition, newPosition + direction))
				if not s.Running then
					s.Running = true
					signalOf(humanoid, "Running"):Fire(humanoid.WalkSpeed)
				end
			end
			if s.Target == nil then
				s.Running = false
			elseif os.clock() - (s.Started or 0) > 8 then
				s.Target = nil
				s.Running = false
				signalOf(humanoid, "MoveToFinished"):Fire(false)
			end
		end
	end
end

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------
-- DataStores (in memory, shared across the run)
local stores = {}
local function makeStore(name, ordered)
	stores[name] = stores[name] or { Data = {}, Ordered = ordered }
	local store = stores[name]
	local api = {}
	function api:GetAsync(key)
		ltask.wait(0.01)
		local value = store.Data[key]
		return value and luau.load("return " .. value)() or nil
	end
	local serde = require("@lune/serde")
	local function encode(value)
		local json = serde.encode("json", value)
		-- round trip through JSON like Roblox does
		return "(" .. "require_json(" .. string.format("%q", json) .. "))"
	end
	function api:SetAsync(key, value)
		store.Data[key] = value ~= nil and serde.encode("json", value) or nil
	end
	function api:UpdateAsync(key, fn)
		local old = store.Data[key] and serde.decode("json", store.Data[key]) or nil
		local new = fn(old)
		if new ~= nil then
			store.Data[key] = serde.encode("json", new)
		end
		return new
	end
	function api:GetAsync(key)
		ltask.wait(0.01)
		return store.Data[key] and serde.decode("json", store.Data[key]) or nil
	end
	function api:GetSortedAsync(ascending, pageSize)
		local entries = {}
		for key, value in pairs(store.Data) do
			table.insert(entries, { key = key, value = serde.decode("json", value) })
		end
		table.sort(entries, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local page = { table.unpack(entries, 1, pageSize) }
		return { GetCurrentPage = function()
			return page
		end, IsFinished = true }
	end
	local _ = encode
	return api
end
Engine.Stores = stores
impl("DataStoreService", "GetDataStore", function(_, name)
	if Engine.DataStoreDisabled then
		error("You must publish this place to the web to access DataStore.")
	end
	return makeStore(name, false)
end)
impl("DataStoreService", "GetOrderedDataStore", function(_, name)
	return makeStore(name, true)
end)

impl("DataModel", "BindToClose", function(_, fn)
	Engine.CloseHandlers = Engine.CloseHandlers or {}
	table.insert(Engine.CloseHandlers, fn)
end)
impl("PhysicsService", "RegisterCollisionGroup", function() end)
impl("PhysicsService", "CollisionGroupSetCollidable", function() end)

impl("MarketplaceService", "UserOwnsGamePassAsync", function()
	return false
end)
impl("MarketplaceService", "PromptGamePassPurchase", function() end)

impl("AnalyticsService", "LogCustomEvent", function() end)

impl("RunService", "IsStudio", function()
	return true
end)
impl("RunService", "IsServer", function()
	return true
end)
impl("RunService", "IsClient", function()
	return true
end)

impl("GuiService", "GetGuiInset", function()
	return Vector2.new(0, 58), Vector2.new(0, 0)
end)

prop("UserInputService", "TouchEnabled", function()
	return Engine.Mobile == true
end, function() end)
prop("UserInputService", "KeyboardEnabled", function()
	return not Engine.Mobile
end, function() end)
prop("UserInputService", "MouseEnabled", function()
	return not Engine.Mobile
end, function() end)
impl("UserInputService", "GetMouseLocation", function()
	return Vector2.new(640, 400)
end)

impl("TweenService", "Create", function(_, instance, info, goals)
	return {
		Play = function()
			for key, value in pairs(goals) do
				instance[key] = value
			end
		end,
		Cancel = function() end,
		Completed = Signal.new("TweenCompleted"),
	}
end)

-- Players
prop("Players", "LocalPlayer", function()
	return Engine.LocalPlayer
end, function() end)
local characterById = {}
local playerCharacter = setmetatable({}, {
	__index = function(_, player)
		return characterById[idOf(player)]
	end,
	__newindex = function(_, player, value)
		characterById[idOf(player)] = value
	end,
})
prop("Player", "Character", function(self)
	return playerCharacter[self]
end, function(self, value)
	playerCharacter[self] = value
end)
impl("Players", "GetPlayers", function(self)
	local list = {}
	for _, child in ipairs(self:GetChildren()) do
		if child:IsA("Player") then
			table.insert(list, child)
		end
	end
	return list
end)
impl("Players", "GetPlayerFromCharacter", function(self, character)
	for _, player in ipairs(self:GetChildren()) do
		if player:IsA("Player") and playerCharacter[player] == character then
			return player
		end
	end
	return nil
end)
impl("Players", "GetPlayerByUserId", function(self, userId)
	for _, player in ipairs(self:GetChildren()) do
		if player:IsA("Player") and player.UserId == userId then
			return player
		end
	end
	return nil
end)
impl("Players", "GetNameFromUserIdAsync", function(_, userId)
	return "User" .. userId
end)
impl("Players", "CreateHumanoidModelFromDescription", function()
	error("CreateHumanoidModelFromDescription is not available in the simulator")
end)

-- Workspace
impl("Workspace", "GetServerTimeNow", function()
	return os.clock() + 1000000
end)
impl("Workspace", "Raycast", function()
	return nil
end)
local camera
prop("Workspace", "CurrentCamera", function(self)
	if not camera then
		camera = Instance.new("Camera")
		camera.Name = "Camera"
		camera.Parent = self
	end
	return camera
end, function() end)
prop("Camera", "ViewportSize", function()
	return Engine.Viewport or Vector2.new(1280, 720)
end, function() end)
impl("Camera", "ViewportPointToRay", function(self, x, y)
	-- Look straight down from 200 studs above the point mapped to the plot area.
	local origin = Engine.RayOrigin or Vector3.new(0, 200, 0)
	return roblox.Ray.new(origin, Vector3.new(0, -1, 0))
end)
impl("Camera", "ScreenPointToRay", function(self, x, y)
	local origin = Engine.RayOrigin or Vector3.new(0, 200, 0)
	return roblox.Ray.new(origin, Vector3.new(0, -1, 0))
end)

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------
local callbackById = {}
local remoteCallbacks = setmetatable({}, {
	__index = function(_, remote)
		return callbackById[idOf(remote)]
	end,
	__newindex = function(_, remote, value)
		callbackById[idOf(remote)] = value
	end,
})
prop("RemoteFunction", "OnServerInvoke", function(self)
	return remoteCallbacks[self]
end, function(self, fn)
	remoteCallbacks[self] = fn
end)
prop("RemoteFunction", "OnClientInvoke", function()
	return nil
end, function() end)
impl("RemoteFunction", "InvokeServer", function(self, ...)
	local deadline = os.clock() + 5
	while not remoteCallbacks[self] and os.clock() < deadline do
		ltask.wait(0.05)
	end
	local fn = remoteCallbacks[self]
	if not fn then
		recordError("InvokeServer", self.Name .. " has no OnServerInvoke")
		return nil
	end
	local results = table.pack(xpcall(fn, handler, Engine.LocalPlayer, ...))
	if not results[1] then
		recordError("OnServerInvoke " .. self.Name, results[2])
		return nil
	end
	return table.unpack(results, 2, results.n)
end)
local function deepCopyForRemote(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		error("cyclic table sent through remote")
	end
	seen[value] = true
	local copy = {}
	local hasNumeric, hasString = false, false
	for k, v in pairs(value) do
		if type(k) == "number" then
			hasNumeric = true
		elseif type(k) == "string" then
			hasString = true
		else
			error("unsupported key type in remote payload: " .. type(k))
		end
		copy[k] = deepCopyForRemote(v, seen)
	end
	if hasNumeric and hasString then
		error("mixed table (array + dictionary) sent through remote")
	end
	seen[value] = nil
	return copy
end
Engine.RemotePayloads = {}
impl("RemoteEvent", "FireClient", function(self, player, ...)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		error("FireClient: first argument must be a Player")
	end
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = deepCopyForRemote(args[i])
	end
	Engine.RemotePayloads[self.Name] = (Engine.RemotePayloads[self.Name] or 0) + 1
	if player == Engine.LocalPlayer then
		signalOf(self, "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
	end
end)
impl("RemoteEvent", "FireAllClients", function(self, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = deepCopyForRemote(args[i])
	end
	Engine.RemotePayloads[self.Name] = (Engine.RemotePayloads[self.Name] or 0) + 1
	signalOf(self, "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
end)
impl("RemoteEvent", "FireServer", function(self, ...)
	signalOf(self, "OnServerEvent"):Fire(Engine.LocalPlayer, ...)
end)

----------------------------------------------------------------------
-- Globals + script loading
----------------------------------------------------------------------
local RaycastParams = {}
function RaycastParams.new()
	return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false }
end
local TweenInfo = {}
function TweenInfo.new(...)
	return { ... }
end

local moduleCacheById = {}
local moduleCache = setmetatable({}, {
	__index = function(_, module)
		return moduleCacheById[idOf(module)]
	end,
	__newindex = function(_, module, value)
		moduleCacheById[idOf(module)] = value
	end,
})

function Engine.MakeEnv(scriptInstance)
	local env = {}
	env.game = Engine.Game
	env.workspace = Engine.Game.Workspace
	env.script = scriptInstance
	env.task = Task
	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		local text = table.concat(parts, " ")
		table.insert(Engine.Logs, "WARN " .. text)
		if Engine.Verbose then
			print("[warn] " .. text)
		end
	end
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		table.insert(Engine.Logs, table.concat(parts, " "))
		if Engine.Verbose then
			print(...)
		end
	end
	env.Instance = { new = function(className, parent)
		local instance = Instance.new(className)
		if parent then
			instance.Parent = parent
		end
		return instance
	end }
	for _, name in ipairs({ "CFrame", "Vector3", "Vector2", "Color3", "UDim", "UDim2", "Enum", "ColorSequence", "NumberSequence", "NumberRange", "PhysicalProperties", "BrickColor", "Ray", "Rect", "Font", "ColorSequenceKeypoint", "NumberSequenceKeypoint" }) do
		env[name] = roblox[name]
	end
	env.RaycastParams = RaycastParams
	env.TweenInfo = TweenInfo
	env.require = function(target)
		if typeof(target) ~= "Instance" or not target:IsA("ModuleScript") then
			error("require expects a ModuleScript, got " .. tostring(target))
		end
		if moduleCache[target] ~= nil then
			return moduleCache[target]
		end
		local fn = luau.load(target.Source, { debugName = target:GetFullName(), environment = Engine.MakeEnv(target) })
		local result = fn()
		if result == nil then
			error("module returned nil: " .. target:GetFullName())
		end
		moduleCache[target] = result
		return result
	end
	setmetatable(env, { __index = _G })
	return env
end

function Engine.Require(moduleInstance)
	return Engine.MakeEnv(nil).require(moduleInstance)
end

function Engine.RunScript(scriptInstance)
	local fn = luau.load(scriptInstance.Source, { debugName = scriptInstance:GetFullName(), environment = Engine.MakeEnv(scriptInstance) })
	Task.spawn(fn)
end

function Engine.Load(path)
	Engine.Game = roblox.deserializePlace(fs.readFile(path))
	for _, name in ipairs({ "Players", "RunService", "DataStoreService", "PhysicsService", "MarketplaceService", "AnalyticsService", "TweenService", "UserInputService", "GuiService", "ServerStorage", "HttpService" }) do
		Engine.Game:GetService(name)
	end
	-- heartbeat loop
	Task.spawn(function()
		local last = os.clock()
		local runService = Engine.Game:GetService("RunService")
		while not Engine.Stopped do
			ltask.wait(1 / 30)
			local now = os.clock()
			local dt = now - last
			last = now
			Engine.StepHumanoids(dt)
			signalOf(runService, "Heartbeat"):Fire(dt)
			signalOf(runService, "RenderStepped"):Fire(dt)
		end
	end)
	return Engine.Game
end

-- HttpService JSONEncode for client signature code
local serde = require("@lune/serde")
impl("HttpService", "JSONEncode", function(_, value)
	return serde.encode("json", value)
end)
impl("HttpService", "JSONDecode", function(_, value)
	return serde.decode("json", value)
end)
impl("HttpService", "GenerateGUID", function()
	return tostring(math.random(1, 1e9))
end)

----------------------------------------------------------------------
-- Players / characters
----------------------------------------------------------------------
function Engine.MakeCharacter(player, position)
	local model = Instance.new("Model")
	model.Name = player.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(position)
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = 22
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = Engine.Game.Workspace
	player.Character = model
	signalOf(player, "CharacterAdded"):Fire(model)
	return model
end

function Engine.AddPlayer(userId, name)
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	local playerGui = Instance.new("PlayerGui")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = player
	player.Parent = Engine.Game:GetService("Players")
	signalOf(Engine.Game:GetService("Players"), "PlayerAdded"):Fire(player)
	return player
end

function Engine.RemovePlayer(player)
	signalOf(Engine.Game:GetService("Players"), "PlayerRemoving"):Fire(player)
	ltask.wait(0.3)
	local character = player.Character
	if character then
		character:Destroy()
	end
	player.Parent = nil
end

-- Find a GuiButton by exact text under a root (for simulated clicks).
function Engine.FindButton(root, text)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiButton") and d:IsA("TextButton") and d.Text == text then
			return d
		end
	end
	return nil
end

function Engine.Click(button)
	signalOf(button, "Activated"):Fire()
end

return Engine
