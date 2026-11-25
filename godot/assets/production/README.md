# Production Art Packs

Runtime mount point for the game's non-placeholder 3D art. `ReleaseAssetRegistry` reads
`manifest.json` here, `ReleaseProductionAssetIntegration` instantiates the models, and the
authored procedural world is hidden once at least 10 models load.

## Layout

| Folder | Pack | Source |
| --- | --- | --- |
| `medieval_village/` | Quaternius Medieval Village MegaKit | https://quaternius.itch.io/medieval-village-megakit |
| `nature/` | Quaternius Stylized Nature MegaKit | https://quaternius.itch.io/stylized-nature-megakit |
| `characters/` | Quaternius Universal Base Characters | https://quaternius.itch.io/universal-base-characters |
| `buildings_extra/` | Quaternius Modular Medieval Pack | https://quaternius.com |
| `characters_extra/` | Quaternius Ultimate Animated Character Pack | https://quaternius.com |
| `animals/` | Quaternius Farm Animals Pack | https://quaternius.com |
| `crops/` | Quaternius Nature Crops Pack | https://quaternius.com |
| `creatures/` | Quaternius Animated Monster Pack | https://quaternius.com |

All of the above are CC0-1.0. Keep each pack's license notice beside its files.

## Installing a pack

```bash
scripts/install_production_packs.sh nature ~/Downloads/Stylized-Nature-MegaKit.zip
```

The script copies `.glb` / `.gltf` (+ `.bin`, textures) into the right folder, re-imports the
project, regenerates `manifest.json`, and prints the QA command. Prefer **GLB**: it embeds its
textures, so each model is a single self-contained file.

## Why a manifest

An exported Godot build packages the *imported* `.scn` of each model, not the raw `.glb`.
A runtime directory scan therefore found nothing inside an APK and the game silently stayed on
fallback geometry even with a full pack installed. `qa/generate_asset_manifest.gd` records the
model paths before export; the registry reads that file inside the packaged build, and the loader
resolves each path through `ResourceLoader`, which handles the import remap. CI runs the generator
before exporting.

## Build size

The packs are the dominant contributor to the APK, not the code (all 77 scripts plus the engine
template are about 29 MB):

| Installed packs | Approximate APK |
| --- | --- |
| none (current) | ~29 MB |
| nature + village + characters (374 MB of archives) | ~400–450 MB |
| all eight packs | well over 500 MB |

No size target is padded with generated noise files: the number grows when real models, textures
and audio are added.
