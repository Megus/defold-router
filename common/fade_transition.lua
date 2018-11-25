local router = require("wh_router.router")

local black = vmath.vector4(0, 0, 0, 1)
local transparent = vmath.vector4(0, 0, 0, 0)

local function on_message(message_id, message)
	if message_id == router.messages.transition then
		local fader = gui.get_node("fader")
		if message.t_type == router.transition_types.t_in or message.t_type == router.transition_types.t_back_in then
			gui.set_color(fader, black)
			gui.animate(fader, "color.w", 0, gui.EASING_LINEAR, 0.2, 0, function()
				msg.post("controller#script", "acquire_input_focus")
			    msg.post(".", "acquire_input_focus")
				router.finished_transition(message.router)
			end)
		else
		    msg.post(".", "release_input_focus")
			msg.post("controller#script", "release_input_focus")
			gui.set_color(fader, transparent)
			gui.animate(fader, "color.w", 1, gui.EASING_LINEAR, 0.2, 0, function()
				router.finished_transition(message.router)
			end)
		end
	end
end

return on_message
