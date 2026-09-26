-- NEON CITY: first-time player tutorial steps (shared so the client can show the text).
-- Each step completes on a server-side event; rewards are granted by the server.

local Tutorial = {}

Tutorial.Steps = {
	{
		Id = "GoToResort",
		Text = "Welcome to NEON CITY! Follow the glowing beam to YOUR resort plot.",
		Guide = "Resort",
		Cash = 100,
		XP = 20,
	},
	{
		Id = "FirstBuilding",
		Text = "Press BUILD and place a Reception Kiosk on your plot.",
		Button = "Build",
		Cash = 150,
		XP = 30,
	},
	{
		Id = "SecondBuilding",
		Text = "Add a Snack Bar or a Neon Motel. Visitors spend money there!",
		Button = "Build",
		Cash = 200,
		XP = 40,
	},
	{
		Id = "FirstVisitor",
		Text = "Wait for an NPC visitor to spend money at your resort (look for +$).",
		Cash = 100,
		XP = 30,
		AutoCompleteAfter = 90,
	},
	{
		Id = "PlayMinigame",
		Text = "Earn extra cash: press PLAY and try Card Rush.",
		Button = "Play",
		Cash = 200,
		XP = 50,
	},
	{
		Id = "OpenTasks",
		Text = "Last step: open TASKS to see your daily goals.",
		Button = "Tasks",
		Cash = 500,
		XP = 100,
	},
}

Tutorial.Done = #Tutorial.Steps + 1

function Tutorial.IndexOf(id)
	for index, step in ipairs(Tutorial.Steps) do
		if step.Id == id then
			return index
		end
	end
	return nil
end

return Tutorial
