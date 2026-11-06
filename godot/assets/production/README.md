# Production Art Packs

This folder is the runtime mount point for the game's non-placeholder production art.

## CC0 sources
- Quaternius Medieval Village MegaKit — textured modular medieval environment.
- Quaternius Stylized Nature MegaKit — textured trees, plants, flowers, rocks and ground details.
- Quaternius Universal Base Characters — rigged humanoid base characters and hairstyles.

Licenses are CC0-1.0 on the source pack pages. Keep each pack's original license notice beside imported files.

## Layout
- medieval_village/ — buildings, walls, roofs, doors, windows and settlement pieces
- nature/ — trees, plants, flowers, rocks and vegetation
- characters/ — humanoid bodies, hair and character variants

The game scans these directories at boot through ReleaseAssetRegistry. Missing packs do not crash the game; the existing authored fallback world remains available.
