<#
.SYNOPSIS
    Runs the Antistasi automated tests. Shortcut for Tools\AutoTest\launch_tests.ps1, all parameters are passed through.

.EXAMPLE
    .\launch_tests.ps1
    .\launch_tests.ps1 -Test smoke_* -NoBuild
    .\launch_tests.ps1 -List
    Get-Help .\Tools\AutoTest\launch_tests.ps1 -Detailed
#>
& (Join-Path $PSScriptRoot 'Tools\AutoTest\launch_tests.ps1') @args
exit $LASTEXITCODE
