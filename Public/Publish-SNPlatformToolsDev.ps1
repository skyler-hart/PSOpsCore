function Publish-SNPlatformToolsDev {
    <#
    .SYNOPSIS
        Publishes the SNPlatformTools-Dev module to a private PowerShell repository.

    .DESCRIPTION
        Automatically locates the SNPlatformTools-Dev module directory using Get-PSOpsDevFolder,
        then publishes it to the configured private PowerShell repository using 1Password secrets.

    .PARAMETER ModuleName
        The name of the module to publish. Default is 'SNPlatformToolsDev'.

    .PARAMETER ModulePath
        Optional custom path to the module directory. If not specified, uses Get-PSOpsDevFolder 
        to find the development folder and constructs the path automatically.

    .PARAMETER Repository
        The name of the PowerShell repository to publish to. If not specified, uses 1Password stored value.

    .PARAMETER ApiKey
        The API key for publishing. If not specified, uses 1Password stored value.

    .EXAMPLE
        Publish-SNPlatformToolsDev
        Publishes the module using automatically detected paths and 1Password secrets.

    .EXAMPLE
        Publish-SNPlatformToolsDev -ModulePath '/custom/path/to/SNPlatformTools-Dev'
        Publishes the module from a custom path.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ModuleName = 'SNPlatformToolsDev',

        [Parameter()]
        [string]$ModulePath,

        [Parameter()]
        [string]$Repository,

        [Parameter()]
        [string]$ApiKey
    )

    begin {
        $os = Get-PSOpsPlatform
        if ($os -match "Unknown|Unsupported") {
            throw "Unsupported OS: $os"
        }
    }

    process {
        # If ModulePath not provided, construct it using development folder detection
        if (-not $ModulePath) {
            $devFolder = Get-PSOpsDevFolder
            if (-not $devFolder) {
                throw "Could not locate development folder. Please specify -ModulePath parameter or ensure your development folder exists."
            }
            
            $ModulePath = Join-Path $devFolder 'PreviousWork/Intact/SNPlatformTools-Dev'
        }
        
        if (-not (Test-Path $ModulePath)) {
            throw "SNPlatformTools-Dev module not found at: $ModulePath"
        }
        
        Write-Verbose "Using module path: $ModulePath"

        # Get repository name from 1Password if not provided
        if (-not $Repository) {
            $script:RepoNameRef = 'op://DevOps/PSResource Repository - PKGS-H/repoName'
            $Repository = op read $script:RepoNameRef
        }

        # Get API key from 1Password if not provided
        if (-not $ApiKey) {
            $script:ApiKeyRef = 'op://DevOps/PSResource Repository - PKGS-H/password'
            $ApiKey = op read $script:ApiKeyRef
        }

        Write-Host "Publishing $ModuleName to repository $Repository..." -ForegroundColor Cyan
        Publish-PSResource -Path $ModulePath -Repository $Repository -ApiKey $ApiKey
        
        Write-Host "Verifying module availability..." -ForegroundColor Cyan
        Find-PSResource -Name $ModuleName -Repository $Repository
        
        Write-Host "Installing module for verification..." -ForegroundColor Cyan
        Install-PSResource -Name $ModuleName -Repository $Repository -TrustRepository
        
        Write-Host "Successfully published and verified $ModuleName" -ForegroundColor Green
    }
}
