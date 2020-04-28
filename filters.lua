-- Words filter
filter.register_filter("words", function(name, message)
	for _, w in ipairs(filter.assets["words"].words) do
		if string.find(message:lower(), "%f[%a]" .. w .. "%f[%A]") then
			return "Watch your language!"
		end
	end
end)

-- Initialize words list
filter.register_on_init(function()
	local sw = s:get_string("words")
	if sw and sw ~= "" then
		filter.assets["words"].words = minetest.parse_json(sw)
	end

	if #filter.assets["words"].words == 0 then
		local words = {}
		local file = io.open(filepath, "r")
		if file then
			for line in file:lines() do
				line = line:trim()
				if line ~= "" then
					words[#words + 1] = line:trim()
				end
			end
			filter.assets["words"].words = words
		end
	end
end)

-- Words filter sub-command
filter.register_chatcommand("words", {
	description = "Usage: /filter words <add|remove|list> [<word>]",
	func = function(cmd)
		local words = filter.assets["words"].words
		if cmd == "list" then
			return true, #words .. " words: " .. table.concat(words, ", ")
		elseif cmd == "add" then
			table.insert(filter.assets["words"].words, param)
			filter.storage:set_string("words", minetest.write_json(words))
			filter.assets["words"].words = words
			return true, "Added \"" .. val .. "\"."
		elseif cmd == "remove" then
			for i, w in ipairs(words) do
				if w == param then
					table.remove(words, i)
					filter.storage:set_string("words", minetest.write_json(words))
					filter.assets["words"].words = words
					return true, "Removed \"" .. param .. "\"."
				end
			end
			return false, "\"" .. param .. "\" not found in list."
		else
			return false, "Invalid option. See /help filter"
		end
	end
})
