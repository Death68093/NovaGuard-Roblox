# NovaGuard Anticheat

[Skip to Instructions](https://github.com/Death68093/NovaGuard-Roblox-Anticheat/blob/main/README.md#setup-instructions)

**Protect your game with a lightweight, high-performance anticheat that’s hard to bypass.**

---

## 🚀 Features

**Movement:** Speed, Jump, Teleport, Wall Climb, Flying, Infinite Jump, No Clip  
**World:** Gravity changes  
**UI & Camera:** FOV & GUI tampering  
**Player Integrity:** Valid humanoid check  
**File & Script:** Core file tampering, LocalScript injections  
**Remote Exploit:** Token-based Remote validation  

---

## ✅ Admin Tools
- Kick / Ban players  
- Fetch server logs  
- Dynamic online player list  
- Admin keybinds & role check  
- GUI-triggered actions  

---

## ⚙️ Customization
- Enable/disable checks  
- Adjust thresholds (speed, jump, FOV)  
- Whitelist trusted players  

---

## ⚡ Performance
- Single-loop heartbeat monitoring  
- Token validation for legit clients  
- Minimal server & client overhead  

---

**NovaGuard** keeps your game safe, fair, and fast.

## Setup Instructions
1. Place `NG_Server` in **ServerScriptService**.  
2. Place `NG_Client` in **StarterPlayerScripts**.  
3. Place `NG_Config` in **ReplicatedStorage**.  
4. Configure `NG_Config` for your game. (Default settings work for most games.)

## Important Note
If you leave **CheckForLocalScript** enabled, make sure you **do not have any files named `"LocalScript"`** in PlayerScripts or Backpack, otherwise the anti-cheat will trigger false positives. ( this feature will be improved! )
