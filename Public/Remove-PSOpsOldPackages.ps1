function Remove-PSOpsOldPackages {
    <#
    .SYNOPSIS
        Removes old versions of packages from the local computer across different operating systems.

    .DESCRIPTION
        Removes outdated versions of installed packages while keeping the latest version.
        Supports PowerShell modules and system packages across Windows, macOS, and Linux.
        The function can target specific packages or clean up all packages with multiple versions.

    .PARAMETER PackageName
        Specific package name to clean up. If not specified, processes all packages with multiple versions.

    .PARAMETER PackageType
        Type of packages to process. Valid values: 'PowerShellModules', 'SystemPackages', 'All'.
        Default is 'PowerShellModules'.

    .PARAMETER KeepVersions
        Number of recent versions to keep for each package. Default is 1 (keep only the latest).

    .PARAMETER ComputerName
        Target computer name. Default is localhost. Requires PowerShell Remoting for remote computers.

    .PARAMETER Credential
        Credentials for remote computer access.

    .PARAMETER Force
        Skip confirmation prompts and force removal of old versions.

    .PARAMETER WhatIf
        Shows what would be removed without actually performing the removal.

    .EXAMPLE
        Remove-PSOpsOldPackages
        Removes old versions of all PowerShell modules, keeping only the latest version of each.

    .EXAMPLE
        Remove-PSOpsOldPackages -PackageName 'PSOpsCore' -Force
        Removes old versions of the PSOpsCore module without confirmation prompts.

    .EXAMPLE
        Remove-PSOpsOldPackages -PackageType 'All' -KeepVersions 2
        Cleans up both PowerShell modules and system packages, keeping the 2 most recent versions.

    .EXAMPLE
        Remove-PSOpsOldPackages -ComputerName 'server01' -Credential (Get-Credential)
        Cleans up packages on a remote computer using specified credentials.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        PSCustomObject[]. Returns cleanup status information for each package processed.

    .NOTES
        Prerequisites:
        - PowerShell 7+ for cross-platform support
        - Administrator/sudo privileges may be required for system package removal
        - PowerShell Remoting enabled for remote computer operations
        - Appropriate package managers installed (chocolatey, brew, apt, etc.)

        Supported package managers:
        - Windows: PowerShell modules, Chocolatey, Windows Package Manager
        - macOS: PowerShell modules, Homebrew
        - Linux: PowerShell modules, APT, YUM, DNF

    .LINK
        Get-PSOpsPlatform
    .LINK
        Remove-PSOpsCorePackage
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [ValidateSet('PowerShellModules', 'SystemPackages', 'All')]
        [string]$PackageType = 'PowerShellModules',

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$KeepVersions = 1,

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $os = Get-PSOpsPlatform
        if ($os -match "Unknown|Unsupported") {
            throw "Unsupported OS: $os"
        }

        # Define script block for cleanup operations
        $cleanupScript = {
            param($PackageName, $PackageType, $KeepVersions, $Force, $OS)
            
            $results = @()

            # Function to clean PowerShell modules
            function Remove-OldPowerShellModules {
                param($SpecificModule, $Keep, $ForceRemoval)
                
                $moduleResults = @()
                
                # Get all installed modules
                $allModules = if ($SpecificModule) {
                    Get-Module -ListAvailable -Name $SpecificModule -ErrorAction SilentlyContinue
                } else {
                    Get-Module -ListAvailable
                }
                
                # Group by module name and find modules with multiple versions
                $moduleGroups = $allModules | Group-Object Name | Where-Object Count -gt 1
                
                foreach ($group in $moduleGroups) {
                    try {
                        # Sort versions and determine which ones to remove
                        $sortedVersions = $group.Group | Sort-Object Version -Descending
                        $versionsToKeep = $sortedVersions | Select-Object -First $Keep
                        $versionsToRemove = $sortedVersions | Select-Object -Skip $Keep
                        
                        if ($versionsToRemove.Count -gt 0) {
                            $moduleResult = [PSCustomObject]@{
                                PackageName = $group.Name
                                PackageType = 'PowerShellModule'
                                TotalVersions = $sortedVersions.Count
                                VersionsToRemove = $versionsToRemove.Count
                                VersionsKept = $versionsToKeep.Count
                                RemovedVersions = @()
                                Status = 'Processing'
                                Errors = @()
                            }
                            
                            foreach ($moduleToRemove in $versionsToRemove) {
                                try {
                                    if ($ForceRemoval) {
                                        Uninstall-Module -Name $moduleToRemove.Name -RequiredVersion $moduleToRemove.Version -Force -ErrorAction Stop
                                    } else {
                                        Uninstall-Module -Name $moduleToRemove.Name -RequiredVersion $moduleToRemove.Version -ErrorAction Stop
                                    }
                                    
                                    $moduleResult.RemovedVersions += $moduleToRemove.Version.ToString()
                                    Write-Host "✓ Removed $($moduleToRemove.Name) v$($moduleToRemove.Version)" -ForegroundColor Green
                                }
                                catch {
                                    $moduleResult.Errors += "Failed to remove v$($moduleToRemove.Version): $($_.Exception.Message)"
                                    Write-Warning "✗ Failed to remove $($moduleToRemove.Name) v$($moduleToRemove.Version): $($_.Exception.Message)"
                                }
                            }
                            
                            $moduleResult.Status = if ($moduleResult.Errors.Count -eq 0) { 'Success' } else { 'Partial' }
                            $moduleResults += $moduleResult
                        }
                    }
                    catch {
                        $moduleResults += [PSCustomObject]@{
                            PackageName = $group.Name
                            PackageType = 'PowerShellModule'
                            Status = 'Failed'
                            Errors = @($_.Exception.Message)
                        }
                    }
                }
                
                return $moduleResults
            }

            # Function to clean system packages (basic implementation)
            function Remove-OldSystemPackages {
                param($SpecificPackage, $Keep, $ForceRemoval, $OperatingSystem)
                
                $systemResults = @()
                
                try {
                    switch ($OperatingSystem) {
                        'Windows' {
                            # Check for Chocolatey
                            if (Get-Command choco -ErrorAction SilentlyContinue) {
                                # Note: Chocolatey doesn't typically keep multiple versions
                                Write-Host "Chocolatey detected - most packages don't retain old versions" -ForegroundColor Yellow
                            }
                            
                            # Check for winget
                            if (Get-Command winget -ErrorAction SilentlyContinue) {
                                Write-Host "Windows Package Manager (winget) detected - cleanup not implemented yet" -ForegroundColor Yellow
                            }
                        }
                        'macOS' {
                            # Check for Homebrew
                            if (Get-Command brew -ErrorAction SilentlyContinue) {
                                if ($SpecificPackage) {
                                    & brew cleanup $SpecificPackage 2>&1 | Out-String
                                } else {
                                    & brew cleanup 2>&1 | Out-String
                                }
                                
                                $systemResults += [PSCustomObject]@{
                                    PackageName = if ($SpecificPackage) { $SpecificPackage } else { 'All' }
                                    PackageType = 'Homebrew'
                                    Status = if ($LASTEXITCODE -eq 0) { 'Success' } else { 'Failed' }
                                    Message = 'Homebrew cleanup completed'
                                }
                            }
                        }
                        'Linux' {
                            # Basic APT cleanup
                            if (Get-Command apt -ErrorAction SilentlyContinue) {
                                Write-Host "APT cleanup would require sudo privileges" -ForegroundColor Yellow
                                $systemResults += [PSCustomObject]@{
                                    PackageName = 'System'
                                    PackageType = 'APT'
                                    Status = 'Skipped'
                                    Message = 'Manual cleanup required: sudo apt autoremove && sudo apt autoclean'
                                }
                            }
                        }
                    }
                }
                catch {
                    $systemResults += [PSCustomObject]@{
                        PackageName = 'System'
                        PackageType = 'SystemPackage'
                        Status = 'Failed'
                        Errors = @($_.Exception.Message)
                    }
                }
                
                return $systemResults
            }

            # Execute cleanup based on package type
            if ($PackageType -eq 'PowerShellModules' -or $PackageType -eq 'All') {
                $results += Remove-OldPowerShellModules -SpecificModule $PackageName -Keep $KeepVersions -ForceRemoval $Force
            }
            
            if ($PackageType -eq 'SystemPackages' -or $PackageType -eq 'All') {
                $results += Remove-OldSystemPackages -SpecificPackage $PackageName -Keep $KeepVersions -ForceRemoval $Force -OperatingSystem $OS
            }
            
            return $results
        }
    }

    process {
        try {
            Write-Host "Starting package cleanup on $ComputerName..." -ForegroundColor Cyan
            Write-Host "Package Type: $PackageType" -ForegroundColor Gray
            Write-Host "Keep Versions: $KeepVersions" -ForegroundColor Gray
            if ($PackageName) { Write-Host "Target Package: $PackageName" -ForegroundColor Gray }

            $results = if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost') {
                # Local execution
                if ($PSCmdlet.ShouldProcess($ComputerName, "Remove old packages")) {
                    & $cleanupScript -PackageName $PackageName -PackageType $PackageType -KeepVersions $KeepVersions -Force $Force -OS $os
                }
            } else {
                # Remote execution
                $sessionParams = @{
                    ComputerName = $ComputerName
                }
                
                if ($Credential) {
                    $sessionParams.Credential = $Credential
                }
                
                Write-Host "Establishing PowerShell session to $ComputerName..." -ForegroundColor Yellow
                $session = New-PSSession @sessionParams -ErrorAction Stop
                
                try {
                    if ($PSCmdlet.ShouldProcess($ComputerName, "Remove old packages remotely")) {
                        Invoke-Command -Session $session -ScriptBlock $cleanupScript -ArgumentList $PackageName, $PackageType, $KeepVersions, $Force, $os
                    }
                }
                finally {
                    Remove-PSSession -Session $session -ErrorAction SilentlyContinue
                }
            }

            # Display summary
            if ($results) {
                $totalProcessed = $results.Count
                $successful = ($results | Where-Object Status -eq 'Success').Count
                $partial = ($results | Where-Object Status -eq 'Partial').Count
                $failed = ($results | Where-Object Status -eq 'Failed').Count
                $skipped = ($results | Where-Object Status -eq 'Skipped').Count
                
                Write-Host "`nCleanup Summary for $ComputerName`:" -ForegroundColor Cyan
                Write-Host "  Total Packages Processed: $totalProcessed" -ForegroundColor White
                Write-Host "  Successful: $successful" -ForegroundColor Green
                Write-Host "  Partial: $partial" -ForegroundColor Yellow
                Write-Host "  Failed: $failed" -ForegroundColor Red
                Write-Host "  Skipped: $skipped" -ForegroundColor Gray
                
                # Show details for packages that had issues
                $problemPackages = $results | Where-Object { $_.Status -in @('Failed', 'Partial') -and $_.Errors }
                if ($problemPackages) {
                    Write-Host "`nPackages with Issues:" -ForegroundColor Yellow
                    foreach ($pkg in $problemPackages) {
                        Write-Host "  $($pkg.PackageName): $($pkg.Errors -join '; ')" -ForegroundColor Red
                    }
                }
            }

            return $results
        }
        catch {
            Write-Error "Package cleanup failed: $($_.Exception.Message)"
            
            return [PSCustomObject]@{
                ComputerName = $ComputerName
                Status = 'Failed'
                Error = $_.Exception.Message
                Timestamp = Get-Date
            }
        }
    }
}