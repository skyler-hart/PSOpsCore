#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Standalone script to register PowerShell resource repositories without requiring PSOpsCore module.

.DESCRIPTION
    This standalone script can be run independently to register PowerShell resource repositories.
    It includes embedded functions and doesn't require the PSOpsCore module to be installed.
    Uses 1Password CLI to retrieve repository configuration.

.PARAMETER Name
    The name of the repository to register. If not specified, uses 1Password stored value.

.PARAMETER Uri
    The URI of the PowerShell resource repository. If not specified, uses 1Password stored value.

.PARAMETER Priority
    The priority of the repository (lower numbers = higher priority). Default is 5.

.EXAMPLE
    pwsh ./Standalone-RegisterPSResourceRepo.ps1
    Registers the repository using 1Password stored values.

.EXAMPLE
    pwsh ./Standalone-RegisterPSResourceRepo.ps1 -Name 'MyRepo' -Uri 'https://my-server.com/v3/index.json'
    Registers a custom PowerShell resource repository.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Name,

    [Parameter()]
    [string]$Uri,

    [Parameter()]
    [int]$Priority = 5
)

# Embedded platform detection function
function Get-PSOpsPlatform {
    if ($IsWindows) { return 'Windows' }
    if ($IsMacOS)   { return 'macOS' }
    if ($IsLinux)   { return 'Linux' }
    return 'Unknown'
}

# Embedded 1Password secret retrieval function
function Get-PSOpsCoreSecret {
    param([string]$Path)
    if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
        throw "1Password CLI 'op' not found. Install 1Password CLI and ensure you're signed in."
    }
    return & op read $Path
}

# Main logic
$os = Get-PSOpsPlatform
if ($os -match "Unknown|Unsupported") {
    throw "Unsupported OS: $os"
}

# Get values from 1Password if not provided as parameters
if (-not $Name) {
    try {
        $Name = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/repoName'
        Write-Verbose "Retrieved repository name from 1Password: $Name"
    } catch {
        throw "Failed to retrieve repository name from 1Password. Ensure you're signed in to 1Password CLI and the secret exists at: op://DevOps/PSResource Repository - PKGS-H/repoName"
    }
}

if (-not $Uri) {
    try {
        $Uri = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/repoUri'
        Write-Verbose "Retrieved repository URI from 1Password: $Uri"
    } catch {
        throw "Failed to retrieve repository URI from 1Password. Ensure you're signed in to 1Password CLI and the secret exists at: op://DevOps/PSResource Repository - PKGS-H/repoUri"
    }
}

# Check if Microsoft.PowerShell.PSResourceGet is available
$psresourceget = Get-Module -ListAvailable Microsoft.PowerShell.PSResourceGet

if ([string]::IsNullOrWhiteSpace($psresourceget)) {
    Write-Host "Installing Microsoft.PowerShell.PSResourceGet module..." -ForegroundColor Yellow
    Install-Module Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force
    Write-Host "Microsoft.PowerShell.PSResourceGet module installed successfully." -ForegroundColor Green
}

# Register the repository
Write-Host "Registering PowerShell resource repository '$Name' at $Uri" -ForegroundColor Cyan
try {
    Register-PSResourceRepository -Name $Name -Uri $Uri -Trusted -Priority $Priority
    Write-Host "Successfully registered PowerShell resource repository '$Name'" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "already exists") {
        Write-Warning "Repository '$Name' already exists. Use Unregister-PSResourceRepository to remove it first if you want to re-register."
    } else {
        throw "Failed to register repository '$Name': $($_.Exception.Message)"
    }
}

# Output usage information
Write-Host "`nRepository '$Name' is now registered and ready to use." -ForegroundColor Cyan
Write-Host "You can now:" -ForegroundColor Cyan
Write-Host "  - Find modules: Find-PSResource -Name <ModuleName> -Repository $Name" -ForegroundColor Gray
Write-Host "  - Install modules: Install-PSResource -Name <ModuleName> -Repository $Name" -ForegroundColor Gray
Write-Host "  - Publish modules: Publish-PSResource -Path <ModulePath> -Repository $Name -ApiKey <ApiKey>" -ForegroundColor Gray