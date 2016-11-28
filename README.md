# Defold Router

A powerful UI router for games built with [Defold Game Engine](http://www.defold.com).

## Table of Contents

- [Setup](#setup)
- [Setting up the navigation](#setting-up-the-navigation)
    - [Routing table](#routing-table)
    - [Using the navigation stack](#using-the-navigation-stack)
- [Handling Router messages in collection scripts](#handling-router-messages-in-collection-scripts)

Just like a lot of Defold newbies, I've quickly found out that there are no standard functions to implement complex navigation between game screens in Defold. The provided examples only show the general idea of switching screens with collection proxies but your game usually has more than just two screens. So I came up with an idea to develop a reusable navigation solution. I took the inspiration from ```UINavigationContoller``` in iOS and React/Redux.

This router gives you several navigation methods:

- state machine approach to navigation (which, I believe, suits games perfectly);
- navigation stack (with two variants of pushing the scene to the stack);
- show popups.

The demo project contains code samples for all possible Router use cases.

## Setup

Add the library zip URL as a [dependency](http://www.defold.com/manuals/libraries/#_setting_up_library_dependencies) to your Defold project: [https://github.com/Megus/defold-router/archive/master.zip](https://github.com/Megus/defold-router/archive/master.zip)

Create a game object (I recommend to name it ```scenes```) in the main collection with [collection proxies](http://www.defold.com/manuals/collection-proxies/) for all your scenes (I'm using the word "scene" for a screen). Proxy names must match the names of your collections. Don't forget that collection filename is not the same as collection name, so please check that ```name``` properties of your collections are properly set.

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
    -- Create the router object with the main routing table.
    -- The first scene will be loaded automatically.
    self.router = router.new(routing, "main:/scenes#router", "controller#script")
end

function on_message(self, message_id, message, sender)
    -- Handle router messages
    router.on_message(self.router, message_id, message, sender)
    -- You can continue to handle other messages here, of course
end
```

Function ```router.new``` accepts three parameters:

- your routing scheme table;
- URL string to the script of the game object with the proxies;
- path to the controller script of your scenes. You should use the same name for all scenes (```controller#script``` is a good choice).

Now you can try to run your project and see that your first scene is loaded!

## Setting up the navigation

The Router treats each scene as a function which has some input parameters and returns some output. This approach is used to decouple scenes as much as possible. Scenes can have an internal state that can be persisted between scene launches. The Router will store these states.

There are four ways to change scenes:

- Scene switching according to rules defined by a routing table.
- Pushing a new scene to the stack with unloading the current scene.
- Pushing a new scene to the stack with keeping the current scene.
- Showing a popup scene with keeping the current scene.

### Routing table

Routing table defines the rules of switching between scenes. It works as a state machine where states are your scene names. When you close a scene that was displayed using routing table, Router will call a function with the same name as your scene and pass the scene output to it. This function can analyze scene output to decide which scene should be displayed next. The function returns the name of the next scene and the input table for it (input is optional).

An example of routing function:

```lua
-- This function will be called when level_selector scene is closed
function M.level_selector(output)
    -- If the level was selected, then the next scene is gameplay,
    -- otherwise get back to the main_menu scene
    if output and output.world then
        return "gameplay", {world = output.world, level = output.level}
    else
        return "main_menu"
    end
end
```

### Using the navigation stack

#### Push the scene

```lua
router.push(router_object, scene_name, input, state)
```

Pushes the new scene to the stack and passes the input to it. The current scene will be unloaded to save memory but you can pass its state so Router can save it. When the pushed scene is closed, the current scene will be loaded again and receive the output of the pushed scene.

Parameters ```input``` and ```state``` are optional.

#### Push the modal scene

```lua
router.push_modal(router_object, scene_name, input)
```

Pushes the new scene to the stack and passes the input to it. The current scene is kept in memory but is disabled. There's no need to save the state in this case. When the pushed scene is closed, the current scene will be enabled and receive the output of the pushed scene.

Parameter ```input``` is optional.

#### Show popup

```lua
router.popup(router_object, scene_name, input)
```

Pushed the new scene to the stack and passes the input to it. The current scene is kept in memory but the input focus will be revoked. When the popup scene is closed, the current scene will get input focus back and receive the output of the popup scene.

### Close scene

```lua
router.close(router_object, output, state)
```

When the scene is finished, you need to close it. You can pass the output to the router and save scene state. Both ```output``` and ```state``` parameters are optional.

## Handling Router messages in collection scripts

You need to handle two Router messages in your scene controller scripts: ```router.messages.scene_input``` and ```router.messages.scene_popped```. Handling the first one is mandatory, the second one should be handled only if you use ```push```, ```push_modal``` or ```popup``` Router functions in this scene.

Please note that ```router.messages.scene_input``` message is not sent when you return to the scene after ```push``` function, only ```router.messages.scene_popped``` is sent.

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
        self.router = message.router
        -- If you push scenes (push/push_modal/popup) in the scene,
        -- handle this message and pushed scene output in message.output
    elseif message_id == hash("select_level") then
        -- Example of using router close function
        router.close(self.router, {world = self.state.world, level = message.level}, self.state)
    end
end
```

---
If you have any questions or suggestions, feel free to contact me: megus.sugem@gmail.com

Created and maintained by Roman "Megus" Petrov / [Wise Hedgehog Studio](https://wisehedgehog.studio).
