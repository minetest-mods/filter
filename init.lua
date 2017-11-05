
--[[

	Copyright 2017 Auke Kok <sofar@foo-projects.org>

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject
	to the following conditions:

	The above copyright notice and this permission notice shall be included
	in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
	KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
	WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
	LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
	OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
	WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

]]--

local s = minetest.get_mod_storage()
assert(s, "minetest version too old")

local words
local sw = s:get_string("words")

if sw and sw ~= "" then
	words = minetest.parse_json(sw)
else
	words = {}
end

minetest.register_on_chat_message(function(name, message)
	local privs = minetest.get_player_privs(name)
	if not privs.shout then
		minetest.chat_send_player(name, "You are temporarily muted.")
		return true
	end

	for _, w in ipairs(words) do
		if string.find(message, "%f[%a]" .. w .. "%f[%A]") then
			local privs = minetest.get_player_privs(name)

			privs.shout = nil
			minetest.set_player_privs(name, privs)
			minetest.chat_send_player(name, "Chat temporarily disabled due to language.")

			minetest.after(60, function()
				minetest.chat_send_player(name, "Chat privilege reinstated. Please do not abuse chat.")
				privs.shout = true
				minetest.set_player_privs(name, privs)
			end)

			return true
		end
	end

	return false
end)

minetest.register_chatcommand("filter", {
	params = "filter server",
	description = "manage swear word filter",
	privs = {server = true},
	func = function(name, param)
		local cmd, val = param:match("(%w+) (.+)")
		if param == "list" then
			return true, table.concat(words, ", ")
		elseif cmd == "add" then
			table.insert(words, val)
			s:set_string("words", minetest.write_json(words))
			return true, "Added \"" .. val .. "\"."
		elseif cmd == "remove" then
			for i, w in ipairs(words) do
				if w == val then
					table.remove(words, i)
					s:set_string("words", minetest.write_json(words))
					return true, "Removed \"" .. val .. "\"."
				end
			end
			return true, "\"" .. val .. "\" not found in list."
		else
			return true, "Usage: /filter <add|remove|list> [<word>]"
		end
	end,
})
