
--[[

	Copyright 2017-8 Auke Kok <sofar@foo-projects.org>
	Copyright 2018 rubenwardy <rw@rubenwardy.com>

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

--]]

filter = {
	assets = {},
	storage = minetest.get_mod_storage()
}
local muted = {}
local violations = {}
local registered_on_violations = {}
local registered_on_init = {}
local registered_filters = {}
local registered_chatcommands = {}

-- Run callback at startup. Can be used for data initialization
-- or loading assets from mod storage
function filter.register_on_init(func)
	table.insert(registered_on_init, func)
end

-- Filters return a warning string if triggered
function filter.register_filter(name, func)
	assert(not registered_filters[name])
	registered_filters[name] = func
	filter.assets["name"] = {}
end

local help_str = ""
local function update_help()
	help_str = ""
	for name, def in pairs(registered_chatcommands) do
		help_str = help_str .. "\n\t\"" .. name .."\": " .. def.description
	end
end

-- /filter sub-command registration method
function filter.register_chatcommand(name, def)
	assert(not registered_chatcommands[name])
	registered_chatcommands[name] = def
	update_help()
end

-- check_message invokes all filters, and returns true and a '\n'
-- separated list of warnings if at least one filter is triggered
local function check_message(name, message)
	local str
	local ret_val = {}

	for _, fn in pairs(filter.registered_filters) do
		str = fn(name, message)
		if str and str ~= "" then
			table.insert(ret_val[name], str)
		end
	end

	local ret = table.concat(ret_val[name], "\n")
	if ret and ret ~= "" then
		ret_val[name] = {}
		return true, ret
	end
	return false
end

local function mute(name, duration)
	do
		local privs = minetest.get_player_privs(name)
		privs.shout = nil
		minetest.set_player_privs(name, privs)
	end

	minetest.chat_send_player(name, "You have been temporarily muted for abusing the chat.")

	muted[name] = true

	minetest.after(duration * 60, function(name)
		local privs = minetest.get_player_privs(name)
		if privs.shout == true then
			return
		end

		muted[name] = nil
		minetest.chat_send_player(name, "Chat privilege reinstated. Please do not abuse the chat.")

		privs.shout = true
		minetest.set_player_privs(name, privs)
	end, name)
end

local function show_warning_formspec(name, warnings)
	local formspec = "size[7,3]bgcolor[#080808BB;true]"
		.. "default.gui_bg" .. "default.gui_bg_img"
		.. "image[0,0;2,2;filter_warning.png]"
		.. "label[2.3,0.5;" .. warnings .. "]"

	if minetest.global_exists("rules") and rules.show then
		formspec = formspec .. [[
				button[0.5,2.1;3,1;rules;Show Rules]
				button_exit[3.5,2.1;3,1;close;Okay]
			]]
	else
		formspec = formspec .. [[
				button_exit[2,2.1;3,1;close;Okay]
			]]
	end
	minetest.show_formspec(name, "filter:warning", formspec)
end

local function on_violation(name, message, warnings)
	violations[name] = (violations[name] or 0) + 1

	local resolution

	for _, cb in pairs(filter.registered_on_violations) do
		if cb(name, message, violations) then
			resolution = "custom"
		end
	end

	if not resolution then
		if violations[name] == 1 and minetest.get_player_by_name(name) then
			resolution = "warned"
			show_warning_formspec(name, warnings)
		elseif violations[name] <= 3 then
			resolution = "muted"
			mute(name, 1)
		else
			resolution = "kicked"
			minetest.kick_player(name, "Kicked for abusing the chat.")
		end
	end

	local logmsg = "VIOLATION (" .. resolution .. "): <" .. name .. "> "..  message
	minetest.log("action", logmsg)

	local email_to = minetest.settings:get("filter.email_to")
	if email_to and minetest.global_exists("email") then
		email.send_mail(name, email_to, logmsg)
	end
end

local function make_checker(old_func)
	return function(name, param)
		if not check_message(name, param) then
			on_violation(name, param)
			return false
		end

		return old_func(name, param)
	end
end

local old_register_chatcommand = minetest.register_chatcommand
function minetest.register_chatcommand(name, def)
	if def.privs and def.privs.shout then
		def.func = make_checker(def.func)
	end
	return old_register_chatcommand(name, def)
end

function filter.register_on_violation(func)
	table.insert(registered_on_violations, func)
end

table.insert(minetest.registered_on_chat_messages, 1, function(name, message)
	if message:sub(1, 1) == "/" then
		return
	end

	local privs = minetest.get_player_privs(name)
	if not privs.shout and muted[name] then
		minetest.chat_send_player(name, "You are temporarily muted.")
		return true
	end

	local dirty, warnings = check_message(name, message)
	if dirty then
		on_violation(name, message, warnings)
		return true
	end
end)

for name, def in pairs(minetest.registered_chatcommands) do
	if def.privs and def.privs.shout then
		def.func = make_checker(def.func)
	end
end

local function step()
	for name, v in pairs(violations) do
		violations[name] = math.floor(v * 0.5)
		if violations[name] < 1 then
			violations[name] = nil
		end
	end
	minetest.after(10*60, step)
end
minetest.after(10*60, step)

minetest.register_chatcommand("filter", {
	params = "<sub-command> [<args>]",
	description = "List of possible sub-commands:" .. help_str,
	privs = {server = true},
	func = function(name, param)
		local fn, cmd = param:match("(%w+) (.+)")
		if fn then
			minetest.chat_send_all("fn " .. fn)
		end
		if cmd then
			minetest.chat_send_all("cmd " .. cmd)
		end

		if not registered_chatcommands[fn] then
			return false, "Invalid sub-command. See /help filter"
		end

		return registered_chatcommands[fn].func(cmd)
	end
})

minetest.register_on_shutdown(function()
	for name, _ in pairs(muted) do
		local privs = minetest.get_player_privs(name)
		privs.shout = true
		minetest.set_player_privs(name, privs)
	end
end)

if minetest.global_exists("rules") and rules.show then
	minetest.register_on_player_receive_fields(function(player, formname, fields)
		if formname == "filter:warning" and fields.rules then
			rules.show(player)
		end
	end)
end

--------------------------------------------------------------------------------
-- Parse filters
local modpath = minetest.get_modpath("filter") .. "/"
dofile(modpath .. "filters.lua")

--------------------------------------------------------------------------------
-- Run all registered_on_init callbacks
for _, init in pairs(registered_on_init) do
	init()
end
