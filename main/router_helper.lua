local M = {}

function M.push(scene_name, input, state)
    msg.post("main:/scenes#router", "scene_push",
        {scene_name = scene_name, input = input, state = state})
end

function M.push_modal(scene_name, input)
    msg.post("main:/scenes#router", "scene_push_modal",
        {scene_name = scene_name, input = input})
end

function M.popup(scene_name, input)
    msg.post("main:/scenes#router", "scene_popup",
        {scene_name = scene_name, input = input})
end

function M.close_scene(output, state)
    msg.post("main:/scenes#router", "scene_close",
        {output = output, state = state})
end

return M
