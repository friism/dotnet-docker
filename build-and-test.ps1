[cmdletbinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("win", "linux")]
    [string]$Platform,
    [switch]$UseImageCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$dockerRepo="microsoft/dotnet"
$dirSeparator = [IO.Path]::DirectorySeparatorChar

if ($UseImageCache) {
    $optionalDockerBuildArgs=""
}
else {
    $optionalDockerBuildArgs = "--no-cache"
}

if ($Platform -eq "win") {
    $imageOs = "nanoserver"
    $tagSuffix = "-nanoserver"
}
else {
    $imageOs = "debian"
    $tagSuffix = ""
}

pushd $PSScriptRoot

$tags = [System.Collections.ArrayList]@()
Get-ChildItem -Recurse -Filter Dockerfile |
    where {$_.DirectoryName.TrimStart($PSScriptRoot) -like "*$dirSeparator$imageOs*"} |
    # sort in descending order to ensure runtime-deps get built before runtime to satisfy dependency
    Sort-Object {$_.DirectoryName} -Descending |
    foreach {
        $tag = "${dockerRepo}:" +
            $_.DirectoryName.
                Replace("$PSScriptRoot$dirSeparator", '').
                Replace("$dirSeparator$imageOs", '').
                Replace($dirSeparator, '-') +
            $tagSuffix
        $tags.Add($tag) | Out-Null
        Write-Host "--- Building $tag from $($_.DirectoryName) ---"
        $dockerfilePath = $_.DirectoryName + '\Dockerfile'
        Get-Content $dockerfilePath | docker build $optionalDockerBuildArgs -t $tag -
        if (-NOT $?) {
            throw "Failed building $tag"
        }
    }

popd

./test/run-test.ps1 -Platform $Platform

Write-Host "Tags built and tested:`n$($tags | Out-String)"
