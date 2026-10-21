# paws.swiggy.glazer

Client-side Northstar mod for Titanfall 2. It watches in-game chat and, when one of the players you configured says anything, replies with a random glaze line from `glaze.txt`.

Every line is used at most once per match, so it never repeats itself in the same game. The used-line list is reset automatically on the next map, or manually with `glaze_reset`.

## Install

1. Copy this whole folder into your Northstar `mods/` directory, so it ends up as `mods/paws.swiggy.glazer/`.
2. Launch the game and open **Mod Settings**.
3. Open the **paws.swiggy.glazer** section and set your targets.

This mod is client-side only. It does not need to be installed on the server and does not affect other players' mods.

## Settings

| Setting | Meaning |
| --- | --- |
| Glazer enabled | Off / On |
| Target usernames | Comma separated player account names. Matching ignores a leading clan tag in the displayed name. |
| Chance to reply per message | Percent chance. `100` replies to every matching message. |
| Minimum seconds between replies | Cooldown so a chatty target does not flood chat. |
| Delay before replying | Optional delay before the reply is sent. |
| Prefix before each glaze | Optional text such as `glaze: ` in front of every line. |
| Maximum reply length | Trims long lines at a word boundary. `0` disables trimming. |
| Reply channel | Always global, or the same channel the target used (team chat stays team chat). |
| Console debug output | Prints every reply to the console. |

## Console commands

| Command | Meaning |
| --- | --- |
| `glaze_who` | Prints account and displayed names for every player. Remote UIDs are not exposed to client scripts. |
| `glaze_add <name>` | Adds a username to the target list. |
| `glaze_status` | Shows settings and how many lines are still unused. |
| `glaze_reset` | Makes every line available again. |
| `glaze_test` | Sends one random glaze immediately. |

This mod matches players by username. Northstar exposes the local player's UID to client scripts, but not remote players' UIDs, so UID targeting is unavailable for a client-only mod that works on vanilla servers.

## Data

`mod/scripts/vscripts/sh_glazer_data.nut` is generated from `glaze.txt` (one line per glaze, the leading number stripped). To change the lines, edit `glaze.txt` and regenerate that file, or edit the array directly.
