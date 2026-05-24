# Building & Publishing Releases

How to build all four platform binaries and upload them to a GitHub release.

## Prerequisites

- **Godot 4.6.2** (headless CLI: `godot4`)
- **Export templates** for 4.6.2 installed (Editor → *Manage Export Templates*, or place them in `~/.local/share/godot/export_templates/4.6.2.stable/`)
- Export presets are already defined in `export_presets.cfg`: `Windows Desktop`, `Linux`, `macOS`, `Web`

## 1. Bump the version

The version string lives in four places. Bump them together (e.g. `v. 9` → `v. 10`):

- `scene/card_table.tscn`   — `lbl_title` text
- `scene/spider_table.tscn` — `lbl_title` text
- `scene/card_table.gd`     — `_ready()` sets `lbl_title.text`
- `scene/spider_table.gd`   — `_ready()` sets `lbl_title.text`

Quick way:

```bash
grep -rl 'v\. 9' scene/ | xargs sed -i 's/v\. 9/v. 10/g'
```

## 2. Build all four platforms

```bash
cd /path/to/Simple_Solitaire
rm -rf build && mkdir -p build/web

godot4 --headless --export-release "Windows Desktop" build/Solitaire.exe
godot4 --headless --export-release "Linux"           build/Solitaire.x86_64
godot4 --headless --export-release "macOS"           build/Solitaire.zip
godot4 --headless --export-release "Web"             build/web/index.html
```

If a card image was changed, reimport first: `godot4 --headless --import`.

## 3. Package into zips

There's no `zip` binary in some environments, so use Python:

```bash
cd build
python3 - <<'EOF'
import zipfile, os, shutil
def zf(name, *files):
    with zipfile.ZipFile(name, 'w', zipfile.ZIP_DEFLATED) as z:
        for f in files: z.write(f)
zf('Solitaire_win.zip',   'Solitaire.exe')
zf('Solitaire_linux.zip', 'Solitaire.x86_64')
shutil.copy('Solitaire.zip', 'Solitaire_macos.zip')   # macOS export is already a zip
with zipfile.ZipFile('Solitaire_web.zip','w',zipfile.ZIP_DEFLATED) as z:
    for f in os.listdir('web'): z.write(os.path.join('web', f), f)   # web files at zip root
EOF
```

Result, in `build/`:

| Platform | File |
|----------|------|
| Windows | `Solitaire_win.zip` |
| Linux | `Solitaire_linux.zip` |
| macOS | `Solitaire_macos.zip` |
| Web | `Solitaire_web.zip` |

## 4. Create the GitHub release & upload

### Option A — web UI

1. Go to <https://github.com/IronWolve/Simple_Solitaire/releases/new>
2. Tag: `v10` (create new tag). Title: `Simple Solitaire v. 10`.
3. Drag the four zips from `build/` into the assets area.
4. **Publish release.**

> Release assets allow up to 2 GB each. (The 25 MB limit only applies to files committed directly to the repo.)

### Option B — GitHub CLI

```bash
gh release create v10 \
  build/Solitaire_win.zip build/Solitaire_linux.zip \
  build/Solitaire_macos.zip build/Solitaire_web.zip \
  --title "Simple Solitaire v. 10" --notes "See README."
```

### Option C — curl (no gh installed)

```bash
TOKEN=<your_personal_access_token>      # needs 'repo' scope
REPO=IronWolve/Simple_Solitaire
TAG=v10

# create the release, capture its id
RID=$(curl -s -X POST -H "Authorization: token $TOKEN" \
  -d "{\"tag_name\":\"$TAG\",\"name\":\"Simple Solitaire $TAG\"}" \
  https://api.github.com/repos/$REPO/releases | grep -m1 '"id"' | grep -o '[0-9]\+')

# upload each asset
for f in build/Solitaire_win.zip build/Solitaire_linux.zip build/Solitaire_macos.zip build/Solitaire_web.zip; do
  curl -s -X POST -H "Authorization: token $TOKEN" -H "Content-Type: application/zip" \
    --data-binary @"$f" \
    "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=$(basename $f)" >/dev/null
  echo "uploaded $f"
done
```

## Notes

- **`build/` is gitignored** — binaries are distributed via Releases, not committed.
- **Web** is exported single-threaded (no cross-origin-isolation headers needed) so it can be hosted on any static server. It still requires HTTP — `file://` won't work.
- **macOS** build is universal (arm64 + x86_64) and unnotarized; users right-click → Open on first launch. (Requires `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`, already set.)
- **Personal access token:** create at <https://github.com/settings/tokens> with the `repo` scope. Never commit it.
