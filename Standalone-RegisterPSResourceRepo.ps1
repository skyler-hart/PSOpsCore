#requires -Version 5.1
<#
.SYNOPSIS
    Standalone script to register PowerShell resource repositories without requiring PSOpsCore module.

.DESCRIPTION
    This standalone script can be run independently to register PowerShell resource repositories.
    It includes embedded functions and doesn't require the PSOpsCore module to be installed.
    Uses 1Password CLI to retrieve repository configuration.
    Compatible with PowerShell 5.1 and later versions.

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

# Embedded platform detection function (PowerShell 5.1+ compatible)
function Get-PSOpsPlatform {
    # PowerShell 6+ has automatic variables
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($IsWindows) { return 'Windows' }
        if ($IsMacOS)   { return 'macOS' }
        if ($IsLinux)   { return 'Linux' }
    }
    
    # PowerShell 5.1 detection
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        if ($env:OS -eq 'Windows_NT' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {
            return 'Windows'
        }
    }
    
    # Fallback detection for other versions
    if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
        return 'Windows'
    } elseif ([System.Environment]::OSVersion.Platform -eq 'Unix') {
        if (Test-Path '/System/Library/CoreServices/SystemVersion.plist') {
            return 'macOS'
        } else {
            return 'Linux'
        }
    }
    
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

# Determine which PowerShell Gallery module to use based on PowerShell version
$psVersion = $PSVersionTable.PSVersion.Major
$useNewPSResourceGet = $psVersion -ge 7

if ($useNewPSResourceGet) {
    # PowerShell 7+ - prefer Microsoft.PowerShell.PSResourceGet
    $psresourceget = Get-Module -ListAvailable Microsoft.PowerShell.PSResourceGet
    
    if ([string]::IsNullOrWhiteSpace($psresourceget)) {
        Write-Host "Installing Microsoft.PowerShell.PSResourceGet module..." -ForegroundColor Yellow
        Install-Module Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force
        Write-Host "Microsoft.PowerShell.PSResourceGet module installed successfully." -ForegroundColor Green
    }
    
    # Register the repository using PSResourceGet
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
} else {
    # PowerShell 5.1 - use traditional PowerShellGet
    $powershellget = Get-Module -ListAvailable PowerShellGet
    
    if ([string]::IsNullOrWhiteSpace($powershellget)) {
        Write-Host "Installing PowerShellGet module..." -ForegroundColor Yellow
        Install-Module PowerShellGet -Scope CurrentUser -Force
        Write-Host "PowerShellGet module installed successfully." -ForegroundColor Green
    }
    
    # Register the repository using PowerShellGet
    Write-Host "Registering PowerShell repository '$Name' at $Uri" -ForegroundColor Cyan
    try {
        # PowerShellGet uses different parameter names
        Register-PSRepository -Name $Name -SourceLocation $Uri -InstallationPolicy Trusted
        Write-Host "Successfully registered PowerShell repository '$Name'" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -match "already exists") {
            Write-Warning "Repository '$Name' already exists. Use Unregister-PSRepository to remove it first if you want to re-register."
        } else {
            throw "Failed to register repository '$Name': $($_.Exception.Message)"
        }
    }
}

# Output usage information
Write-Host "`nRepository '$Name' is now registered and ready to use." -ForegroundColor Cyan
Write-Host "You can now:" -ForegroundColor Cyan

if ($useNewPSResourceGet) {
    Write-Host "  - Find modules: Find-PSResource -Name <ModuleName> -Repository $Name" -ForegroundColor Gray
    Write-Host "  - Install modules: Install-PSResource -Name <ModuleName> -Repository $Name" -ForegroundColor Gray
    Write-Host "  - Publish modules: Publish-PSResource -Path <ModulePath> -Repository $Name -ApiKey <ApiKey>" -ForegroundColor Gray
} else {
    Write-Host "  - Find modules: Find-Module -Name <ModuleName> -Repository $Name" -ForegroundColor Gray
    Write-Host "  - Install modules: Install-Module -Name <ModuleName> -Repository $Name" -ForegroundColor Gray
    Write-Host "  - Publish modules: Publish-Module -Path <ModulePath> -Repository $Name -NuGetApiKey <ApiKey>" -ForegroundColor Gray
}