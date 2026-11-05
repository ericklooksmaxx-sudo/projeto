# Hollow Logger: Discord Dumper, AI & Moderation Bot

Discord bot specialized in Lua/Luau script deobfuscation, obfuscator detection, an in-server AI assistant,
Roblox-UA requests, shortener bypass, credits, premium keys, full moderation, anti-raid, giveaways and announcements.

Everything runs inside the bot process. There is no separate website or API to deploy.

- **Prefix:** `.` (configurable in `.env`)
- **Language:** all bot responses are in English
- **Cost:** every command consumes **1 credit**, except the free ones listed below
- **Owner role:** unlimited credits

## Quick start

Requirements: Python 3.9+ (tested on 3.13), plus the tools listed under [Dumper tools](#dumper-tools).

```bash
pip install -r requirements.txt
cp .env.example .env      # then fill in DISCORD_TOKEN and the role IDs
python3 run.py
```

`./up.sh` starts the bot in the background (PID in `bot.pid`, output in `bot.log`) and `./down.sh` stops it.

Run the tests with `python3 -m unittest discover -s tests`.

## Free commands (no credits)

| Command | Description |
|---|---|
| `.help` | Show the full command menu (also by mentioning the bot with no other text) |
| `.daily` | Claim daily credits: regular **+5/day**, Premium balance topped up to **100** (never exceeds 100) |
| `.balance` | Check your credit balance and status |
| `.redeem <key>` | Redeem a premium key (`PREM-XXXX-XXXX-XXXX`) to activate Premium (the role is cosmetic; the key is the entitlement) |
| `.ping` | Bot latency |
| `.ai <message>` | Chat with Hollow Logger AI, or just mention the bot. Free; commands the AI runs on your behalf cost normal credits |
| `.imagine <prompt>` | Create images with AI (Premium only). Aliases: `.img`, `.image` |
| `.beautify [--rename]` | Beautify Lua/Luau code. Aliases: `.format`, `.pretty`, `.fmt`. `--rename` also infers readable variable names |
| `.minify` | Compress and minify Lua/Luau code. Aliases: `.mini`, `.compress`, `.min` |

## Credit system

- **Paid commands normally cost 1 credit.** Users with `0` credits cannot execute paid commands.
- **CEO and Owner roles** have **infinite credits** (never charged).
- **Admin role** receives **+50 credits per day** with `.daily`; **Staff role** receives **+25**.
- **Premium** (Premium role **or** an active redeemed key) gets topped up to **100 credits per day** (never above 100).
- **Regular users** get **+5 credits per day** with `.daily`.
- `.l` refunds your credit only when the dump fails completely. A **Partial Dump** result is charged normally.
- `.ai` chat is free. Commands it runs for you follow the normal rules; `.format`, `.beautify` and `.minify` are free.
- `.bypass` and `.imagine` are exclusive to **Premium members** and infinite-credit roles.

## Dumper & analysis (1 credit each)

| Command | Description |
|---|---|
| `.l` | Deobfuscates and reconstructs Lua/Luau scripts sent as an attachment (`.lua`, `.luau`, `.txt`), a code block, a direct link (Pastebin, GitHub raw, etc.) or by replying to a message. Specialized engines for **Prometheus / MoonSec V3**, **Luraph V15** and **MoonSec V2**, followed by an AST reconstruction and formatting pipeline (`darklua`, `namer`, `tidy`). Falls back to the [lune](https://github.com/lune-org/lune) dynamic dumper. Also reports **exposed webhooks** found in the script. Aliases: `.deobf`, `.dump`, `.reconstruct`, `.rebuild` |
| `.detect` | Detects which obfuscator was used and shows the verdict, the match and the confidence |
| `.get` / `.fetch` / `.getraw` | HTTP request to a URL using the official Roblox User-Agent (`Roblox/WinInetRobloxApp/0.673.0.6730711 (GlobalDist; RobloxDirectDownload)`). Returns the file attached with status and size. Links to private or internal addresses are refused |
| `.bypass <url>` | Resolves supported shorteners, key systems and ad-links (Premium only). Aliases: `.byp`, `.dlv`, `.unshorten` |

Every deobfuscated/recovered output starts with the official header:

```lua
--  [[ Logged by Hollow Logger https://discord.gg/UWjSZ5ugGJ ]]
```

Every failed or partial dump is archived under `dumps/errors/<id>/` as `obfuscated.lua`, `error.txt`, `result.lua`
(recovered output, with the header) and `metadata.json`. Delivered dumps are capped at 4 MB so they always fit as a
Discord attachment.

Links given to `.l`, `.detect`, `.format`, `.get` and the AI tools are downloaded through `netguard.py`: only
`http`/`https`, and any address (or redirect) that points at a private, loopback, link-local or otherwise internal
host is refused.

## AI assistant

Talk to Hollow Logger with `.ai <message>` or by mentioning the bot. Mentioning the bot with a prefixed command
(for example `@Hollow Logger .l`) still uses the normal deterministic command path.

- **What it can do:** explain every command, credits/premium and the official channels; run `.l`, `.detect`, `.fetch`,
  `.format`, `.beautify`, `.minify` and `.bypass` on your behalf; generate images; answer general questions.
- **Providers:** OpenRouter free models are tried first (strongest first), then NVIDIA NIM as fallback. Dead or
  rate-limited models are cooled down automatically. Set `OPENROUTER` and/or `NVIDIA_NIM` in `.env`.
- **Stream mode:** real-time token streaming with a live cursor and throttled Discord message updates.
- **Credits:** the chat itself is free; commands the assistant runs are charged normally and refunded on failure.
- **Privacy:** it does not reveal the model/provider behind it and never exposes the bot's source or configuration.

## Premium keys (Admin+)

| Command | Description |
|---|---|
| `.genkey <amount>` | Generate **1-50 unique keys** at once. Keys are listed in the channel and sent to your DMs |
| `.keys` | Key statistics (total / available / claimed / revoked) |
| `.revoke <key>` | Revoke a single key and remove the Premium role from whoever redeemed it |
| `.revoke @user` | Revoke **all** keys of a user and remove their Premium role |

## CEO management (CEO+)

| Command | Description |
|---|---|
| `.givecredits <@user\|id> <amount>` | Grant personal credits to any user. Aliases: `.addcredits`, `.givecredit`, `.addcredit` |

## Permission tiers

| Level | Role | Perks |
|---|---|---|
| 4 | Owner | Everything + **infinite credits** |
| 3 | CEO | **Infinite credits** + `givecredits` + all Admin/Staff commands |
| 2 | Admin | **+50 credits/day**, key system, ban, kick, clear, slowmode, lock, unlock, announcements, giveaways, antiraid |
| 1 | Staff | **+25 credits/day**, mute, warn, warnings, clear |
| 0 | Member | **+5 credits/day**, free + paid commands |

Members with an equal or higher tier than the moderator cannot be moderated (the Owner role is always protected).
Role IDs are set in `.env`.

## Moderation (1 credit each)

| Command | Level | Description |
|---|---|---|
| `.mute @user [duration]` | Staff+ | Timeout a member (`10m`, `1h`, `1d`; default 10m, max 28d) |
| `.unmute @user` | Staff+ | Remove a member's timeout |
| `.warn @user <reason>` | Staff+ | Issue a warning (saved, DMs the user) |
| `.warnings @user` | Staff+ | List a user's warnings |
| `.clear <1-100>` | Staff+ | Bulk delete messages |
| `.kick @user [reason]` | Admin+ | Kick a member |
| `.ban @user [reason]` | Admin+ | Ban a member (also works by raw user ID) |
| `.clearwarnings @user` | Admin+ | Clear a user's warnings |
| `.slowmode <0-21600\|off>` | Admin+ | Set channel slowmode |
| `.lock` / `.unlock` | Admin+ | Lock/unlock the current channel for @everyone |

## Anti-raid & security (Admin+)

```
.antiraid status                    show full config
.antiraid on / off                  enable/disable the system
.antiraid joins <n>                 max joins per minute before raid alert (default 8)
.antiraid action <timeout|kick|ban> action applied on raid detection (default timeout 1h)
.antiraid invite <on|off>           block server invite links
.antiraid spam <on|off>             block message spam (5 msgs / 3.5s or duplicates)
.antiraid mention <on|off> [max]    mass-mention guard (default 5 mentions)
.antiraid autorole <on|off>         auto-assign Member role on join
.antiraid log <#channel|off>        set the security log channel
```

Events are logged to the configured log channel: raid detection (join flood), anti-invite triggers, mass mentions and
spam (offenders are deleted and timed out).

## Utility (1 credit each)

| Command | Description |
|---|---|
| `.userinfo [@user]` | Full profile: roles, credits, warnings, join/creation dates |
| `.serverinfo` | Server overview: counts, boosts, roles, dates |
| `.avatar [@user]` | Full-size avatar |
| `.say <text>` | Repeat a message |
| `.embed <title> \| <text>` | Send a custom embed with a random color |
| `.poll <question>` | Create a thumbs up/down poll |

## Giveaways & announcements (Admin+)

| Command | Description |
|---|---|
| `.gstart <winners> <duration> <prize>` | Start a giveaway (e.g. `.gstart 2 1h 50 credits`), react to join, automatic draw |
| `.greroll <message_id\|link>` | Draw new winners for an ended giveaway |
| `.announce [#channel] <title> \| <message>` | Post a styled announcement embed |

Giveaways survive bot restarts and are processed by a background loop.

## Obfuscator detection

`.detect` uses signature rules (`fingerprint.py`) by default. If an ML model file is present, `classifier.py` uses it
instead:

- `weights.json` (or `weights.model`, a pickle) in the project root. It is a pure-Python TF-IDF (char 2-4 n-grams) +
  logistic regression export, so it needs no scikit-learn at runtime.
- The model is **not included** in this repository. Without it the bot answers from signatures, which are strong on
  Luraph, IronBrew, LuaObfuscator, MoonSec V3 and clean code and weaker on Prometheus/WeAreDevs, MoonSec V2 and Xen.
- Only load model files you trust: `weights.model` is a pickle.

## Project layout

```
run.py            main bot: commands, events, AI entry points, anti-raid loop, health-check server
assistant.py      AI layer: OpenRouter first, NVIDIA fallback, history and tool calling
unlink.py         shortener resolver (local decoders, PlatoRelay, Galactic)
wallet.py         credits database (data/wallet.json), premium daily cap
passes.py         premium keys database (data/passes.json)
guard.py          anti-raid config (data/guard.json) and detectors
draws.py          giveaways (data/draws.json) and warnings (data/strikes.json)
storage.py        the data/ folder
netguard.py       safe downloads: refuses private/internal addresses
sandbox.py        lune execution, partial recovery, error artifacts, webhook scan, output header
pipeline.py       specialized deobfuscators (Luraph V15, MoonSec V2/V3, Prometheus) and reconstruction
fingerprint.py    signature-based obfuscator detector
classifier.py     optional ML detector + VM heuristic; detect_best() is what `.detect` calls
tidy.py           token-safe readability formatter
namer.py          optional Luau variable-name inference
tracer.lua        the lune dumper / environment logger
env_shim.lua      environment API table used by the dumper
tools/            launchers for lune and darklua, unluac.jar, MoonSec build (Linux)
vendor/           third-party deobfuscator sources (see vendor/README.md)
tests/            unit tests
data/             runtime data (git-ignored)
dumps/            dumper output and error reports (git-ignored)
```

## Dumper tools

`.l`, `.format` and `.minify` need:

- **lune** and **darklua**: required. Put the binaries on `PATH`, or next to the launchers as
  `tools/lune-x86_64` / `tools/lune-aarch64` (and `tools/darklua-...`), or point `LUNE_BIN` / `DARKLUA_BIN` at them.
  The `Dockerfile` installs both.
- **Java**, **Node.js** and the **.NET runtime**: optional. They power the specialized engines (unluac, MoonSec V2 and
  Luraph V15, MoonSec V3). A missing tool only skips its engine; the lune dumper still runs. The `Dockerfile` does
  not install them.

## Docker and hosting

```bash
docker build -t hollow-logger .
docker run -d --name hollow-logger --env-file .env -p 8080:8080 \
  -v $(pwd)/data:/app/data -v $(pwd)/dumps:/app/dumps hollow-logger
```

Mount `data/`: it holds credits, premium keys, giveaways and warnings. The built-in health-check server on
`$PORT` (default `8080`) answers `GET /` and `GET /health` with `{"status": "online", ...}`, which keeps container
health checks green and allows free 24/7 pings (UptimeRobot and similar). Set `ENABLE_WEB_SERVER=false` to turn it off.
A `Procfile` is included for platforms that use one.

## Moving from the old layout

Environment variable names did not change. Move your runtime files into `data/` with their new names:

| Old file | New file |
|---|---|
| `credits.json` | `data/wallet.json` |
| `keys.json` | `data/passes.json` |
| `giveaways.json` | `data/draws.json` |
| `warnings.json` | `data/strikes.json` |
| `antiraid_config.json` | `data/guard.json` |
| `math_engine.json` / `math_engine.model` (optional) | `weights.json` / `weights.model` |

The bot no longer serves a website or `/api/*` routes and no longer calls any hosted service of its own. It still
talks to Discord, the AI providers, the image worker and the bypass resolver.

## Third-party credits

See [vendor/README.md](vendor/README.md): MoonsecDeobfuscator (tupsutumppu), Deobfuscator-Luraph-V15 (caomod2077),
Lua-Deobfuscator (SixZensED), hidelat-deobfuscator (axom), clyde-deobf (Oxygen Deobf), unluac, lune and darklua.
