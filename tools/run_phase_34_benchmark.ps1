param(
    [Parameter(Mandatory)][string] $Godot,
    [string] $Reference = '9b7c69d',
    [string] $Destination = (Join-Path $PSScriptRoot '../outputs/performance-3.4'),
    [double] $Seconds = 3
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = (Get-Command $Godot).Source
$out = (New-Item -ItemType Directory -Force $Destination).FullName
$referencePath = Join-Path $out 'reference'
$archive = Join-Path $out 'reference.zip'
$secondsArgument = $Seconds.ToString([Globalization.CultureInfo]::InvariantCulture)

& git -C $project archive --format=zip "--output=$archive" $Reference
if ($LASTEXITCODE -ne 0) { throw 'Could not archive the requested reference commit.' }
Expand-Archive -LiteralPath $archive -DestinationPath $referencePath -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'stockpile_benchmark.gd') -Destination (Join-Path $referencePath 'tools') -Force
foreach ($checkout in @($referencePath, $project)) {
    & $Godot --headless --editor --path $checkout --import
    if ($LASTEXITCODE -ne 0) { throw "Import failed for $checkout." }
}

$modes = @('architecture', 'architecture_actions', 'headless_architecture',
    'headless_architecture_actions', 'thermal_trace', 'headless_structure', 'promotion', 'headless_promotion')
foreach ($build in @('before', 'after')) {
    $checkout = if ($build -eq 'before') { $referencePath } else { $project }
    foreach ($mode in $modes) {
        $path = Join-Path $out "$build-$mode.jsonl"
        $settings = @('--headless')
        if ($mode -in @('architecture', 'architecture_actions', 'promotion')) {
            $settings = @('--resolution', '1920x1016')
        }
        & $Godot @settings --path $checkout --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- $path $mode $secondsArgument
        if ($LASTEXITCODE -ne 0) { throw "Benchmark failed for $build $mode." }
    }
}
& py -3 (Join-Path $PSScriptRoot 'compare_fire_architecture.py') $out
if ($LASTEXITCODE -ne 0) { throw 'The performance capture or replay comparison did not match.' }
