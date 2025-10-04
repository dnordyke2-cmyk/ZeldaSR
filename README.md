# Zelda Shattered Realms (Alpha Framework)

## Build (via Docker)
```bash
docker run --rm --platform linux/amd64 -v "$PWD:/src" -w /src vieux/libdragon make clean all
```

## Run (macOS)
```bash
brew install mupen64plus     # if not installed yet
mupen64plus shattered_realms.z64
```

## Layout
- `assets/romfs/` — sprites, tiles, audio
- `src/` — game code (hud, dungeon, combat, audio)
