-- Defold Router: Sample routing table implementation
--
-- This table works like a simple state machine.
--
-- © 2016 Roman "Megus" Petrov, Wise Hedgehog Studio.
-- https://wisehedgehog.studio, https://megus.org

local M = {}

--- Router entry point
-- This function returns the data for the first scene
-- @treturn string The first scene name
-- @treturn tab The first scene input table (optional)
function M.first_scene()
    return "main_menu"
end

--- Main menu scene handler
-- Scene functions are called when the scene is finished.
-- These functions can analyze scene output to decide which scene should be displayed next.
-- In this case the only possible next scene is "level_selector".
-- @tparam table output Scene output (optional)
-- @treturn string Next scene name
-- @treturn tab Input table for the next scene (optional)
function M.main_menu(output)
    return "level_selector"
end

--- Level Selector scene handler
-- If the level is selected, then output table will contain world and level number and
-- the next scene will be "gameplay". If the "Back" button was pressed, output will be empty
-- and we should return to the main menu.
-- @tparam table output Scene output (optional)
-- @treturn string Next scene name
-- @treturn tab Input table for the next scene (optional)
function M.level_selector(output)
    if output and output.world then
        return "gameplay", {world = output.world, level = output.level}
    else
        return "main_menu"
    end
end

--- Gameplay scene handler
-- Depending on win boolean field in output, we choose between "win" and "fail" scenes.
-- @tparam table output Scene output (optional)
-- @treturn string Next scene name
-- @treturn tab Input table for the next scene (optional)
function M.gameplay(output)
    if output.win then
        return "win", {world = output.world, level = output.level}
    else
        return "fail", {world = output.world, level = output.level}
    end
end

--- Fail scene handler
-- Go to Level Selector and tell it that it was a fail so it can update wins/fails counts
-- @tparam table output Scene output (optional)
-- @treturn string Next scene name
-- @treturn tab Input table for the next scene (optional)
function M.fail(output)
    return "level_selector", {win = false}
end

--- Win scene handler
-- Go to Level Selector and tell it that it was a win so it can update wins/fails counts
-- @tparam table output Scene output (optional)
-- @treturn string Next scene name
-- @treturn tab Input table for the next scene (optional)
function M.win(output)
    return "level_selector", {win = true}
end

return M
