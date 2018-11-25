-- Defold Router: Sample routing table implementation
--
-- Simple GUI button component
--
-- © 2016-2018 Roman "Megus" Petrov, Wise Hedgehog Studio.
-- https://wisehedgehog.studio, https://megus.org

local pressed = vmath.vector4(0, 0, 0, 0.5)
local unpressed = vmath.vector4(0, 0, 0, 0)
local msgMouse = hash("mouse")

local function input(nodeId, actionId, action, onClick)
    if actionId == msgMouse then
        if action.pressed then
            if gui.pick_node(gui.get_node(nodeId .."/box"), action.x, action.y) then
                gui.set_color(gui.get_node(nodeId .. "/pressed"), pressed)
            end
        elseif action.released then
            gui.set_color(gui.get_node(nodeId .. "/pressed"), unpressed)
            if gui.pick_node(gui.get_node(nodeId .. "/box"), action.x, action.y) then
                onClick()
            end
        end
    end
end

return input
