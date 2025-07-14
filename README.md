# CrystalBuff

CrystalBuff is an Ashita v4 addon for Final Fantasy XI that automatically tracks and corrects your current crystal buff—Signet, Sanction, or Sigil—based on the zone you are in.

> **Note:**  
> This addon is designed **EXCLUSIVELY** for the [CatsEyeXI private server](https://www.catseyexi.com/) and will not function as intended on retail or other private servers.  
> The required commands (`!signet`, `!sanction`, `!sigil`) and zone assignments are specific to CatsEyeXI.

## Features

- **Automatic Detection:** Monitors your active buffs and determines which crystal buff (Signet, Sanction, or Sigil) is required for your current zone.
- **Buff Correction:** If you are missing the required buff for your zone, CrystalBuff will automatically attempt to apply the correct one by issuing the appropriate command.
- **Zone Awareness:** Recognizes the zones where each buff is needed—Signet (vanilla zones), Sanction (ToAU zones), Sigil (past zones)—and adapts as you move.
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

### Supported Buffs

| Buff    | ID  | Applies In             | Command     |
|---------|-----|------------------------|-------------|
| Signet  | 118 | Vanilla zones (0-184)  | `!signet`   |
| Sanction| 119 | ToAU zones (185-254)   | `!sanction` |
| Sigil   | 120 | Past zones (255-294)   | `!sigil`    |

> **Note:** These zone ID ranges and commands are specific to CatsEyeXI.

## Output

CrystalBuff will print its actions in the chat log, including:
- The current zone and required buff.
- Your current crystal buff.
- Any mismatches detected and corrective actions taken.

Example output:
```
[CrystalBuff] Current Zone: Bastok Markets (234)
[CrystalBuff] Required Buff: Sanction
[CrystalBuff] Current Crystal Buff: Signet
[CrystalBuff] Mismatch detected, issuing command: !sanction
```

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
