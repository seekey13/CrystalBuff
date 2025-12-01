# CrystalBuff

CrystalBuff is an Ashita v4 addon for Final Fantasy XI that automatically tracks and corrects your current crystal buff—Signet, Sanction, or Sigil—based on the zone you are in.

> **Note:**  
> This addon is designed **EXCLUSIVELY** for the [CatsEyeXI private server](https://www.catseyexi.com/) and will not function as intended on retail or other private servers.  
> The required commands (`!signet`, `!sanction`, `!sigil`) and zone assignments are specific to CatsEyeXI.


## Features

- **Automatic Detection:** Monitors your active buffs and determines which crystal buff (Signet, Sanction, or Sigil) is required for your current zone.
- **Buff Correction:** If you are missing the required buff for your zone, CrystalBuff will automatically attempt to apply the correct one by issuing the appropriate command.
- **Zone Awareness:** Recognizes the zones where each buff is needed—Signet (vanilla zones), Sanction (ToAU zones), Sigil (past zones)—and adapts as you move.
- **Smart Filtering:** Automatically ignores city zones, non-combat areas, and other safe zones where crystal buffs are not needed.
- **Command Cooldown:** Built-in 10-second cooldown prevents spam and conflicts with other addons.
- **Intelligent Delays:** Uses strategic delays to ensure buff data is fully updated before making corrections.
- **Debug Mode:** Optional verbose output for troubleshooting and monitoring addon behavior.
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

CrystalBuff runs automatically in the background. When you change zones or your buffs change, it will:

1. **Check your location:** Determines if you're in a zone that uses a crystal buff
2. **Verify your buffs:** Compares your current crystal buff against what's needed for the zone
3. **Apply corrections:** If needed, automatically issues the appropriate command to get the correct buff

### Intelligent Behavior
- **Safe Zone Detection:** Automatically ignores cities, towns, and other non-combat areas where buffs aren't needed
- **Rate Limiting:** Uses a 10-second cooldown between correction commands to prevent server command spam
- **Timing Optimization:** Employs strategic delays to ensure buff data is fully updated before making decisions
- **Error Resilience:** Robust error handling prevents crashes and provides helpful feedback

### When Corrections Happen
- If you have no crystal buff in a combat zone
- If you have the wrong crystal buff for your current zone (e.g., Signet in a ToAU zone)
- After zoning into a new area that requires a different buff


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

When debug mode is enabled, you'll see detailed information about:
- Current zone name and ID
- Required buff for the zone  
- Your current crystal buff status
- Buff correction actions

### Additional Commands
```
/crystalbuff zoneid
```
Displays your current zone name and ID for troubleshooting purposes.

> **Example Debug Output:**  
> [CrystalBuff] Current Zone: East Ronfaure (101)  
> [CrystalBuff] Required Buff: Signet  
> [CrystalBuff] Current Crystal Buff: None  
> [CrystalBuff] Mismatch detected, issuing command: !signet

### Available Commands
- `/crystalbuff debug` - Toggle debug mode on/off
- `/crystalbuff zoneid` - Show current zone name and ID


## Compatibility

- **Ashita v4** (required)
- **CatsEyeXI** server ONLY


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

## Changelog

### Version 1.4 (Current)
- Added event system detection to prevent commands during cutscenes/events
- Implemented 10-second startup delay after addon load for data initialization
- Implemented 10-second delay after zone-in before buff checks begin
- Improved timing logic to prevent premature buff corrections
- Enhanced world ready state detection for better reliability

### Version 1.3
- Added 1-second delay for buff change detection to improve accuracy
- Enhanced packet handling for more reliable zone and buff detection
- Improved error handling with comprehensive pcall usage

### Version 1.2  
- Added command cooldown system (10-second rate limiting)
- Implemented smart delays (2-second delay for commands to avoid conflicts)
- Added non-combat zone filtering (cities, towns, safe areas)
- Introduced debug mode with `/crystalbuff debug` command
- Added zone ID command `/crystalbuff zoneid` for troubleshooting
- Enhanced error handling and logging
- Improved zone change detection with packet-based monitoring

### Version 1.0
- Initial release with basic automatic buff detection and correction
- Support for Signet, Sanction, and Sigil buffs
- Zone-based buff requirements
