function Register-PSOpsCoreRepo {
    <#
    .SYNOPSIS
        Registers the PSOpsCore PowerShell resource repository.

    .DESCRIPTION
        Installs Microsoft.PowerShell.PSResourceGet if needed and registers the PKGS-H repository
        for accessing PSOpsCore modules and other internal PowerShell resources.
        Uses 1Password secrets for repository configuration.

    .PARAMETER Name
        The name of the repository to register. If not specified, uses 1Password stored value.

    .PARAMETER Uri
        The URI of the PowerShell resource repository. If not specified, uses 1Password stored value.

    .PARAMETER Priority
        The priority of the repository (lower numbers = higher priority). Default is 5.

    .PARAMETER Standalone
        Run in standalone mode without requiring the full PSOpsCore module to be loaded.

    .EXAMPLE
        Register-PSOpsCoreRepo
        Registers the repository using 1Password stored values.

    .EXAMPLE
        Register-PSOpsCoreRepo -Name 'MyRepo' -Uri 'https://my-nuget-server.com/v3/index.json'
        Registers a custom PowerShell resource repository.

    .EXAMPLE
        Register-PSOpsCoreRepo -Standalone
        Runs in standalone mode for environments where the module isn't fully loaded.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string]$Uri,

        [Parameter()]
        [int]$Priority = 5,

        [Parameter()]
        [switch]$Standalone
    )

    begin {
        # Standalone mode: Define functions if not available
        if ($Standalone -or -not (Get-Command Get-PSOpsPlatform -ErrorAction SilentlyContinue)) {
            function Get-PSOpsPlatform {
                if ($IsWindows) { return 'Windows' }
                if ($IsMacOS)   { return 'macOS' }
                if ($IsLinux)   { return 'Linux' }
                return 'Unknown'
            }
        }
        
        if ($Standalone -or -not (Get-Command Get-PSOpsCoreSecret -ErrorAction SilentlyContinue)) {
            function Get-PSOpsCoreSecret {
                param([string]$Path)
                if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
                    throw "1Password CLI 'op' not found. Install 1Password CLI and ensure you're signed in."
                }
                return & op read $Path
            }
        }
        
        $os = Get-PSOpsPlatform
        if ($os -match "Unknown|Unsupported") {
            throw "Unsupported OS: $os"
        }
        
        # Get values from 1Password if not provided as parameters
        if (-not $Name) {
            $Name = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/repoName'
        }
        
        if (-not $Uri) {
            $Uri = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/repoUri'
        }
        
        $psresourceget = Get-Module -ListAvailable Microsoft.PowerShell.PSResourceGet
    }

    process {
        if ([string]::IsNullOrWhiteSpace($psresourceget)) {
            Write-Verbose "Installing Microsoft.PowerShell.PSResourceGet module..."
            Install-Module Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force
        }

        Write-Verbose "Registering PowerShell resource repository '$Name' at $Uri"
        Register-PSResourceRepository -Name $Name -Uri $Uri -Trusted -Priority $Priority
        
        Write-Host "Successfully registered PowerShell resource repository '$Name'" -ForegroundColor Green
    }
}
