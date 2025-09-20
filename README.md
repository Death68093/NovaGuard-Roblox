# NovaGuard-Roblox
A robust anti-cheat system for Roblox games.

## Setup Instructions
1. Place `NG_Server` in **ServerScriptService**.  
2. Place `NG_Client` in **StarterPlayerScripts**.  
3. Place `NG_Config` in **ReplicatedStorage**.  
4. Add all RemoteEvents (`NG_Pass`, `NG_Fail`, `NG_Check`, `NG_Exists`, `NG_GetVal`, `NG_Find`) to **ReplicatedStorage**.  
5. Configure `NG_Config` for your game. (Default settings work for most games.)

## Important Note
If you leave **CheckForLocalScript** enabled, make sure you **do not have any files named `"LocalScript"`** in PlayerScripts or Backpack, otherwise the anti-cheat will trigger false positives.
