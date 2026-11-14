param(
    [Parameter(Mandatory)][string] $Godot,
    [Parameter(Mandatory)][string] $WindowsTemplate,
    [string] $StressSave,
    [string] $Version = '3.4',
    [string] $Destination = (Join-Path $PSScriptRoot '../outputs/performance-3.4/Playtest')
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godotExe = (Get-Command $Godot).Source
$template = (Resolve-Path $WindowsTemplate).Path
$destination = (New-Item -ItemType Directory -Force $Destination).FullName
$kernelName = 'fire_kernel.windows.x86_64.dll'
$library = Join-Path $project "native/$kernelName"
if (!(Test-Path -LiteralPath $library)) {
    throw 'Build the Windows simulation kernel with native/build.ps1 before exporting.'
}

$pack = Join-Path $destination 'Firetender.pck'
& $godotExe --headless --path $project --export-pack 'Windows Desktop' $pack --log-file (Join-Path (Split-Path $destination) 'export-engine.log')
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $pack)) { throw 'Godot export failed.' }
Copy-Item -LiteralPath $template -Destination (Join-Path $destination 'Firetender.exe') -Force
$native = (New-Item -ItemType Directory -Force (Join-Path $destination 'native')).FullName
Copy-Item -LiteralPath $library -Destination (Join-Path $native $kernelName) -Force
$stressInstructions = ''
if ($StressSave) {
    Copy-Item -LiteralPath $StressSave -Destination (Join-Path $destination 'Chapter-II-stress.sav') -Force
    $stressInstructions = @'

The included Chapter-II-stress.sav starts with a dense 150-piece pile,
twelve drying logs and an active hearth. To load it, copy it as
slot-10.sav into an empty slot-10 in a Firetender profile directory
(%APPDATA%\Godot\app_userdata\Firetender - The Living Fire\profiles\profile-1
for Profile 1), then use Load from the title screen. A different unused
slot number from 01 through 10 works as well.
'@
}
@"
FIRETENDER $Version | Windows x86-64 playtest

Keep Firetender.exe, Firetender.pck and the native folder together.
Start Firetender.exe. The game uses the existing Firetender profile
location in Windows.

Start a new story and press F7 at the hearth to enter Chapter II practice.
Gather wood, stack it under cover and move one piece from the top, then
from the bottom. Keep nine to twelve damp logs around a substantial fire
and compare the 1x, 16x and 64x controls. The latter two can run below
their requested rate under load. Space pauses the hearth.
$stressInstructions
"@ | Set-Content -Encoding utf8 (Join-Path $destination 'Readme.txt')
Write-Output $destination
