$tasks = Get-ChildItem -Filter "*Task" -Directory

$manifest = Get-Content -Path ".\vss-extension.json" -Force | ConvertFrom-Json

$version = $manifest.version
$versionParts = $version.Split(".")

$majorVersion = $versionParts[0]
$minorVersion = $versionParts[1]
$patchVersion = $versionParts[2]

foreach ($task in $tasks)
{
    Copy-Item -Path .\ps_modules -Destination $task.FullName -Recurse -Force
    
    $taskManifestPath = Join-Path -Path $task.FullName -ChildPath "task.json"
    $taskManifest = Get-Content -Path $taskManifestPath -Force | ConvertFrom-Json

    $taskManifest.version.Major = $majorVersion
    $taskManifest.version.Minor = $minorVersion
    $taskManifest.version.Patch = $patchVersion

    $taskManifest | ConvertTo-Json -Depth 3 | Set-Content -Path $taskManifestPath -Force
}