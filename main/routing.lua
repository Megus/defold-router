--- Defold Router state-machine
-- @module router

local M = {}

--- Router entry point
-- This function returns the data for the first scene
-- @treturn string The first scene name
-- @treturn tab The first scene input table (optional)
function M.first_scene()
    return "main_menu"
end

--- Scene handler
-- This function is called when a scene is finished.
-- It can analyze scene output to decide which scene should be displayed next.
-- @tparam table output Scene output (optional)
-- @treturn string Next scene name
-- @treturn tab Input table for the next scene (optional)
function M.main_menu(output)
    return "level_selector", output
end

function M.level_selector(output)
    if output and output.world then
        return "gameplay", {world = output.world, level = output.level}
    else
        return "main_menu"
    end
end

function M.gameplay(output)
    if output.win then
        return "win"
    else
        return "fail"
    end
end

function M.fail(output)
    return "level_selector", {win = false}
end

function M.win(output)
    return "level_selector", {win = true}
end

return M
