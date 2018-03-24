-- Defold Router: Helper functions
--
-- © 2016 Roman "Megus" Petrov, Wise Hedgehog Studio.
-- https://wisehedgehog.studio, https://megus.org

--- Router module
-- @module M
local M = {}

--- Router message hashes
M.messages = {
	scene_input = hash("wh_router_scene_input"),      -- scene input message
	scene_popped = hash("wh_router_scene_popped")     -- scene popped message
}

----------------------------------------------------------------------------------------------------
-- Private interface
----------------------------------------------------------------------------------------------------

-- Router messages
local messages = {
	push = hash("wh_router_scene_push"),
	push_modal = hash("wh_router_scene_push_modal"),
	popup = hash("wh_router_scene_popup"),
	close = hash("wh_router_scene_close")
}

-- Scene display methods
local methods = {
	switch = 0,
	push = 1,
	push_modal = 2,
	popup = 3,
	restore = 4
}

-- Private storage: routing tables and router objects
local router_objects = {}

-- Returns scene controller URL string
local function scene_controller_url(ro, name)
	return name .. ":/" .. ro.scene_controller_path
end

-- Unload a scene
local function unload_scene(url)
	msg.post(url, "disable")
	msg.post(url, "final")
	msg.post(url, "unload")
end

-- Get scene info
local function scene_info(ro, scene_name)
	local info = {	-- Default scene info
		sync_load = false,
		show_loading = false,
		has_transitions = false
	}

	if ro.scenes.info and ro.scenes.info[scene_name] then
		for key, value in pairs(ro.scenes.info[scene_name]) do
			info[key] = value
		end
	end

	return info
end

local function get_next_scene(ro, current, output)
	local route = current and ro.scenes.routing[current] or ro.scenes.first_scene
	assert(route, current and "Can't get the scene next to [" .. current .. "]" or "First scene is not set")
	if type(route) == "string" then
		return route
	elseif type(route) == "table" then
		return route[1], route[2]
	elseif type(route) == "function" then
		return route(output)
	else
		assert(false, "Invalid routing table entry format for scene [" .. current .. "]")
	end
end

-- Puts the next scene to the scene stack and loads it
local function show_next_scene(ro, method, message)
	local scene

	if method == methods.switch then
		-- Switch a scene, use the state machine to get the next scene
		local current_name = #ro.stack ~= 0 and ro.stack[#ro.stack].name or nil
		if current_name then
			ro.states[current_name] = message.state
		end
		local next_name, input = get_next_scene(ro, current_name, message.output)
		scene = {name = next_name, input = input, method = method}
	elseif method == methods.push or method == methods.push_modal or method == methods.popup then
		-- All these methods are pushing the new scene
		if method == methods.push then
			ro.states[ro.stack[#ro.stack].name] = message.state
		end
		scene = {name = message.scene_name, input = message.input, method = method}
	elseif method == methods.restore then
		-- Restore the previous scene
		local previous = ro.stack[#ro.stack - 1]
		scene = {name = previous.name, input = previous.input,
			output = message.output, method = previous.method, restored = true}
		-- Remove it for now, it will be pushed back below
		table.remove(ro.stack, #ro.stack - 1)
	end
	-- Push the next scene to the stack
	table.insert(ro.stack, scene)
	local info = scene_info(ro, scene.name)
	msg.post("#" .. scene.name, info.sync_load and "load" or "async_load")
end


-- Message handling
local message_handlers = {
	-- A new scene is loaded
	[hash("proxy_loaded")] = function(ro, _, sender)
		local previous = (#ro.stack > 1) and ro.stack[#ro.stack - 1] or nil
		local current = ro.stack[#ro.stack]
		-- Unload the previous scene if needed
		if previous and (current.method == methods.switch or current.method == methods.push or current.restored) then
			unload_scene("#" .. previous.name)
		-- Disable the previous scene on modal push
		elseif current.method == methods.push_modal then
			msg.post("#" .. previous.name, "disable")
		-- Release input focus from the previous scene on popup
		elseif current.method == methods.popup then
			msg.post(scene_controller_url(ro, previous.name), "release_input_focus")
		end
		-- Remove previous scene from the stack if it was a switch or the current scene was restored
		if current.method == methods.switch or current.restored then
			table.remove(ro.stack, #ro.stack - 1)
		end
		-- Init and enable new scene
		msg.post(sender, "init")
		msg.post(sender, "enable")
		-- Pass the input to the new scene
		if not current.restored then
			msg.post(scene_controller_url(ro, current.name), M.messages.scene_input,
				{router = ro.router_url, input = current.input, state = ro.states[current.name]})
		else
			msg.post(scene_controller_url(ro, current.name), M.messages.scene_popped,
				{router = ro.router_url, output = current.output, state = ro.states[current.name]})
		end
	end,

	-- Scene is unloaded
	[hash("proxy_unloaded")] = function()
		-- Currently we don't need to do anything here
	end,

	-- Handle scene push
	[messages.push] = function(ro, message)
		show_next_scene(ro, methods.push, message)
	end,

	-- Handle scene modal push
	[messages.push_modal] = function(ro, message)
		show_next_scene(ro, methods.push_modal, message)
	end,

	-- Handle scene popup
	[messages.popup] = function(ro, message)
		show_next_scene(ro, methods.popup, message)
	end,

	-- Handle scene close
	[messages.close] = function(ro, message)
		local current = ro.stack[#ro.stack]
		-- This scene appeared by switching, the state-machine will be used
		if current.method == methods.switch then
			show_next_scene(ro, methods.switch, message)
		-- It was a pushed scene, we need to restore the previous one
		elseif current.method == methods.push then
			show_next_scene(ro, methods.restore, message)
		-- It was modally pushed scene, unload it and enable the previous one
		elseif current.method == methods.push_modal or current.method == methods.popup then
			unload_scene("#" .. current.name)
			table.remove(ro.stack)
			local previous = ro.stack[#ro.stack]
			if current.method == methods.popup then
				msg.post(scene_controller_url(ro, previous.name), "acquire_input_focus")
			else
				msg.post("#" .. previous.name, "enable")
			end
			msg.post(scene_controller_url(ro, previous.name),
				M.messages.scene_popped,
				{router = ro.router_url, output = message.output, name = current.name})
		end
	end
}


----------------------------------------------------------------------------------------------------
-- Public interface
----------------------------------------------------------------------------------------------------

--- Create new Router object
-- @treturn string Router ID
-- @tparam table Scene table
-- @tparam string router_url Script with the router URL string
-- @tparam string scene_controller_path Path to scene controller scripts
function M.new(scenes, router_url, scene_controller_path)
	assert(router_url, "router_url can't be nil")
	assert(scene_controller_path, "scene_controller_path can't be nil")
	-- Init scene stack and scene state storage
	local ro = {
		stack = {},
		states = {},
		scenes = scenes,
		router_url = router_url,
		scene_controller_path = scene_controller_path
	}
	-- Save router object and routing table in the internal storage.
	router_objects[router_url] = ro
	-- Load the first scene
	show_next_scene(ro, methods.switch, {})
	return router_url
end

--- Router message handler
-- Call this handler from your root scene on_message function
-- @tparam string router_id Router ID
-- @tparam hash message_id Message ID
-- @tparam table message Message table
-- @param sender Message sender
function M.on_message(router_id, message_id, message, sender)
	local ro = router_objects[router_id]
	assert(ro, "Invalid router_id")
	if message_handlers[message_id] then
		message_handlers[message_id](ro, message, sender)
	end
end

--- Push the new scene to scene stack
-- The current scene will be unloaded and its state will be saved.
-- When the pushed scene is closed, the current scene will receive "scene_popped"
-- message with the output of the pushed scene and the state of the current scene
-- so it can restore its state. "scene_input" message will not be sent.
-- @tparam string router_id Router ID
-- @tparam string scene_name Name of the new scene
-- @tparam table input Input for the new scene (optional)
-- @tparam table state State of the current scene (optional)
function M.push(router_id, scene_name, input, state)
	local ro = router_objects[router_id]
	assert(ro, "Invalid router_id")
	msg.post(ro.router_url, messages.push,
		{scene_name = scene_name, input = input, state = state})
end

--- Push the new modal scene
-- The current scene will not be unloaded but will be disabled
-- (it will disappear from the screen). When the pushed scene is closed,
-- the current scene will receive "scene_popped" message with the output of
-- the pushed scene. State saving is not required for this method.
-- @tparam string router_id Router ID
-- @tparam string scene_name Name of the new scene
-- @tparam table input Input for the new scene (optional)
function M.push_modal(router_id, scene_name, input)
	local ro = router_objects[router_id]
	assert(ro, "Invalid router_id")
	msg.post(ro.router_url, messages.push_modal,
		{scene_name = scene_name, input = input})
end

--- Show popup scene
-- The current scene will not be unloaded but the input will be disabled.
-- When the pushed scene is closed, the current scene will receive "scene_popped"
-- message with the output of the pushed scene. The input focus will be acquired again.
-- State saving is not required for this method
-- @tparam string router_id Router ID
-- @tparam string scene_name Name of the new scene
-- @tparam table input Input for the new scene (optional)
function M.popup(router_id, scene_name, input)
	local ro = router_objects[router_id]
	assert(ro, "Invalid router_id")
	msg.post(ro.router_url, messages.popup,
		{scene_name = scene_name, input = input})
end

--- Close the current scene
-- The current scene will be unloaded. The output will be used depending on how this
-- scene was displayed. For push, push_modal and popup methods this output will be
-- passed directly to the previous scene. If this scene was displayed according to
-- routing rules, the output will be passed to corresponding routing function.
-- @tparam string router_id Router object
-- @tparam table output The output of the current scene (optional)
-- @tparam table state State of the scene (optional)
function M.close(router_id, output, state)
	local ro = router_objects[router_id]
	assert(ro, "Invalid router_id")
	msg.post(ro.router_url, messages.close,
		{output = output, state = state})
end

return M
