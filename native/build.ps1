param(
    [Parameter(Mandatory)][string] $Godot,
    [Parameter(Mandatory)][string] $Zig,
    [string] $Destination = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$Godot = (Get-Command $Godot).Source
$Zig = (Get-Command $Zig).Source
$Destination = (New-Item -ItemType Directory -Force -Path $Destination).FullName
$scratch = (New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot '../outputs/native-build')).FullName
$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $scratch 'zig-cache'
$env:ZIG_LOCAL_CACHE_DIR = Join-Path $scratch 'zig-local'

Push-Location $scratch
try {
    & $Godot --headless --dump-gdextension-interface --dump-extension-api --log-file (Join-Path $scratch 'godot.log')
    if ($LASTEXITCODE -ne 0) { throw 'Godot could not dump the GDExtension API.' }
    $api = Get-Content -Raw extension_api.json | ConvertFrom-Json
    if ($api.header.version_major -ne 4 -or $api.header.version_minor -ne 7) {
        throw 'Build with the matching Godot 4.7 Windows x86-64 executable.'
    }
    $sizes = ($api.builtin_class_sizes | Where-Object build_configuration -eq 'float_64').sizes
    $methods = ($api.builtin_classes | Where-Object name -eq 'PackedFloat64Array').methods
    $vector = ($sizes | Where-Object name -eq 'Vector2').size
    if ($vector -ne 8) { throw 'The kernel expects the standard precision Godot build.' }
    @"
#pragma once
namespace abi {
constexpr int name_size = $(($sizes | Where-Object name -eq 'StringName').size);
constexpr int string_size = $(($sizes | Where-Object name -eq 'String').size);
constexpr int array_size = $(($sizes | Where-Object name -eq 'PackedFloat64Array').size);
constexpr long long size_hash = $(($methods | Where-Object name -eq 'size').hash);
constexpr long long resize_hash = $(($methods | Where-Object name -eq 'resize').hash);
}
"@ | Set-Content -Encoding ascii godot_abi.h

    $dll = Join-Path $Destination 'fire_kernel.windows.x86_64.dll'
    $flags = @('c++', '-target', 'x86_64-windows-gnu', '-O3', '-std=c++17', '-shared',
        '-fno-exceptions', '-fno-rtti', '-ffp-contract=off', '-s', "-I$scratch",
        "-Wl,--out-implib,$(Join-Path $scratch 'fire_kernel.lib')")
    & $Zig @flags (Join-Path $PSScriptRoot 'godot_bridge.cpp') (Join-Path $PSScriptRoot 'fire_kernel.cpp') `
        (Join-Path $PSScriptRoot 'thermal_network.cpp') -o $dll
    if ($LASTEXITCODE -ne 0) { throw 'Native kernel build failed.' }
    if ($Destination -ne $PSScriptRoot) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fire_kernel.gdextension') -Destination $Destination
    }
} finally {
    Pop-Location
}
