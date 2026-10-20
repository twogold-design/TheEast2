# Jiangnan style v4

This is the current playable building tier. The v3, v2 and realistic packs are
kept as fallbacks.

V4 replaces the broad roof strips used in v3 with overlapping, staggered clay
tiles, rounded tile lips, ridge caps and end ornaments. Facades add framed lime
plaster, timber lattice windows, eave brackets, paving, hanging shop banners and
stronger dark-wood outlines. Residential, market and tea assets also include a
small canal edge, stone bank and clustered willow planting so placed buildings
read as part of a Jiangnan water town from the planning camera.

The exported models are consolidated to one mesh per material. This retains the
authored roof silhouette while avoiding hundreds of separate tile draw nodes in
Godot.

Files:

- `models/*.glb`: seven game-ready buildings
- `models/jiangnan_style_v4_manifest.json`: asset and geometry inventory
- `source/jiangnan_style_v4_gallery.blend`: editable Blender source
- `previews/jiangnan_style_v4_gallery.png`: rendered look-development preview
- `tools/generate_jiangnan_style_assets_v4.py`: deterministic generator

Run `重新生成江南水墨资源.bat` from the project root to rebuild the tier. The
batch file redirects Blender user data, logs and temporary files to this project
on the M drive.
