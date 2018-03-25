-- Defold Router: Helper functions
--
-- © 2016 Roman "Megus" Petrov, Wise Hedgehog Studio.
-- https://wisehedgehog.studio, https://megus.org

--- Router module
-- @module M
local M = {}

--- Router message hashes
M.messages = {
	scene_input = hash("wh_router_scene_input"),		-- scene input message
	scene_popped = hash("wh_router_scene_popped"),		-- scene popped message
	transition = hash("wh_router_transition"),			-- scene transition message
	loader_start = hash("wh_router_start_loader"),		-- start loader message
	loader_stop = hash("wh_router_stop_loader"),		-- stop loader message
}

M.transition_types = {
	t_none = 0,
	t_in = 1,
	t_out = 2,
	t_back_in = 3,
	t_back_out = 4
}

----------------------------------------------------------------------------------------------------
-- Private interface
----------------------------------------------------------------------------------------------------

-- Router messages
local messages = {
	push = hash("wh_router_scene_push"),
	push_modal = hash("wh_router_scene_push_modal"),
	popup = hash("wh_router_scene_popup"),
	close = hash("wh_router_scene_close"),
	finished_transition = hash("wh_router_finished_transition"),
	stopped_loader = hash("wh_router_stopped_loader")
}

local msg_proxy_loaded = hash("proxy_loaded")

-- Scene display methods
local methods = {
	switch = 1,
	push = 2,
	push_modal = 3,
	popup = 4,
}

-- Private storage: routing tables and router objects
local router_objects = {}

-- Returns scene controller URL string
local function scene_controller_url(ro, name)
	return name .. ":/" .. ro.scene_controller_path
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

-- Returns top scene at the stack
local function top_scene(ro)
	return #ro.stack ~= 0 and ro.stack[#ro.stack] or nil
end

-- Get the next scene from the routing state machine
local function get_next_scene(ro, current, output)
	local route = current and ro.scenes.routing[current] or ro.scenes.first_scene
	assert(route, current and "Can't get the scene next to [" .. current .. "]" or "first_scene is not set")
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

-- Unload a scene
local function unload_scene(scene, should_disable)
	should_disable = should_disable == nil and true or false
	local url = "#" .. scene.name
	if should_disable then
		msg.post(url, "disable")
	end
	msg.post(url, "final")
	msg.post(url, "unload")
end

local function scene_transition(ro, scene, t_type)
	if t_type == M.transition_types.t_none then return end
	local info = scene_info(ro, scene.name)
	if info.has_transitions then
		msg.post(scene_controller_url(ro, scene.name), M.messages.transition, {t_type = t_type})
		ro.wait_for = messages.finished_transition
		coroutine.yield()
	end
end

-- Initialize scene
local function init_scene(ro, scene, message, did_pop, t_type)
	message.router = ro.router_url
	message.state = ro.states[scene.name]
	msg.post(scene_controller_url(ro, scene.name), did_pop and M.messages.scene_popped or M.messages.scene_input, message)
	scene_transition(ro, scene, t_type)
end

-- Load new scene
local function load_scene(ro, scene, previous, message, did_pop)
	table.insert(ro.stack, scene)
	local info = scene_info(ro, scene.name)
	msg.post("#" .. scene.name, info.sync_load and "load" or "async_load")

	-- Enable loading indicator, if needed
	if info.show_loading and ro.loader_url then
		if previous then
			msg.post("#" .. previous.name, "disable")
		end
		msg.post(ro.loader_url, "enable")
		msg.post(ro.loader_url, M.messages.loader_start, {router = ro.router_url})
	end

	-- Wait for the scene to load
	ro.wait_for = msg_proxy_loaded
	coroutine.yield()

	-- Unload previous scene
	if previous then
		unload_scene(previous, info.show_loading and ro.loader_url)
	end

	-- Disable loading indicator, if needed
	if info.show_loading and ro.loader_url then
		msg.post(ro.loader_url, M.messages.loader_stop, {router = ro.router_url})
		ro.wait_for = messages.stopped_loader
		coroutine.yield()
		msg.post(ro.loader_url, "disable")
	end

	msg.post("#" .. scene.name, "enable")
	init_scene(ro, scene, message, did_pop, did_pop and M.transition_types.t_back_in or M.transition_types.t_in)
end

local function switch_scene(ro, current_output)
	local current = top_scene(ro)
	if current then table.remove(ro.stack, #ro.stack) end
	local next_name, input = get_next_scene(ro, current and current.name or nil, current_output)
	local scene = {name = next_name, method = methods.switch}
	load_scene(ro, scene, current, {input = input}, false)
end

local function push_scene(ro, scene_name, input, state)
	local co = coroutine.create(function()
		local current = top_scene(ro)
		ro.states[scene_name] = state
		scene_transition(ro, current, M.transition_types.t_out)
		local scene = {name = scene_name, method = methods.push}
		load_scene(ro, scene, current, {input = input}, false)
		ro.co = nil
	end)
	ro.co = co
	coroutine.resume(co)
end

local function push_modal_scene(ro, scene_name, input)
	local co = coroutine.create(function()
		local current = top_scene(ro)
		scene_transition(ro, current, M.transition_types.t_out)
		msg.post("#" .. current.name, "disable")
		local scene = {name = scene_name, method = methods.push_modal}
		load_scene(ro, scene, nil, {input = input}, false)
		ro.co = nil
	end)
	ro.co = co
	coroutine.resume(co)
end

local function popup_scene(ro, scene_name, input)
	local co = coroutine.create(function()
		local current = top_scene(ro)
		local scene = {name = scene_name, method = methods.popup}
		msg.post(scene_controller_url(ro, current.name), "release_input_focus")
		load_scene(ro, scene, nil, {input = input}, false)
		ro.co = nil
	end)
	ro.co = co
	coroutine.resume(co)
end

local function close_scene(ro, output, state)
	local co = coroutine.create(function()
		-- Save state
		local scene = top_scene(ro)
		ro.states[scene.name] = state
		scene_transition(ro, scene,
			scene.method == methods.switch and M.transition_types.t_out or M.transition_types.t_back_out)

		-- Now load next scene
		if scene.method == methods.switch then
			switch_scene(ro, output)
		elseif scene.method == methods.push then
			table.remove(ro.stack, #ro.stack)
			local previous = top_scene(ro)
			table.remove(ro.stack, #ro.stack)
			load_scene(ro, previous, scene, {output = output, name = scene.name}, true)
		elseif scene.method == methods.push_modal then
			table.remove(ro.stack, #ro.stack)
			unload_scene(scene)
			local previous = top_scene(ro)
			msg.post("#" .. previous.name, "enable")
			init_scene(ro, previous, {output = output, name = scene.name}, true, M.transition_types.t_back_in)
		elseif scene.method == methods.popup then
			table.remove(ro.stack, #ro.stack)
			unload_scene(scene)
			local previous = top_scene(ro)
			init_scene(ro, previous, {output = output, name = scene.name}, true, M.transition_types.t_none)
			msg.post(scene_controller_url(ro, previous.name), "acquire_input_focus")
		end
		ro.co = nil
	end)
	coroutine.resume(co)
	ro.co = co
end


----------------------------------------------------------------------------------------------------
-- Public interface
----------------------------------------------------------------------------------------------------

--- Create new Router object
-- @treturn string Router ID
-- @tparam table Scene table
-- @tparam string router_url Script with the router URL string
-- @tparam string scene_controller_path Path to scene controller scripts
-- @tparam string loader_url URL of a loader component (optional, only if you use loaders)
function M.new(scenes, router_url, scene_controller_path, loader_url)
	assert(router_url, "router_url can't be nil")
	assert(scene_controller_path, "scene_controller_path can't be nil")

	-- Init scene stack and scene state storage
	local ro = {
		stack = {},
		states = {},
		scenes = scenes,
		router_url = router_url,
		loader_url = loader_url,
		scene_controller_path = scene_controller_path
	}
	router_objects[router_url] = ro

	-- Load the first scene
	if loader_url then
		msg.post(loader_url, "disable")
	end
	ro.co = coroutine.create(function() switch_scene(ro) end)
	coroutine.resume(ro.co)
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

	if message_id == ro.wait_for then
		ro.wait_for = nil
		coroutine.resume(ro.co, message, sender)
	elseif message_id == messages.push then
		push_scene(ro, message.scene_name, message.input, message.state)
	elseif message_id == messages.push_modal then
		push_modal_scene(ro, message.scene_name, message.input)
	elseif message_id == messages.popup then
		popup_scene(ro, message.scene_name, message.input)
	elseif message_id == messages.close then
		close_scene(ro, message.output, message.state)
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
	msg.post(ro.router_url, messages.push, {scene_name = scene_name, input = input, state = state})
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
	msg.post(ro.router_url, messages.push_modal, {scene_name = scene_name, input = input})
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
	msg.post(ro.router_url, messages.popup, {scene_name = scene_name, input = input})
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
	msg.post(ro.router_url, messages.close, {output = output, state = state})
end

function M.finished_transition(router_id)
	local ro = router_objects[router_id]
	assert(ro, "Invalid router_id")
	msg.post(ro.router_url, messages.finished_transition)
end

function M.stopped_loader(router_id)
	local ro = router_objects[router_id]
	assert(ro, "Invalid router_id")
	msg.post(ro.router_url, messages.stopped_loader)
end

return M
