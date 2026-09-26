-- Panels: only one big window is open at a time (keeps the screen readable on phones).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Signal)

local Panels = {}
Panels.Changed = Signal.new() -- (openName or nil)

local registry = {}
local openName = nil

-- handlers = { Open = function(...), Close = function() }
function Panels.Register(name, handlers)
	registry[name] = handlers
end

function Panels.Current()
	return openName
end

function Panels.Close()
	if openName then
		local handlers = registry[openName]
		openName = nil
		if handlers and handlers.Close then
			handlers.Close()
		end
		Panels.Changed:Fire(nil)
	end
end

function Panels.Open(name, ...)
	if openName == name then
		return
	end
	Panels.Close()
	local handlers = registry[name]
	if handlers then
		openName = name
		handlers.Open(...)
		Panels.Changed:Fire(name)
	end
end

function Panels.Toggle(name)
	if openName == name then
		Panels.Close()
	else
		Panels.Open(name)
	end
end

return Panels
