-- State: the client's read-only copy of server state. The server is the source of truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local State = {}
State.Data = nil -- latest player snapshot
State.Event = nil -- current event info
State.City = { Power = 100, Tourism = 50, Security = 90, Popularity = 50 }
State.Changed = Signal.new()
State.EventChanged = Signal.new()
State.CityChanged = Signal.new()

function State.Start()
	Remotes.Get("StateChanged").OnClientEvent:Connect(function(snapshot)
		State.Data = snapshot
		State.Changed:Fire(snapshot)
	end)
	Remotes.Get("EventState").OnClientEvent:Connect(function(info)
		State.Event = info
		State.EventChanged:Fire(info)
	end)
	Remotes.Get("CityStats").OnClientEvent:Connect(function(stats)
		State.City = stats
		State.CityChanged:Fire(stats)
	end)
	task.spawn(function()
		-- The server may still be loading our data; retry until it answers.
		for _ = 1, 30 do
			local ok, snapshot = pcall(function()
				return Remotes.Get("GetState"):InvokeServer()
			end)
			if ok and snapshot then
				if not State.Data then
					State.Data = snapshot
					State.Changed:Fire(snapshot)
				end
				return
			end
			task.wait(1)
		end
	end)
end

return State
