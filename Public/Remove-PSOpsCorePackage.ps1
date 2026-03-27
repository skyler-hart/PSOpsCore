function Remove-PSOpsCorePackage {
    <#
    .SYNOPSIS
        Removes (de-lists) a package from the BaGet PowerShell repository.

    .DESCRIPTION
        Removes or de-lists a specified package from the BaGet PowerShell repository using the BaGet REST API.
        The function uses 1Password secrets for repository configuration and authentication, and supports
        removing specific versions or all versions of a package.

    .PARAMETER PackageName
        The name of the package to remove from the repository.

    .PARAMETER Version
        Optional specific version of the package to remove. If not specified, removes all versions.

    .PARAMETER Repository
        The name of the PowerShell repository. If not specified, uses 1Password stored value.

    .PARAMETER ApiKey
        The API key for repository authentication. If not specified, uses 1Password stored value.

    .PARAMETER ServerUri
        The BaGet server URI. If not specified, uses 1Password stored value.

    .PARAMETER Force
        Bypass confirmation prompts and force the removal.

    .PARAMETER WhatIf
        Shows what would happen without actually removing the package.

    .EXAMPLE
        Remove-PSOpsCorePackage -PackageName 'SkyPSTest'
        Removes all versions of the SkyPSTest package from the repository with confirmation prompt.

    .EXAMPLE
        Remove-PSOpsCorePackage -PackageName 'PSOpsCore' -Version '1.0.0' -Force
        Removes version 1.0.0 of PSOpsCore without confirmation prompts.

    .EXAMPLE
        Remove-PSOpsCorePackage -PackageName 'SNPlatformToolsDev' -WhatIf
        Shows what would be removed without actually performing the action.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        PSCustomObject. Returns removal status information.

    .NOTES
        Prerequisites:
        - BaGet server must be accessible and running
        - 1Password CLI must be installed and signed in
        - API key must have package deletion permissions
        - Package deletion must be enabled in BaGet configuration
        - PowerShell 7+ for cross-platform REST API support

        The function uses the BaGet REST API endpoints for package management.
        If you get HTTP 401 errors, check that your API key has delete permissions
        and that BaGet is configured to allow package deletion.
        Use -WhatIf to preview actions before executing.

    .LINK
        Get-PSOpsCoreSecret
    .LINK
        Publish-PSOpsCore
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageName,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [string]$Repository,

        [Parameter()]
        [string]$ApiKey,

        [Parameter()]
        [string]$ServerUri,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $os = Get-PSOpsPlatform
        if ($os -match "Unknown|Unsupported") {
            throw "Unsupported OS: $os"
        }
    }

    process {
        try {
            # Get repository configuration from 1Password if not provided
            if (-not $Repository) {
                $Repository = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/repoName'
            }

            if (-not $ApiKey) {
                $ApiKey = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/password'
            }

            if (-not $ServerUri) {
                $ServerUri = Get-PSOpsCoreSecret -Path 'op://DevOps/PSResource Repository - PKGS-H/repoUri'
            }

            # Convert repository URI to BaGet API base URL
            $baseUri = $ServerUri -replace '/v3/index\.json$', ''
            
            Write-Verbose "Using BaGet server: $baseUri"
            Write-Verbose "Repository: $Repository"
            Write-Verbose "Package: $PackageName"
            if ($Version) { Write-Verbose "Version: $Version" }

            # Prepare headers for API authentication (DELETE requests don't need Content-Type)
            $headers = @{
                'X-API-Key' = $ApiKey
            }

            # First, check if package exists using the correct BaGet registration API
            $packageInfoUri = "$baseUri/v3/registration/$($PackageName.ToLower())/index.json"
            
            Write-Host "Checking package existence at: $packageInfoUri" -ForegroundColor Yellow
            
            try {
                $packageInfo = Invoke-RestMethod -Uri $packageInfoUri -Method Get -ErrorAction Stop
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 'NotFound') {
                    throw "Package '$PackageName' not found in repository '$Repository'"
                }
                throw "Failed to retrieve package information: $($_.Exception.Message)"
            }

            # Determine versions to remove from BaGet registration response
            $versionsToRemove = if ($Version) {
                @($Version)
            } else {
                # Extract versions from BaGet registration API response
                $allVersions = [System.Collections.Generic.List[string]]::new()
                
                if ($packageInfo.items) {
                    foreach ($item in $packageInfo.items) {
                        if ($item.items) {
                            foreach ($subItem in $item.items) {
                                if ($subItem.catalogEntry -and $subItem.catalogEntry.version) {
                                    $allVersions.Add($subItem.catalogEntry.version)
                                }
                            }
                        }
                    }
                } elseif ($packageInfo.catalogEntry -and $packageInfo.catalogEntry.version) {
                    $allVersions.Add($packageInfo.catalogEntry.version)
                }
                
                $allVersions.ToArray() | Sort-Object -Unique
            }

            if (-not $versionsToRemove -or $versionsToRemove.Length -eq 0) {
                throw "No versions found for package '$PackageName'"
            }

            # Confirmation logic
            $actionDescription = if ($Version) {
                "Remove version $Version of package '$PackageName'"
            } else {
                "Remove ALL $($versionsToRemove.Length) versions of package '$PackageName'"
            }

            if (-not $Force -and -not $PSCmdlet.ShouldProcess($PackageName, $actionDescription)) {
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                return [PSCustomObject]@{
                    PackageName = $PackageName
                    Repository = $Repository
                    Status = 'Cancelled'
                    Timestamp = Get-Date
                }
            }

            Write-Host $actionDescription -ForegroundColor Cyan

            # Remove each version using BaGet's delete API
            $results = @()
            foreach ($versionToRemove in $versionsToRemove) {
                # BaGet uses /api/v2/package/{id}/{version} for deletions (DELETE method)
                # Note: BaGet defaults to "unlisting" packages rather than hard deletion
                $deleteUri = "$baseUri/api/v2/package/$($PackageName.ToLower())/$versionToRemove"
                
                if ($PSCmdlet.ShouldProcess("$PackageName v$versionToRemove", "DELETE $deleteUri")) {
                    try {
                        Write-Host "Removing $PackageName v$versionToRemove..." -ForegroundColor Yellow
                        Write-Verbose "DELETE endpoint: $deleteUri"
                        Write-Verbose "Request headers: X-API-Key = [REDACTED]"
                        
                        # BaGet delete endpoint - returns 204 (NoContent) on success, 404 if not found
                        $response = Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers -ErrorAction Stop
                        
                        $results += [PSCustomObject]@{
                            PackageName = $PackageName
                            Version = $versionToRemove
                            Status = 'Success'
                            Message = "Package unlisted/removed successfully"
                        }
                        
                        Write-Host "✓ Successfully removed $PackageName v$versionToRemove" -ForegroundColor Green
                    }
                    catch {
                        $errorMessage = $_.Exception.Message
                        $statusCode = $null
                        
                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                            $errorMessage = "HTTP $statusCode - $errorMessage"
                            
                            # Provide helpful guidance for common errors
                            if ($statusCode -eq 401) {
                                $errorMessage += "`nThis usually means the API key lacks delete permissions or package deletion is disabled in BaGet."
                            }
                            elseif ($statusCode -eq 404) {
                                $errorMessage += "`nThe package version may not exist or may already have been removed."
                            }
                        }
                        
                        $results += [PSCustomObject]@{
                            PackageName = $PackageName
                            Version = $versionToRemove
                            Status = 'Failed'
                            Message = $errorMessage
                        }
                        
                        Write-Error "✗ Failed to remove $PackageName v$versionToRemove`: $errorMessage"
                    }
                }
            }

            # Summary
            $successCount = @($results | Where-Object Status -eq 'Success').Count
            $failureCount = @($results | Where-Object Status -eq 'Failed').Count
            
            Write-Host "`nRemoval Summary:" -ForegroundColor Cyan
            Write-Host "  Package: $PackageName" -ForegroundColor White
            Write-Host "  Repository: $Repository" -ForegroundColor White
            Write-Host "  Successful: $successCount" -ForegroundColor Green
            Write-Host "  Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { 'Red' } else { 'Green' })

            # Return comprehensive results
            return [PSCustomObject]@{
                PackageName = $PackageName
                Repository = $Repository
                ServerUri = $baseUri
                TotalVersions = $versionsToRemove.Length
                SuccessCount = $successCount
                FailureCount = $failureCount
                Results = $results
                Status = if ($failureCount -eq 0) { 'Success' } else { 'Partial' }
                Timestamp = Get-Date
            }
        }
        catch {
            Write-Error "Package removal failed: $($_.Exception.Message)"
            
            return [PSCustomObject]@{
                PackageName = $PackageName
                Repository = $Repository
                Status = 'Failed'
                Error = $_.Exception.Message
                Timestamp = Get-Date
            }
        }
    }
}