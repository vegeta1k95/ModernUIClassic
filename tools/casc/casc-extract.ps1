<#
.SYNOPSIS
Extract files from the local World of Warcraft CASC storage by FileDataID or path.

.DESCRIPTION
Reads the install's own data archives through CASCExplorer's managed CascLib.dll
(no network, no running client needed) and uses its community listfile.csv for
FileDataID <-> path lookups. The retail install carries every texture the
retail UI uses, so this is how retail art gets into the addon: look a file up,
extract it, drop it under assets/.

Products: "wow" (retail), "wow_classic_era", "wow_classic". The install root is
the folder holding .build.info and Data/.

Many UI textures exist in two variants in the storage: the one the client uses
at low texture quality, and a high-resolution one (usually 2x). -HighRes picks
the high-resolution variant where there is one; the retail UI at high texture
quality is drawn with those.

.EXAMPLE
.\casc-extract.ps1 236562 -Out ..\..\assets\textures\achievementicons
    writes 236562.blp (named by id)

.EXAMPLE
.\casc-extract.ps1 interface/icons/achievement_level_10.blp 904010 -Out D:\tmp -NameByPath
    writes achievement_level_10.blp and questmaplogatlas.blp

.EXAMPLE
.\casc-extract.ps1 -Lookup 236562
.\casc-extract.ps1 -Lookup interface/questframe/questmaplogatlas.blp
    prints the other half of the id <-> path pair
#>
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]] $Files,
    [string] $Out = ".",
    [string] $Wow = "D:\Games\World of Warcraft",
    [string] $Product = "wow",
    [string] $CascLib = "D:\Soft\CASCExplorer\CascLib.dll",
    [string] $ListFile = "D:\Soft\CASCExplorer\listfile.csv",
    [switch] $NameByPath,
    [switch] $HighRes,
    [string] $Lookup
)

$ErrorActionPreference = "Stop"

# listfile.csv rows are "<fdid>;<lowercase path>"
function Find-ByPath([string] $path) {
    $needle = ";" + $path.ToLower().Replace("\", "/")
    foreach ($line in [IO.File]::ReadLines($ListFile)) {
        if ($line.EndsWith($needle, [StringComparison]::Ordinal)) {
            return [int]$line.Substring(0, $line.IndexOf(";"))
        }
    }
    return $null
}

function Find-ById([int] $id) {
    $prefix = "$id;"
    foreach ($line in [IO.File]::ReadLines($ListFile)) {
        if ($line.StartsWith($prefix, [StringComparison]::Ordinal)) {
            return $line.Substring($prefix.Length)
        }
    }
    return $null
}

if ($Lookup) {
    if ($Lookup -match '^\d+$') {
        $path = Find-ById ([int]$Lookup)
        if ($path) { "$Lookup -> $path" } else { "$Lookup -> not in the listfile" }
    } else {
        $id = Find-ByPath $Lookup
        if ($id) { "$Lookup -> $id" } else { "$Lookup -> not in the listfile" }
    }
    return
}

if (-not $Files -or $Files.Count -eq 0) {
    Write-Error "Give FileDataIDs or paths to extract, or -Lookup <id|path>."
}

$null = [Reflection.Assembly]::LoadFrom($CascLib)
$config = [CASCLib.CASCConfig]::LoadLocalStorageConfig($Wow, $Product, $null)
$casc = [CASCLib.CASCHandler]::OpenStorage($config, $null)
$null = $casc.Root.SetFlags([CASCLib.LocaleFlags]::enUS, $false, [bool]$HighRes, $false)
"storage: $($config.BuildName)"

$outDir = (New-Item -ItemType Directory -Force $Out).FullName

foreach ($file in $Files) {
    $id = $null
    $path = $null
    if ($file -match '^\d+$') {
        $id = [int]$file
        $path = Find-ById $id
    } else {
        $path = $file.ToLower().Replace("\", "/")
        $id = Find-ByPath $path
        if (-not $id) { Write-Warning "$file is not in the listfile"; continue }
    }
    if (-not $casc.FileExists($id)) { Write-Warning "$id is not in this storage"; continue }

    $ext = if ($path) { [IO.Path]::GetExtension($path) } else { ".bin" }
    $name = if ($NameByPath -and $path) { [IO.Path]::GetFileName($path) } else { "$id$ext" }
    $target = Join-Path $outDir $name

    $in = $casc.OpenFile($id)
    try {
        $outStream = [IO.File]::Create($target)
        try { $in.CopyTo($outStream) } finally { $outStream.Dispose() }
    } finally { $in.Dispose() }
    "$id  $(if ($path) { $path } else { '?' })  ->  $target  ($((Get-Item $target).Length) bytes)"
}
