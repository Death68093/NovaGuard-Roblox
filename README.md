# NovaGuard-Roblox
An advanced anti-cheat system for Roblox

## Setup Instructions
1. Place `NG_Server` in **ServerScriptService**.  
2. Place `NG_Client` in **StarterPlayerScripts**.  
3. Place `NG_Config` in **ReplicatedStorage.Modules**.  
4. Add all RemoteEvents to **ReplicatedStorage**.  
5. Configure `NG_Config` for your game. (Default settings work for most games, default settings reccomended for most games)

## Important Notes
If you leave **CheckForLocalScript** enabled, make sure you **do not have any files named `"LocalScript"`** in PlayerScripts or Backpack, otherwise the anti-cheat will trigger false positives.

**Repo includes newest file. Find the appriopriate version in Releases to use an older version**