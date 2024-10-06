# MyUI

## A Bundle of my UI lua scripts into a single package.

When you first load the script, you will be presented with a very simple GUI window.

All of the modules first come disabled, this way you can select the ones you would like to use. Settings are persistant, so the next time you run it you will have the same modules available.
You can add your own custom modules either with the Template inside `MQDIR/lua/MyUI/Modules` folder, you can also easily modify an existing script into a module. Adding the Module to the GUI and your config can be done through either command line or the GUI. Removeing a custom added Module is currently done in the gui.

If you have DanNet running you will also have the option with a right click on either the minimized button window or the gear icon on the main window to start/stop other characters in client mode. Otherwise you can just issue `/lrun run myui client` to your other characters with whatever you use for comms. Actors Support is included with many of the scripts I have written for passing your information to the driver from the clients. This does require them to all be running on the same PC.

MyChat if enabled will also function as the output channel for the modules. If you add a custom module see the information on the options available. Some modules will create their own Tab in mychat to write to and others will use the MyUI tab that is created. If you have the MyChat Module disabled then all module output will go to MQ console by default.

Your settings are saved Per Character in `MQDIR/Config/MyUI/Server_Name/CharName.lua` files. so if you want to duplicate one characters settings it should be easier.

## Adding more Modules (scripts)

This is possible and I will add documentation for it soon... let me get the ones I have included cleaned up some first.

## Commands and Startup.

### Commands:

- `/myui show` - Toggle the Main UI
- `/myui exit` - Exit the script
- `/myui load [moduleName]` - Load a module
- `/myui unload [moduleName]` - Unload a module
- `/myui new [moduleName]` - Add a new module

### Startup:

- /lua run myui [client|driver] - Start the Sctipt in either Driver or Client Mode
- Default(Driver) if not specified

## Media
