# CASC extraction

`casc-extract.ps1` pulls files straight out of the local World of Warcraft
install's data archives, so retail art never has to be downloaded or exported
by hand. It drives CASCExplorer's managed `CascLib.dll` (default location
`D:\Soft\CASCExplorer`) and resolves FileDataIDs against the community
`listfile.csv` that ships beside it. No network is involved.

```
# by FileDataID, written as <id>.<ext>
.\tools\casc\casc-extract.ps1 236562 -Out .\assets\textures\achievementicons

# by path, written under its own name
.\tools\casc\casc-extract.ps1 interface/icons/achievement_level_10.blp -Out D:\tmp -NameByPath

# id <-> path lookups
.\tools\casc\casc-extract.ps1 -Lookup 236562
.\tools\casc\casc-extract.ps1 -Lookup interface/questframe/questmaplogatlas.blp
```

`-Product` picks the install: `wow` (retail, the default), `wow_classic_era`,
`wow_classic`. `-Wow` is the root holding `.build.info` and `Data\`. Opening a
storage takes about five seconds; pass several files in one call.

`-HighRes` takes the high-resolution variant of a texture where the storage
holds one (most UI art ships in a low and a 2x high version; the client picks
by its texture quality setting). Without it you get the low one.

Atlas members (retail `UiTextureAtlasMember` rows) are not in the listfile;
their pixel rectangles come from wago.tools or NewEra's `Generated/AtlasData.lua`,
then the sheet is extracted here and cropped with Pillow (`blpload.py` in the
scratchpad reads the uncompressed BLP encoding Pillow lacks).
