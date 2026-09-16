# SPDX-License-Identifier: MIT
#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('Bootstrap', 'Doctor', 'CheckUpdates', 'Sync', 'Smoke', 'Rollback', 'Recover')]
    [string]$Action,
    [string]$MatlabRoot,
    [string]$LockFile,
    [string]$Cache,
    [string]$Output,
    [ValidateSet('new', 'existing', 'auto')][string]$Session,
    [switch]$Offline,
    [switch]$Latest,
    [ValidateRange(1, 3600)][int]$Timeout = 600,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$agentScript = Join-Path $PSScriptRoot 'agent_env.py'
$agentArguments = @($agentScript, $Action, '--timeout', "$Timeout")
foreach ($pair in @(@('--matlab-root', $MatlabRoot), @('--lock', $LockFile), @('--cache', $Cache), @('--output', $Output), @('--session', $Session))) {
    if ($pair[1]) { $agentArguments += $pair }
}
if ($Offline) { $agentArguments += '--offline' }
if ($Latest) { $agentArguments += '--latest' }
& $Python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'
if ($LASTEXITCODE -ne 0) { throw 'Python 3.11+ is required. Select it with -Python.' }
& $Python @agentArguments
exit $LASTEXITCODE
