-- NEON CITY: building catalog.
-- Size = footprint in studs (must be multiples of Config.GridSize).
-- Appeal = how attractive this building is per NPC type (0 = ignored by that type).
-- Spend = cash an NPC spends per visit (before type multiplier).
-- Passive = cash per PassiveIncomeInterval from resort operations.
-- Rating = contribution to the resort rating (resort level 1-5).

local Buildings = {}

Buildings.Categories = { "Buildings", "Entertainment", "Outdoor", "Lights", "Decoration", "Parking", "Nature" }

Buildings.List = {
	-- Level 1 starters ------------------------------------------------
	{
		Id = "reception", Name = "Reception Kiosk", Category = "Buildings", Style = "box",
		Cost = 300, Size = { 12, 12 }, Height = 10, Level = 1,
		Color = Color3.fromRGB(40, 44, 70), Accent = Color3.fromRGB(0, 235, 255),
		Appeal = { Tourist = 2, Business = 2, Luxury = 1 }, Spend = 15, Passive = 6, Rating = 2,
		Description = "Welcomes visitors. Every resort starts here.",
	},
	{
		Id = "snack_bar", Name = "Snack Bar", Category = "Buildings", Style = "box",
		Cost = 500, Size = { 12, 12 }, Height = 9, Level = 1,
		Color = Color3.fromRGB(70, 35, 55), Accent = Color3.fromRGB(255, 60, 170),
		Appeal = { Tourist = 3, Family = 4, Racer = 2, Event = 2 }, Spend = 22, Passive = 8, Rating = 2,
		Description = "Quick food for hungry tourists and families.",
	},
	{
		Id = "motel", Name = "Neon Motel", Category = "Buildings", Style = "box",
		Cost = 1200, Size = { 20, 16 }, Height = 14, Level = 1,
		Color = Color3.fromRGB(45, 40, 80), Accent = Color3.fromRGB(255, 90, 60),
		Appeal = { Tourist = 5, Family = 3, Racer = 2 }, Spend = 40, Passive = 15, Rating = 4,
		Description = "Small rooms, big neon. Tourists love it.",
	},
	{
		Id = "parking", Name = "Parking Lot", Category = "Parking", Style = "parking",
		Cost = 400, Size = { 20, 20 }, Height = 1, Level = 1,
		Color = Color3.fromRGB(30, 30, 38), Accent = Color3.fromRGB(240, 240, 255),
		Appeal = { Racer = 3, Business = 2, Tourist = 1 }, Spend = 10, Passive = 5, Rating = 1,
		Description = "Visitors need somewhere to park.",
	},
	{
		Id = "palm", Name = "Neon Palm", Category = "Nature", Style = "palm",
		Cost = 150, Size = { 4, 4 }, Height = 14, Level = 1,
		Color = Color3.fromRGB(110, 75, 50), Accent = Color3.fromRGB(60, 255, 150),
		Appeal = {}, Spend = 0, Passive = 1, Rating = 1,
		Description = "Glowing palm tree. Boosts resort rating.",
	},
	{
		Id = "lamp", Name = "Neon Lamp", Category = "Lights", Style = "lamp",
		Cost = 100, Size = { 4, 4 }, Height = 10, Level = 1,
		Color = Color3.fromRGB(50, 50, 60), Accent = Color3.fromRGB(255, 220, 120),
		Appeal = {}, Spend = 0, Passive = 1, Rating = 1,
		Description = "Street lamp with warm neon glow.",
	},
	-- Early unlocks -------------------------------------------------------
	{
		Id = "neon_sign", Name = "Neon Sign", Category = "Decoration", Style = "sign",
		Cost = 600, Size = { 12, 4 }, Height = 10, Level = 2,
		Color = Color3.fromRGB(30, 30, 40), Accent = Color3.fromRGB(255, 50, 220), SignText = "OPEN",
		Appeal = {}, Spend = 0, Passive = 3, Rating = 2,
		Description = "Tells the whole city you are open for business.",
	},
	{
		Id = "restaurant", Name = "Diner", Category = "Buildings", Style = "box",
		Cost = 3500, Size = { 24, 20 }, Height = 12, Level = 3,
		Color = Color3.fromRGB(60, 30, 40), Accent = Color3.fromRGB(255, 70, 70),
		Appeal = { Tourist = 4, Family = 6, Business = 3, Racer = 2 }, Spend = 80, Passive = 30, Rating = 6,
		Description = "Retro diner with the best milkshakes in NEON CITY.",
	},
	{
		Id = "fountain", Name = "Fountain", Category = "Outdoor", Style = "fountain",
		Cost = 2000, Size = { 12, 12 }, Height = 4, Level = 4,
		Color = Color3.fromRGB(200, 200, 215), Accent = Color3.fromRGB(0, 200, 255),
		Appeal = { Family = 2, Tourist = 2 }, Spend = 5, Passive = 6, Rating = 4,
		Description = "A calm spot visitors enjoy.",
	},
	{
		Id = "arcade", Name = "Arcade", Category = "Entertainment", Style = "box",
		Cost = 6000, Size = { 24, 24 }, Height = 16, Level = 5,
		Color = Color3.fromRGB(35, 20, 70), Accent = Color3.fromRGB(140, 255, 60),
		Appeal = { Family = 7, Tourist = 3, Racer = 3, Event = 3 }, Spend = 120, Passive = 45, Rating = 8,
		Description = "Skill games for families and kids.",
	},
	{
		Id = "pool", Name = "Pool", Category = "Outdoor", Style = "pool",
		Cost = 8000, Size = { 24, 16 }, Height = 2, Level = 7,
		Color = Color3.fromRGB(220, 220, 230), Accent = Color3.fromRGB(0, 180, 255),
		Appeal = { Tourist = 5, Luxury = 4, Family = 4 }, Spend = 90, Passive = 35, Rating = 8,
		Description = "Glowing pool. Luxury guests approve.",
	},
	{
		Id = "hotel", Name = "Hotel Tower", Category = "Buildings", Style = "tower",
		Cost = 15000, Size = { 24, 24 }, Height = 40, Level = 8,
		Color = Color3.fromRGB(35, 40, 75), Accent = Color3.fromRGB(0, 235, 255),
		Appeal = { Tourist = 7, Business = 6, Luxury = 3 }, Spend = 250, Passive = 90, Rating = 14,
		Description = "A real hotel. More rooms, more guests.",
	},
	{
		Id = "garage", Name = "Tuning Garage", Category = "Entertainment", Style = "garage",
		Cost = 12000, Size = { 24, 20 }, Height = 12, Level = 10,
		Color = Color3.fromRGB(45, 45, 50), Accent = Color3.fromRGB(255, 60, 60),
		Appeal = { Racer = 10, Business = 1 }, Spend = 220, Passive = 70, Rating = 10,
		Description = "Racers come from all over the city to tune their cars.",
	},
	{
		Id = "vip_lounge", Name = "VIP Lounge", Category = "Entertainment", Style = "box",
		Cost = 40000, Size = { 20, 20 }, Height = 14, Level = 15,
		Color = Color3.fromRGB(25, 20, 30), Accent = Color3.fromRGB(255, 200, 60),
		Appeal = { Luxury = 10, Business = 4 }, Spend = 600, Passive = 180, Rating = 18,
		Description = "Exclusive lounge that attracts luxury tourists.",
	},
	{
		Id = "hologram", Name = "Hologram Statue", Category = "Decoration", Style = "hologram",
		Cost = 25000, Size = { 8, 8 }, Height = 16, Level = 18,
		Color = Color3.fromRGB(40, 40, 55), Accent = Color3.fromRGB(0, 255, 230),
		Appeal = { Tourist = 2, Event = 2 }, Spend = 20, Passive = 40, Rating = 10,
		Description = "A giant rotating hologram. Very photogenic.",
	},
	{
		Id = "ent_hall", Name = "Entertainment Hall", Category = "Entertainment", Style = "tower",
		Cost = 80000, Size = { 32, 28 }, Height = 24, Level = 20,
		Color = Color3.fromRGB(40, 20, 60), Accent = Color3.fromRGB(255, 50, 220),
		Appeal = { Tourist = 6, Family = 5, Event = 8, Racer = 2 }, Spend = 900, Passive = 300, Rating = 25,
		Description = "Shows, games and music under one roof.",
	},
	{
		Id = "luxury_hotel", Name = "Luxury Hotel", Category = "Buildings", Style = "tower",
		Cost = 250000, Size = { 32, 32 }, Height = 64, Level = 30,
		Color = Color3.fromRGB(20, 20, 30), Accent = Color3.fromRGB(255, 210, 90),
		Appeal = { Luxury = 12, Business = 7, Tourist = 4 }, Spend = 2500, Passive = 800, Rating = 40,
		Description = "Five neon stars. Luxury tourists pay top dollar.",
	},
	{
		Id = "arena", Name = "Mini Arena", Category = "Entertainment", Style = "arena",
		Cost = 1000000, Size = { 40, 40 }, Height = 14, Level = 45,
		Color = Color3.fromRGB(60, 60, 75), Accent = Color3.fromRGB(0, 235, 255),
		Appeal = { Event = 12, Racer = 5, Tourist = 6, Family = 4 }, Spend = 8000, Passive = 2500, Rating = 70,
		Description = "Your own event arena.",
	},
	{
		Id = "helipad", Name = "Helipad", Category = "Outdoor", Style = "helipad",
		Cost = 2500000, Size = { 20, 20 }, Height = 3, Level = 60,
		Color = Color3.fromRGB(45, 45, 55), Accent = Color3.fromRGB(255, 255, 255),
		Appeal = { Luxury = 12, Business = 9 }, Spend = 15000, Passive = 5000, Rating = 60,
		Description = "Luxury guests arrive in style.",
	},
	-- Special unlocks ------------------------------------------------------
	{
		Id = "vip_sign", Name = "VIP Neon Sign", Category = "Decoration", Style = "sign",
		Cost = 0, Size = { 12, 4 }, Height = 10, Level = 1, Pass = "VIP",
		Color = Color3.fromRGB(25, 20, 10), Accent = Color3.fromRGB(255, 200, 60), SignText = "VIP",
		Appeal = { Luxury = 2 }, Spend = 0, Passive = 5, Rating = 3,
		Description = "Gold VIP sign (VIP Pass).",
	},
	{
		Id = "prestige_monument", Name = "Prestige Monument", Category = "Decoration", Style = "hologram",
		Cost = 50000, Size = { 8, 8 }, Height = 20, Level = 1, Prestige = 1,
		Color = Color3.fromRGB(30, 25, 10), Accent = Color3.fromRGB(255, 215, 0),
		Appeal = { Tourist = 3, Luxury = 3, Event = 3 }, Spend = 30, Passive = 120, Rating = 15,
		Description = "Only prestiged players can build this.",
	},
}

Buildings.ById = {}
for index, def in ipairs(Buildings.List) do
	def.Order = index
	Buildings.ById[def.Id] = def
end

function Buildings.Get(id)
	return Buildings.ById[id]
end

-- Footprint after rotation (rot = 0..3 quarter turns).
function Buildings.Footprint(def, rot)
	if rot % 2 == 1 then
		return def.Size[2], def.Size[1]
	end
	return def.Size[1], def.Size[2]
end

return Buildings
