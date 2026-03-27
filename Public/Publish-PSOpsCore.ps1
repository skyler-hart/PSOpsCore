function Publish-PSOpsCore {
    <#
    .SYNOPSIS
        Publishes the PSOpsCore module to a private PowerShell repository.

    .DESCRIPTION
        Automatically locates the PSOpsCore module directory using Get-PSOpsDevFolder,
        then publishes it to the configured private PowerShell repository using 1Password secrets.

    .EXAMPLE
        Publish-PSOpsCore
        Publishes the module from the automatically detected development folder.
    #>
    [CmdletBinding()]
    param ()

    begin {
        $os = Get-PSOpsPlatform
        if ($os -match "Unknown|Unsupported") {
            Throw "Unsupported OS: $os"
        }
    }

    process {
        # Find the development folder and construct module path
        $devFolder = Get-PSOpsDevFolder
        if (-not $devFolder) {
            throw "Could not locate development folder. Please ensure your development folder exists or use Get-PSOpsDevFolder -CustomPaths to specify custom locations."
        }
        
        $ModulePath = Join-Path $devFolder 'PSOpsCore'
        
        if (-not (Test-Path $ModulePath)) {
            throw "PSOpsCore module not found at: $ModulePath"
        }
        
        Write-Verbose "Using module path: $ModulePath"

        $name = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/repoName'
        $key  = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/password'

        Publish-PSResource -Path $ModulePath -Repository $name -ApiKey $key
        Find-PSResource -Name PSOpsCore -Repository $name
        Install-PSResource -Name PSOpsCore -Repository $name -TrustRepository
    }
}
