-- Defold Router: Sample routing table implementation
--
-- This table works like a simple state machine.
--
-- © 2016 Roman "Megus" Petrov, Wise Hedgehog Studio.
-- https://wisehedgehog.studio, https://megus.org

local M = {
    info = {
        -- Regular scenes
        main_menu = {
            sync_load = true,
        },
        level_selector = {
            has_transitions = true,
        },
        gameplay = {
            has_transitions = true,
            show_loading = true
        },
        fail = {
        },
        win = {
        },
        -- Popups
        help = {
        },
        help_chapter = {

        },
        settings = {

        }
    },

    first_scene = "main_menu",
    routing = {
        -- Go to Level Selector from the Main Menu screen
        main_menu = "level_selector",

        -- Depending on the output, go to Gameplay or back to Main Menu
        level_selector = function (output)
            if output and output.world then
                return "gameplay", {world = output.world, level = output.level}
            else
                return "main_menu"
            end
        end,

        gameplay = function (output)
            if output.win then
                return "win", {world = output.world, level = output.level}
            else
                return "fail", {world = output.world, level = output.level}
            end
        end,

        fail = {"level_selector", {win = false}},
        win = {"level_selector", {win = true}}
    }
}

return M
