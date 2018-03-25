# whDefRouter

A powerful screen manager for games built with [Defold Game Engine](https://www.defold.com).

Defold doesn't provide standard functions to implement complex navigation between game screens. The provided examples only show the general idea of switching screens with collection proxies, but your game usually has more than just two screens. So I came up with a plan to develop a reusable navigation solution. I took the inspiration from ```UINavigationContoller``` in iOS and React/Redux. My library was the first of its kind, but now other solutions also exist, e.g. [Monarch](https://www.defold.com/community/projects/88415/).

**Features:**

- Three different ways to navigate between screens:
	- State machine approach to navigation (which, I believe, suits games perfectly);
	- Navigation stack (with two variants of pushing the scene to the stack);
	- Popups.
- Synchronous or asynchronous loading of collections.
- Support for animated screen transitions.
- Support for "Loading..." screen.

The demo project provides code samples for all possible Router use cases.

[Try demo project online](https://megus.github.io/defold-router).

## Table of Contents

- [Setup](#setup)
- [Setting up the navigation](#setting-up-the-navigation)
	- [Scenes description table](#scenes-description-table)
	- [State Machine approach](#state-machine-approach)
	- [Using the navigation stack](#using-the-navigation-stack)
		- [Push a scene](#push-a-scene)
		- [Push a modal scene](#push-a-modal-scene)
		- [Show a Popup](#show-a-popup)
	- [Close scene](#close-scene)
- [Setting up animated scene transitions](#setting-up-animated-scene-transitions)
- [Setting up "Loading" screen](#setting-up-loading-screen)
- [Handling Router messages in collection scripts](#handling-router-messages-in-collection-scripts)

## Setup

Add the library zip URL as a [dependency](http://www.defold.com/manuals/libraries/#_setting_up_library_dependencies) to your Defold project: [https://github.com/Megus/defold-router/archive/master.zip](https://github.com/Megus/defold-router/archive/master.zip)

Create a game object (I recommend to name it ```scenes```) in the main collection with [collection proxies](https://www.defold.com/manuals/collection-proxy/) for all your scenes (I'm using the word "scene" for a screen). Proxy names must match the names of your collections. Don't forget that collection filename is not the same as collection name, so check that ```name``` properties of your collections are appropriately set.

Create the scenes description table Lua module (e.g., ```scenes.lua``` in the ```main``` folder) with the following sample content (see details below):

```lua
local M = {
	info = {},
	first_scene = "main_menu", -- Change to the name of your first scene
	routing = {}
}

return M
```

Create a script for ```scenes``` game object (recommended component name is ```router```). Import the router library, your scenes description table (described above), initialize the router in ```init``` function and call the router message handler in ```on_message``` function. Please, note that you need to save the router ID to use it later.

```lua
local router = require("wh_router.router") -- Require Router library
local scenes = require("main.scenes") -- Path to your scene description table

function init(self)
	msg.post(".", "acquire_input_focus")
	-- Create the router object with the main scene description table.
	-- The first scene will be loaded automatically.
	self.rid = router.new(scenes, "main:/scenes#router", "controller#script")
end

function on_message(self, message_id, message, sender)
	-- Handle router messages
	router.on_message(self.rid, message_id, message, sender)
	-- Handle other messages here
end
```

Function ```router.new``` accepts four parameters:

```lua
router.new(scenes, router_url, scene_controller_path, loader_url)
```

- The scene description table.
- URL string to the script of the game object with the proxies.
- The path to the controller script of your scenes. You should use the same name for all scenes (```controller#script``` is a good choice).
- Optional: URL of a "Loading..." component (only if you use it).

Now you can try to run your project and see that the Router loaded your first scene!

---

## Setting up the navigation

The Router treats each scene as a function which has some input parameters and returns some output. This approach is used to decouple scenes. Scenes also may have an internal state which the Router can persist between scene launches.

There are four ways to change scenes:

- Switch scenes according to rules defined by a routing table (state machine approach).
- Push a new scene to the stack with unloading the current one.
- Push a new scene to the stack, and keep the current one loaded, but disabled.
- Show a pop-up scene and keep the current one loaded and enabled.

### Scenes description table

The Scenes description table has three fields:

- ```info``` — a table with scene properties
- ```first_scene``` — the first scene
- ```routing``` — the rules to switch between scenes

#### ```info```

Each scene has three properties. You don't need to define all of them if any property is missing, the Router will use a default value. You can even skip a scene in the info table; the Router will use default values for all properties in this case.

Example:

```lua
info = {
	main_menu = {
		sync_load = true,			-- Load this scene synchronously? Default: false
		has_transitions = false,	-- Does this scene have in/out transition animations? Default: false
		show_loading = false		-- Show "Loading..." when loading? Default: false
	},
}
```

#### ```first_scene```

This field defines the first scene of your game. It can be a string, a table or a function.

- string — simply the name of the first scene
- table — you can pass some input to the first scene. Example: ```{"main_menu", {skip_tutorial = true}}```
- function — if you need to implement some logic to define the first scene (e.g., different scenes for iOS and Android), use this option. The function should return two values: scene name and scene input table (input table is optional)

### State Machine approach

```routing``` field of the scenes description table defines the rules of switching between scenes. It works as a state machine where states are your scene names. When you close a scene that was displayed using routing table, Router will check the ```routing``` table field with the same name as your closing scene. These fields, just like, the ```first_scene``` field of the Scene description table can be a string, a table or a function.

An example of a routing table:

```lua
routing = {
	-- Go to Level Selector from the Main Menu screen
	main_menu = "level_selector",

	gameplay = function (output)
		if output.win then
			return "win", {world = output.world, level = output.level}
		else
			return "fail", {world = output.world, level = output.level}
		end
	end,

	-- Go to Level Selector and pass some input to this scene
	fail = {"level_selector", {win = false}},
	win = {"level_selector", {win = true}}	
}
```

### Using the navigation stack

You can use a traditional stack-based navigation approach with the Router. You can also combine state machine approach with the stack navigation, which is very convenient.

#### Push a scene

```lua
router.push(router_id, scene_name, input)
```

Pushes the new scene to the stack and passes the input to it. The current scene will be unloaded to save memory, but you can pass its state so Router can save it. When the pushed scene is closed, the current scene will be loaded again and receive the output of the pushed scene.

Parameters ```input``` and ```state``` are optional.

#### Push a modal scene

```lua
router.push_modal(router_id, scene_name, input)
```

Pushes the new scene to the stack and passes the input to it. The current scene is kept in memory but is disabled. There's no need to save the state in this case. When the pushed scene is closed, the current scene will be enabled and receive the output of the pushed scene.

Parameter ```input``` is optional.

#### Show a popup

```lua
router.popup(router_id, scene_name, input)
```

Pushes the new scene to the stack and passes the input to it. The current scene is kept in memory, but the input focus will be revoked. When the popup scene is closed, the current scene will get input focus back and receive the output of the pop-up scene.

### Close scene

```lua
router.close(router_id, output, state)
```

When the scene is finished, you need to close it. You can pass the output to the router and save scene state. Both ```output``` and ```state``` parameters are optional.

---

## Setting up animated scene transitions

When you set ```has_transitions``` to ```true``` for a scene, the Router will send the special message to your scene to let you handle transitions.

Example part of ```on_message``` function:

```lua
if message_id == router.messages.transition then
	-- Do some animations according to transition type in message.t_type
end
```

There are four transition types; they're defined as constants in ```router.transition_types``` table:

- ```t_in``` — Show scene
- ```t_out``` — Hide scene
- ```t_back_in``` — Show scene after returning from a pushed scene
- ```t_back_out``` — Hide pushed scene

When the animation is finished, you must call ```router.finished_transition(router_id)``` function to let the Router continue its job.

The demo project has an example of fade in/fade out effect as the screen transition.

---

## Setting up "Loading" screen

Some collections may take a lot of time to load. It's good to show a user some "Loading..." message in this case. To do it, create a game object in your main collection and pass its full URL as a 4th parameter to ```router.new``` function. An example:

```lua
self.router_id = router.new(scenes, "main:/scenes#router", "controller#script", "main:/loader")
```

The Router will enable and disable this GO when needed. After enabling, the Router will send a message to this GO to let it initialize. The hash of this message is stored in ```router.messages.loader_start```. When the scene is loaded, the Router will send another message (hash is stored in ```outer.messages.loader_stop```) to let your GO finish. After this message is processed, you must call ```router.stopped_loader(message.router)``` function to let the Router disable this GO and show the loaded collection.

An example ```on_message``` function of "Loading..." GO:

```lua
function on_message(_, message_id, message, _)
	if message_id == router.messages.loader_start then
		gui.set_color(gui.get_node("loading"), vmath.vector4(1, 1, 1, 1))
	elseif message_id == router.messages.loader_stop then
		gui.set_color(gui.get_node("loading"), vmath.vector4(1, 1, 1, 1))
        gui.animate(gui.get_node("loading"), "color.w", 0, gui.EASING_LINEAR, 0.3, 0, function()
			router.stopped_loader(message.router)
        end)
	end
end
```

---

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
		self.rid = message.router
		-- Setup the scene according to the state in message.state
		-- Handle scene input contained in message.input
	elseif message_id == router.messages.scene_popped then
		self.rid = message.router
		-- If you push scenes (push/push_modal/popup) in the scene,
		-- handle this message and pushed scene output in message.output
	elseif message_id == router.messages.transition then
		-- Handle animated scene transitions
		if message.t_type == router.transition_types.t_in then
			-- Handle "in" transition
		end
	elseif message_id == hash("select_level") then
		-- Example of using router close function with sending the output and the scene state to persist
		router.close(self.rid, {world = self.state.world, level = message.level}, self.state)
	end
end
```

---

If you have any questions or suggestions, feel free to contact me: 

- [Defold forum thread](https://forum.defold.com/t/defold-ui-routing-library/3528)
- ```@megus``` at Defold Slack workspace.
- Email: megus@wisehedgehog.studio

Created and maintained by Roman "Megus" Petrov / [Wise Hedgehog Studio](https://wisehedgehog.studio).
