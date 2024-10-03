# MyUI

## A Bundle of my UI lua scripts into a single package. 

* `/lua run myui [mode]` to start the script
* modes are driver and client
  * Modes mostly pertain to Actor
  * Driver mode will enable the GUI for modules that use Actors and previously supported modes.
  * Client will still enable Actors but hide the windows until you toggle them on. 
* All Modules retain their original command line commands
* `/myui show` will toggle the config UI 
* The config UI state is saved and should only appear if you left it open , on first run, or you Toggle it.
* Toggling off a Module while it was already running currently just hides the module. It will not load that module on the next restart of MyUI.
* All save states are persistant, and you will by default start with the Config open and No Modules enabled.

## Adding more Modules (scripts)

This is possible and I will add documentation for it soon... let me get the ones I have included cleaned up some first.
