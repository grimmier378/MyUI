# MyUI

A MacroQuest LUA Script

## Description

This is a collection of the scripts I have written so far, bundled together and converted into Modules. This way you only need to run 1 command and have your choice of the currently 14 scripts to load at once. There is also a template included incase anyone wants to build their own modules or convert a script to a module.

## Getting Started

When you first load the script, you will be presented with a very simple GUI window.

All of the modules first come disabled, this way you can select the ones you would like to use. Settings are persistant, so the next time you run it you will have the same modules available.

You can add your own custom modules either with the Template inside `MQDIR/lua/MyUI/Modules` folder, you can also easily modify an existing script into a module.

Adding the Module to the GUI and your config can be done through either command line or the GUI. Removeing a custom added Module is currently done in the gui.

If you have **_DanNet_** running you will also have the option with a right click on either the minimized button window or the gear icon on the main window to start/stop other characters in client mode. Otherwise you can just issue `/lrun run myui client` to your other characters with whatever you use for comms.

**Actors Support** is included with many of the scripts I have written for passing your information to the driver from the clients. This does require them to all be running on the same PC.

**MyChat** if enabled will also function as the output channel for the modules. If you add a custom module see the information on the options available. Some modules will create their own Tab in mychat to write to and others will use the MyUI tab that is created. If you have the MyChat Module disabled then all module output will go to MQ console by default.

**Settings** are saved Per Character in `MQDIR/Config/MyUI/Server_Name/CharName.lua` files. so if you want to duplicate one characters settings it should be easier.

## Loading \ Unloading Modules.

You can load and unload modules either through command line or through the GUI.

When loading a Module we first close any existing versions of the same script running as a standalone.

## Adding more Modules (scripts)

This is possible and I will add documentation for it soon...

In the mean while you can check out the `template.lua` for some information as well as any of the existing modules.

## Commands and Startup.

### Commands:

- `/myui show` - Toggle the Main UI
- `/myui exit` - Exit the script
- `/myui load [moduleName]` - Load a module
- `/myui unload [moduleName]` - Unload a module
- `/myui new [moduleName]` - Add a new module

### Startup:

- `/lua run myui [client|driver]` - Start the Script in either Driver or Client Mode - **Default** (_Driver_) if not specified

## Media

https://www.youtube.com/watch?v=oECOqykjQfs
