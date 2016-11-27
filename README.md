# Defold Router

A powerful UI router for games built with [Defold Game Engine](http://www.defold.com).

Just like a lot of Defold newbies, I've quickly found out that there are no standard functions to implement complex navigation between game screens in Defold. The provided examples only show the general idea of switching screens with collection proxies. But your game usually has more than just two screens. So I came up with an idea to develop a reusable navigation solution. I took the inspiration from ```UINavigationContoller``` in iOS and React/Redux.

This router gives you several navigation methods:

- state machine approach to navigation (which, I believe, suites games perfectly);
- navigation stack (with two variants of pushing the scene to the stack);
- show popups.

## How to use

### Setup

Add the library zip URL as a [dependency](http://www.defold.com/manuals/libraries/#_setting_up_library_dependencies) to your Defold project: [https://github.com/Megus/defold-router/archive/master.zip](https://github.com/Megus/defold-router/archive/master.zip)

Create a game object (I recommend to call it ```scenes```) in the main collection with [collection proxies](http://www.defold.com/manuals/collection-proxies/) for all your scenes (I'm using the word "scene" for a screen). Names of the proxies must match the names of your collections. Don't forget that collection filename is not the same as collection name, so please check that the ```name``` property of your collections are properly set.

Create a routing table Lua module (e.g. ```routing.lua``` in ```main``` folder) with the following sample content:

```lua
local M = {}

function M.first_scene()
    return "main_menu" -- Change to the name of your first scene
end

return M
```

Create a script for ```scenes``` game object (recommended component name is ```router```). Import the router library, your routing table (described below), initialize router in ```init``` function and call router message handler in ```on_message``` function. Please note that you need to save the router object to use it later.

```lua
local router = require("wh_router.router") -- Require Router library
local routing = require("main.routing") -- Path to your routing table

function init(self)
    msg.post(".", "acquire_input_focus")
    -- Create the router with the main routing table.
    -- It will automatically load the first scene.
    self.router = router.new(routing, "main:/scenes#router", "controller#script")
end

function on_message(self, message_id, message, sender)
    -- Handle router messages
    router.on_message(self.router, message_id, message, sender)
    -- You can continue to handle other messages here, of course
end
```

Now you can try to run your project and see that your first scene is loaded!

### Setting up the navigation

There are four navigation methods:

- Scene switching according to rules defined by a routing table.
- Pushing a new scene to the stack with unloading the current scene.
- Pushing a new scene to the stack with keeping the current scene.
- Showing a popup scene with keeping the current scene.

The router treats each scene as a function which has some input parameters and returns some output. Scenes can also have an internal state that can be persisted between scene launches. The router can store these states as well.

#### Routing table

Routing table defines the rules of switching between scenes.

An example of routing function:

```lua
function M.level_selector(output)
    if output and output.world then
        return "gameplay", {world = output.world, level = output.level}
    else
        return "main_menu"
    end
end
```

#### Using the navigation stack

### Handling Router messages in collection scripts

```lua
-- Load router library
local router = require("wh_router.router")

-- Example of on_message function
function on_message(self, message_id, message, sender)
    if message_id == router.messages.scene_input then
        -- Router object is passed in the message, save it to use later
        self.router = message.router
        -- Setup the scene according to the state in message.state
        -- Handle scene input contained in message.input
    elseif message_id == router.messages.scene_popped then
        -- If you push scenes (push/push_modal/popup) in the scene,
        -- handle this message and pushed scene output in message.output
    elseif message_id == hash("select_level") then
        -- Example of using router close function
        router.close(self.router, {world = self.state.world, level = message.level}, self.state)
    end
end
```

---
Created and maintained by Roman "Megus" Petrov / [Wise Hedgehog Studio](https://wisehedgehog.studio).
