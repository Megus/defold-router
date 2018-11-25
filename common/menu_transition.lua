local router = require("wh_router.router")

local black = vmath.vector4(0, 0, 0, 0.5)
local transparent = vmath.vector4(0, 0, 0, 0)

local function on_message(message_id, message)
	if message_id == router.messages.transition then
		local container = gui.get_node("container")
		local shadow = gui.get_node("shadow")
		if message.t_type == router.transition_types.t_in or message.t_type == router.transition_types.t_back_in then
			gui.set_position(container, vmath.vector3(0, -600, 0))
			gui.set_color(shadow, transparent)
			gui.animate(shadow, "color.w", 0.5, go.EASING_LINEAR, 0.2)
			gui.animate(container, "position", vmath.vector3(0, 0, 0), go.EASING_OUTBACK, 0.4, 0, function()
				msg.post("controller#script", "acquire_input_focus")
			    msg.post(".", "acquire_input_focus")
				router.finished_transition(message.router)
			end)
		else
		    msg.post(".", "release_input_focus")
			msg.post("controller#script", "release_input_focus")
			gui.set_color(shadow, black)
			gui.animate(shadow, "color.w", 0, go.EASING_LINEAR, 0.2, 0.2)
			gui.animate(container, "position", vmath.vector3(0, -600, 0.5), go.EASING_INCUBIC, 0.4, 0, function()
				router.finished_transition(message.router)
			end)
		end
	end
end

return on_message