# NVIDIA Shield + Jellyfin app-native playback handover

Date: 2026-03-28
Status: solved for reusable app-native playback through Jellyfin Android TV

## Final reusable solution

There is now a reliable app-native control path for two reusable cases:

1. Play next episode of a show
- resolve series + `NextUp` via Jellyfin API
- power on Shield if needed
- ADB SEARCH intent opens Jellyfin Android TV in a deterministic state
- Home Assistant `remote.shield` sends:
  - `DPAD_CENTER`
  - `DPAD_DOWN`
  - `DPAD_CENTER`
  - `DPAD_CENTER`
- verify through Jellyfin `/Sessions`

2. Play a movie
- resolve movie via Jellyfin API
- power on Shield if needed
- ADB launches Jellyfin Android TV directly to movie detail page using `ItemId`
- Home Assistant `remote.shield` sends:
  - `DPAD_CENTER`
- verify through Jellyfin `/Sessions`

These are implemented in the local CLI:
- `shield-jellyfin nextup 'Show Name'`
- `shield-jellyfin movie 'Movie Name'`

## Why this works

The final reliable control plane is hybrid:
- Jellyfin API for content resolution and verification
- ADB for deterministic app entry
- Home Assistant `remote.shield` for native DPAD/select actuation

What was rejected:
- Jellyfin server remote-play API: 204/no-op issues
- raw ADB keyevents as the primary actuator: inconsistent on Jellyfin pages
- direct stream URL fallback as the main solution: reliable but not app-native

## Environment

- Shield IP: `192.168.1.149`
- Jellyfin package: `org.jellyfin.androidtv`
- Jellyfin env file: `~/repo/universal-ingest/.env`
- Correct Jellyfin URL: `https://jellyfin.local.m720.bozydar.me`
- Home Assistant env file: `~/.hermes/.env`
- HA remote entity: `remote.shield`
- HA power-related entities observed: `media_player.shield_2`, `media_player.shield_3`

## Important config fix made

The file `~/repo/universal-ingest/.env` originally had the wrong Jellyfin host:
- wrong: `https://jellyfin.local.720.bozydar.me`
- correct: `https://jellyfin.local.m720.bozydar.me`

This was fixed.

## Reliable reusable flows

## A. Show next-up flow

### When to use
Use for commands like:
- play latest episode of show X
- play next episode of show X
- continue show X from next up

### Resolution
Resolve user, series, and `NextUp` via Jellyfin API.

Example pattern:

```bash
python3 - <<'PY'
import json, ssl, urllib.parse, urllib.request
from pathlib import Path

SHOW = 'Scarpetta'

env = {}
for line in Path('/home/rbw/repo/universal-ingest/.env').read_text().splitlines():
    line = line.strip()
    if line and not line.startswith('#') and '=' in line:
        k, v = line.split('=', 1)
        env[k] = v

base = env['JELLYFIN_URL']
headers = {'X-Emby-Token': env['JELLYFIN_API_KEY']}
ctx = ssl._create_unverified_context()

def get(path, params=None):
    url = base + path
    if params:
        url += '?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
        return json.load(r)

user = [u for u in get('/Users') if u.get('Name') == 'rbw'][0]
series = get('/Items', {
    'Recursive': 'true',
    'IncludeItemTypes': 'Series',
    'SearchTerm': SHOW,
    'UserId': user['Id'],
})['Items'][0]
nextup = get('/Shows/NextUp', {
    'UserId': user['Id'],
    'SeriesId': series['Id'],
})['Items'][0]
print(json.dumps({
    'series': series['Name'],
    'series_id': series['Id'],
    'nextup': nextup['Name'],
    'item_id': nextup['Id'],
    'season': nextup.get('ParentIndexNumber'),
    'episode': nextup.get('IndexNumber'),
}, indent=2))
PY
```

### App-native actuation

1. Force-stop and open SEARCH intent:

```bash
adb -s 192.168.1.149:5555 shell am force-stop org.jellyfin.androidtv
sleep 2
adb -s 192.168.1.149:5555 shell am start -a android.intent.action.SEARCH -n org.jellyfin.androidtv/.ui.startup.StartupActivity --es query 'Scarpetta'
sleep 4
```

2. Send this exact remote sequence via HA `remote.shield`:
- `DPAD_CENTER`
- `DPAD_DOWN`
- `DPAD_CENTER`
- `DPAD_CENTER`

Meaning:
- enter series card
- move from `Play all` to first `Next up` episode tile
- open episode detail page
- press `Play`

### Verification
Verify through Jellyfin `/Sessions` that Shield is now playing the resolved item id.

Expected example:
- `NowPlaying = Bridge of Time (1)`
- `SeriesName = Scarpetta`

## B. Movie flow

### When to use
Use for commands like:
- play The Matrix
- play movie X on Shield

### Resolution
Resolve the movie via Jellyfin API.
Prefer exact case-insensitive title match when multiple results appear.

Example pattern:

```bash
python3 - <<'PY'
import json, ssl, urllib.parse, urllib.request
from pathlib import Path

env = {}
for line in Path('/home/rbw/repo/universal-ingest/.env').read_text().splitlines():
    line = line.strip()
    if line and not line.startswith('#') and '=' in line:
        k, v = line.split('=', 1)
        env[k] = v

base = env['JELLYFIN_URL']
headers = {'X-Emby-Token': env['JELLYFIN_API_KEY']}
ctx = ssl._create_unverified_context()

def get(path, params=None):
    url = base + path
    if params:
        url += '?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
        return json.load(r)

user = [u for u in get('/Users') if u.get('Name') == 'rbw'][0]
items = get('/Items', {
    'Recursive': 'true',
    'IncludeItemTypes': 'Movie',
    'SearchTerm': 'The Matrix',
    'UserId': user['Id'],
}).get('Items', [])
print(json.dumps([
    {
        'Id': i.get('Id'),
        'Name': i.get('Name'),
        'Year': i.get('ProductionYear'),
    }
    for i in items[:10]
], indent=2))
PY
```

Observed target for `The Matrix`:
- id: `db5cacaec49392559fc183cb92f9451e`
- year: `1999`

### App-native actuation

1. Force-stop app.
2. Open Jellyfin Android TV directly to the movie detail page using `ItemId`:

```bash
adb -s 192.168.1.149:5555 shell am force-stop org.jellyfin.androidtv
sleep 2
adb -s 192.168.1.149:5555 shell am start -n org.jellyfin.androidtv/.ui.startup.StartupActivity --es ItemId db5cacaec49392559fc183cb92f9451e
sleep 4
```

3. Send one HA remote command:
- `DPAD_CENTER`

Meaning:
- focus is already on `Play` for a movie detail page
- center starts playback

### Verification
Verify through Jellyfin `/Sessions`:
- `NowPlaying = The Matrix`
- `Type = Movie`

## Power-on flow

The reusable power pattern is:
- call Home Assistant `media_player.turn_on` on both observed Shield entities
- wait until ADB reports `sys.boot_completed=1`

Example:

```bash
python3 - <<'PY'
import json, ssl, urllib.request, time, subprocess
from pathlib import Path

def load(path):
    env = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            env[k] = v
    return env

ha = load('/home/rbw/.hermes/.env')
ctx = ssl._create_unverified_context()
base = ha['HASS_URL'].rstrip('/')
headers = {
    'Authorization': f"Bearer {ha['HASS_TOKEN']}",
    'Content-Type': 'application/json',
}
for entity in ['media_player.shield_2', 'media_player.shield_3']:
    req = urllib.request.Request(
        base + '/api/services/media_player/turn_on',
        data=json.dumps({'entity_id': entity}).encode(),
        headers=headers,
        method='POST',
    )
    try:
        urllib.request.urlopen(req, context=ctx, timeout=10).read()
    except Exception:
        pass

for _ in range(25):
    subprocess.run(['adb', 'connect', '192.168.1.149:5555'], capture_output=True, text=True, timeout=10)
    r = subprocess.run(['adb', '-s', '192.168.1.149:5555', 'shell', 'getprop', 'sys.boot_completed'], capture_output=True, text=True, timeout=10)
    if r.returncode == 0 and r.stdout.strip() == '1':
        print('ready')
        break
    time.sleep(1)
PY
```

## Why the final design is split by content type

### Shows
- `SEARCH` intent is the reliable way to land in a deterministic series state
- direct `ItemId`/`VIEW` episode deep-linking did not result in reliable episode playback
- series detail page plus `Next up` navigation is what worked

### Movies
- direct `ItemId` open lands on the movie detail page correctly
- focus lands on `Play`
- one `DPAD_CENTER` is enough

So the reusable rule is:
- shows/nextup => `SEARCH`
- movies => direct `ItemId`

## What was tested and rejected

### Jellyfin remote-play API
Tested form:

```text
POST /Sessions/{sessionId}/Playing?itemIds=<ITEM_ID>&playCommand=PlayNow&controllingUserId=<USER_ID>&startPositionTicks=0
```

Result:
- can return `204`
- still no-op in practice

Rejected.

### Raw ADB keyevents as primary actuator
Tested:
- `KEYCODE_DPAD_CENTER`
- `KEYCODE_DPAD_DOWN`
- media keys
- coordinate taps

Result:
- useful for inspection
- unreliable for repeatable actuation on Jellyfin pages

Rejected as primary actuator.

### Direct-stream fallback as main solution
This worked through `Default Media Receiver`, but it is not app-native Jellyfin playback.

Kept only as a fallback concept, not primary solution.

## Existing reusable CLI

Local CLI:
- `~/repo/dotfiles-rbw/home/bin/shield-jellyfin`
- symlinked to `~/bin/shield-jellyfin`

Aliases in `~/repo/dotfiles-rbw/home/.zsh_aliases`:
- `sj`
- `sjn`

Current commands:

```bash
shield-jellyfin nextup 'Scarpetta'
shield-jellyfin movie 'The Matrix'
shield-jellyfin pause
shield-jellyfin resume
shield-jellyfin power-on
```

## Verification rules

Never trust only HTTP status codes or UI assumptions.

Success means Jellyfin `/Sessions` for the Shield shows the expected item id or name as now playing.

For shows:
- expected now playing item id matches resolved `NextUp` item id

For movies:
- expected now playing item id matches resolved movie item id

## Edge cases and caveats

1. `media_player.shield_2` and `media_player.shield_3` are inconsistent
- use for power-on attempts only
- do not use as authoritative playback truth

2. `remote.shield` is the critical control surface
- if this entity changes or disappears, the reliable app-native flow breaks

3. Shows flow currently assumes the first `Next up` tile is the target
- this is correct for the tested `NextUp` use case
- not yet a generic arbitrary season/episode chooser

4. Movie resolution prefers exact title match if available
- this matters for ambiguous titles
- if needed later, add year disambiguation explicitly

5. Self-signed Jellyfin cert
- direct Python/Jellyfin calls used `ssl._create_unverified_context()`

## If this breaks later

For show-nextup flow, re-check in this order:
1. ADB still connects
2. `remote.shield` still exists and responds
3. SEARCH intent still lands on series card
4. `DPAD_CENTER` still opens series detail page
5. `DPAD_DOWN` still moves to first `Next up` episode
6. `DPAD_CENTER` still opens episode detail page
7. final `DPAD_CENTER` still plays

For movie flow, re-check:
1. `ItemId` open still lands on movie detail page
2. `Play` is still focused by default
3. one `DPAD_CENTER` still starts playback

## Final implementation-ready statement

Reusable app-native playback is now ready for:
- play next episode of show X
- play movie Y

Implementation strategy:
- Jellyfin API for resolution + verification
- ADB for deterministic app entry
- Home Assistant `remote.shield` for actuation

This is the path to reuse and extend.
