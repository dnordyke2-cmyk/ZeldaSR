# Zelda Shattered Realms (Alpha Framework)

This repo contains the skeleton build environment for the Zelda Shattered Realms N64 ROM.

## Build (via GitHub Actions)
Every push triggers GitHub Actions to build the ROM in the cloud.  
Artifacts (.z64 ROM and romfs.dfs) will be available in the Actions tab.

## Build locally (Docker, optional)
```bash
docker run --rm --platform linux/amd64 -v "$PWD:/src" -w /src vieux/libdragon make clean all
```

## Run in Emulator (macOS)
```bash
brew install mupen64plus     # if not installed yet
mupen64plus shattered_realms.z64
```

## Layout
- `assets/romfs/` — sprites, tiles, audio
- `src/` — game code (hud, dungeon, combat, audio)
