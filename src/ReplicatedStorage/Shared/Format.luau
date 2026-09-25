-- NEON CITY: number / time formatting helpers.

local Format = {}

function Format.Commas(n)
	n = math.floor(n + 0.5)
	local negative = n < 0
	local s = tostring(math.abs(n))
	local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if result:sub(1, 1) == "," then
		result = result:sub(2)
	end
	return (negative and "-" or "") .. result
end

function Format.Money(n)
	return "$" .. Format.Commas(n)
end

-- Compact form for HUDs: $950, $12.5K, $3.2M, $1.1B
function Format.ShortMoney(n)
	local abs = math.abs(n)
	-- { show from, divisor, suffix }
	local suffixes = { { 1e12, 1e12, "T" }, { 1e9, 1e9, "B" }, { 1e6, 1e6, "M" }, { 1e4, 1e3, "K" } }
	for _, entry in ipairs(suffixes) do
		if abs >= entry[1] then
			local text = string.format("%.1f", n / entry[2]):gsub("%.0$", "")
			return "$" .. text .. entry[3]
		end
	end
	return Format.Money(n)
end

function Format.Time(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Format.RaceTime(seconds)
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, rest)
end

return Format
