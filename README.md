# NovaGuard Anticheat

**Protect your game with a lightweight, high-performance anticheat that’s fully customizable and hard to bypass.**

---

## 🚀 Features

### Movement Protection
- **Speed** – Detects unnatural movement speeds.  
- **Jump Power / Height** – Flags abnormal jumps.  
- **Teleportation** – Stops instant position changes.  
- **Spider / Wall Climb** – Detects walking on walls or ceilings.  
- **Platform / Flying** – Detects standing on invisible platforms or flying.  
- **Infinite Jump** – Prevents repeated mid-air jumps.  
- **No Clip** – Blocks passing through walls and floors.

### World Protection
- **Gravity Change** – Detects client-side gravity modifications.  

### UI & Camera Protection
- **FOV Changes** – Ensures players use your intended camera settings.  
- **CoreGui / PlayerGui Modifications** – Detects any unauthorized UI changes.

### Player Integrity
- **Humanoid Existence** – Confirms players have a valid character setup.  

### File & Script Protection
- **Anticheat File Removal** – Kicks players who tamper with core files.  
- **LocalScript Injections** – Detects injected scripts in PlayerScripts or Backpack.  

### Remote / Exploit Prevention
- **Token-Based Remote Validation** – Blocks fake RemoteEvent or RemoteFunction calls.

---

## ⚙️ Customization
- Enable or disable any check in the config file.  
- Adjust thresholds like max speed, jump height, gravity, and FOV.  
- Whitelist trusted players to bypass specific checks.  

---

## ⚡ Performance
- Optimized single-loop heartbeat monitoring for multiple checks.  
- Token-based validation ensures only legitimate client responses are accepted.  
- Minimal overhead on both server and client.

---

**NovaGuard** keeps your game safe, fair, and fun — without slowing it down.  


## Setup Instructions
1. Place `NG_Server` in **ServerScriptService**.  
2. Place `NG_Client` in **StarterPlayerScripts**.  
3. Place `NG_Config` in **ReplicatedStorage**.  
4. Configure `NG_Config` for your game. (Default settings work for most games.)

## Important Note
If you leave **CheckForLocalScript** enabled, make sure you **do not have any files named `"LocalScript"`** in PlayerScripts or Backpack, otherwise the anti-cheat will trigger false positives. ( this feature will be improved! )
