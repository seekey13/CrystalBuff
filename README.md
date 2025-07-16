# CrystalBuff

CrystalBuff is an Ashita v4 addon for Final Fantasy XI that automatically tracks and corrects your current crystal buff—Signet, Sanction, or Sigil—based on the zone you are in.

> **Note:**  
> This addon is designed **EXCLUSIVELY** for the [CatsEyeXI private server](https://www.catseyexi.com/) and will not function as intended on retail or other private servers.  
> The required commands (`!signet`, `!sanction`, `!sigil`) and zone assignments are specific to CatsEyeXI.


## Features

- **Automatic Detection:** Monitors your active buffs and determines which crystal buff (Signet, Sanction, or Sigil) is required for your current zone.
- **Buff Correction:** If you are missing the required buff for your zone, CrystalBuff will automatically attempt to apply the correct one by issuing the appropriate command.
- **Zone Awareness:** Recognizes the zones where each buff is needed—Signet (vanilla zones), Sanction (ToAU zones), Sigil (past zones)—and adapts as you move.
- **Performance Optimized:** Features caching, debouncing, and memory management for minimal impact on gameplay.
- **Smart Filtering:** Automatically skips buff checks in cities and safe zones where buffs aren't needed.
- **Command Cooldowns:** Built-in 10-second cooldown prevents command spam to server.
- **Enhanced Commands:** Debug mode, status reporting, and zone information commands for troubleshooting.
- **Minimal Setup:** No configuration required. Just load the addon and let it keep your crystal buff up-to-date.


## Installation

1. Download or clone this repository into your Ashita v4 `addons` folder:

   ```
   git clone https://github.com/seekey13/CrystalBuff.git
   ```

2. Start or restart Ashita.
3. Load the addon in-game:

   ```
   /addon load crystalbuff
   ```

## Usage

CrystalBuff runs silently in the background. When you change zones or your buffs change, it will check if you have the correct crystal buff for your region:

- If you do, nothing happens.
- If you don't, it will automatically issue the appropriate command in chat to apply the correct buff.

## Commands
CrystalBuff includes several commands for monitoring and troubleshooting:

```
/crystalbuff debug    - Toggle debug output on/off
/crystalbuff status   - Show comprehensive addon status
/crystalbuff zoneid   - Display current zone name and ID
/crystalbuff check    - Manually trigger a buff check
/crystalbuff suppress - Toggle zone change buff suppression
/crystalbuff help     - Show all available commands
```

**Debug Mode:** When enabled, shows detailed information about zone detection, buff requirements, and decision-making process.

**Status Command:** Displays current zone, required buff, active buff, debug mode state, world readiness, zone change suppression, and cache statistics.

**Suppress Command:** Toggles whether buff update checks are suppressed during zone transitions to reduce redundant processing.


## Supported Buffs
`Signet`<img width="16" height="16" alt="Signet_29" src="https://github.com/user-attachments/assets/bf734529-5be3-454f-9c22-b9a94db5037d" />, 
`Sanction`<img width="16" height="16" alt="Sanction_29" src="https://github.com/user-attachments/assets/a0df9583-9263-49e5-94f9-6a3a3de5d447" /> & 
`Sigil`<img width="16" height="16" alt="Sigil_29" src="https://github.com/user-attachments/assets/0b7739d3-a903-4143-8494-bf839d22179b" />


## Output
By default, CrystalBuff runs silently in the background with minimal output.

### Debug Mode

Enable detailed output with:
```
/crystalbuff debug
```

**Debug Output Examples:**
```
[CrystalBuff] Current Zone: East Ronfaure (106)
[CrystalBuff] Required Buff: Signet
[CrystalBuff] Current Crystal Buff: None
[CrystalBuff] Mismatch detected, issuing command: !signet
```

**City Zone (No Action Needed):**
```
[CrystalBuff] Zone "Southern San d'Oria" (230) is a non-combat/city zone. No buff check needed.
```

### Status Information

Use `/crystalbuff status` to see comprehensive addon information:
```
=== CrystalBuff Status ===
Zone: East Ronfaure (106)
Required Buff: Signet
Current Buff: Signet
Debug Mode: ON
Cache Size: 12 zones
```

### Performance Features

- **Command Cooldown:** 10-second minimum between buff commands prevents spam
- **Zone Caching:** Reduces API calls for improved performance  
- **Smart Filtering:** Automatically skips checks in cities and safe zones
- **Debounced Checking:** Limits buff checks to once per 0.5 seconds
- **World Readiness Detection:** Initial buff check waits for proper world initialization via RoE packet
- **Zone Transition Optimization:** Configurable suppression of redundant buff checks during zone changes

### Timing and Initialization

CrystalBuff uses intelligent timing to ensure reliable operation:

- **World Readiness:** The addon waits for the Records of Eminence (RoE) packet before performing the initial buff check, ensuring the game world is fully loaded
- **Fallback Safety:** If the RoE packet doesn't arrive within 10 seconds, a fallback check is performed to prevent hanging
- **Buff Update Delays:** Small delays after buff update packets ensure memory is properly updated before checking
- **Zone Change Handling:** Proper synchronization with zone transition packets


## Compatibility

- **Ashita v4** (required)
- **CatsEyeXI** server ONLY
- **Version:** 1.3

## Performance

Version 1.3 includes significant performance improvements:
- Advanced caching system reduces API calls
- Memory-efficient buff comparison 
- Optimized zone detection and packet handling
- Minimal CPU and memory footprint


## License

MIT License. See [LICENSE](LICENSE) for details.


## Credits

- Author: Seekey
- Inspired by the annoyance of forgetting your Signet/Sanction/Sigil.


## Support

Open an issue or pull request on the [GitHub repository](https://github.com/seekey13/CrystalBuff) if you have suggestions or encounter problems.


## Special Thanks

[Commandobill](https://github.com/commandobill), [Xenonsmurf](https://github.com/Xenonsmurf), [atom0s](https://github.com/atom0s), and [Carver](https://github.com/CatsEyeXI)

Completely unnecessary AI generated image  
<img width="200" height="200" alt="CrystalBuff-transparent" src="https://github.com/user-attachments/assets/7be56b46-c39f-4234-8e8b-d8c7cb3b5fd0" />
