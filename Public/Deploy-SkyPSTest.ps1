function Deploy-SkyPSTest {
    <#
    .SYNOPSIS
        Deploys the SkyPSTest module to a specified remote computer.

    .DESCRIPTION
        Transfers the SkyPSTest module from the local development folder to a specified remote computer.
        The function automatically detects the local module path, determines the target OS, and uses
        appropriate methods for cross-platform deployment (PowerShell Remoting, SSH/SCP, or network shares).

    .PARAMETER ComputerName
        The name or IP address of the target computer to deploy the module to.

    .PARAMETER ModulePath
        Optional custom path to the local SkyPSTest module. If not specified, uses Get-PSOpsDevFolder
        to automatically detect the development folder.

    .PARAMETER Credential
        Credentials for authenticating to the remote computer. If not specified, uses current context.

    .PARAMETER UseSSH
        Force the use of SSH/SCP for deployment instead of PowerShell Remoting (useful for Linux/macOS targets).

    .PARAMETER DestinationPath
        Custom destination path on the remote computer. If not specified, uses platform-appropriate
        default PowerShell module locations.

    .EXAMPLE
        Deploy-SkyPSTest -ComputerName 'server01'
        Deploys SkyPSTest to server01 using default settings and current credentials.

    .EXAMPLE
        Deploy-SkyPSTest -ComputerName '192.168.1.100' -UseSSH -Credential (Get-Credential)
        Deploys SkyPSTest to a Linux/macOS system using SSH with specified credentials.

    .EXAMPLE
        Deploy-SkyPSTest -ComputerName 'workstation02' -DestinationPath 'C:\CustomModules\SkyPSTest'
        Deploys SkyPSTest to a custom destination path on the remote system.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        PSCustomObject. Returns deployment status information.

    .NOTES
        Prerequisites:
        - PowerShell Remoting enabled on target Windows systems (unless using -UseSSH)
        - SSH access configured for Linux/macOS targets
        - Appropriate network connectivity and permissions
        - SkyPSTest module must exist in the local development folder

    .LINK
        Get-PSOpsDevFolder
    .LINK
        Deploy-PSOpsCore
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter()]
        [string]$ModulePath,

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [switch]$UseSSH,

        [Parameter()]
        [string]$DestinationPath
    )

    begin {
        $os = Get-PSOpsPlatform
        if ($os -match "Unknown|Unsupported") {
            throw "Unsupported OS: $os"
        }
    }

    process {
        # Find the local module path if not specified
        if (-not $ModulePath) {
            $devFolder = Get-PSOpsDevFolder
            if (-not $devFolder) {
                throw "Could not locate development folder. Please specify -ModulePath parameter or ensure your development folder exists."
            }
            
            $ModulePath = Join-Path $devFolder 'SkyPSTest'
        }
        
        if (-not (Test-Path $ModulePath)) {
            throw "SkyPSTest module not found at: $ModulePath"
        }
        
        Write-Verbose "Using local module path: $ModulePath"
        Write-Host "Deploying SkyPSTest to $ComputerName..." -ForegroundColor Cyan

        # Determine deployment method based on parameters and target OS detection
        $deploymentMethod = if ($UseSSH) { 'SSH' } else { 'PSRemoting' }
        
        try {
            switch ($deploymentMethod) {
                'SSH' {
                    # Use SSH/SCP for deployment
                    if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
                        throw "SSH/SCP not available. Install OpenSSH client or use PowerShell Remoting."
                    }
                    
                    # Default SSH destination for PowerShell modules
                    if (-not $DestinationPath) {
                        $DestinationPath = '/usr/local/share/powershell/Modules/SkyPSTest'
                    }
                    
                    $scpTarget = if ($Credential) {
                        "$($Credential.UserName)@${ComputerName}:$DestinationPath"
                    } else {
                        "${ComputerName}:$DestinationPath"
                    }
                    
                    Write-Host "Using SSH/SCP deployment to: $scpTarget" -ForegroundColor Yellow
                    & scp -r $ModulePath $scpTarget
                    
                    if ($LASTEXITCODE -ne 0) {
                        throw "SCP deployment failed with exit code: $LASTEXITCODE"
                    }
                }
                
                'PSRemoting' {
                    # Use PowerShell Remoting for deployment
                    $sessionParams = @{
                        ComputerName = $ComputerName
                    }
                    
                    if ($Credential) {
                        $sessionParams.Credential = $Credential
                    }
                    
                    Write-Host "Establishing PowerShell session to $ComputerName..." -ForegroundColor Yellow
                    $session = New-PSSession @sessionParams -ErrorAction Stop
                    
                    try {
                        # Determine remote destination path if not specified
                        if (-not $DestinationPath) {
                            $remoteInfo = Invoke-Command -Session $session -ScriptBlock {
                                @{
                                    IsWindows = $IsWindows
                                    IsLinux = $IsLinux
                                    IsMacOS = $IsMacOS
                                    PSModulePath = ($env:PSModulePath -split [System.IO.Path]::PathSeparator)[0]
                                }
                            }
                            
                            if ($remoteInfo.IsWindows) {
                                $DestinationPath = Join-Path $remoteInfo.PSModulePath 'SkyPSTest'
                            } else {
                                $DestinationPath = '/usr/local/share/powershell/Modules/SkyPSTest'
                            }
                        }
                        
                        Write-Host "Copying module to remote path: $DestinationPath" -ForegroundColor Yellow
                        
                        # Create destination directory on remote system
                        Invoke-Command -Session $session -ScriptBlock {
                            param($destPath)
                            if (-not (Test-Path $destPath)) {
                                New-Item -Path $destPath -ItemType Directory -Force | Out-Null
                            }
                        } -ArgumentList $DestinationPath
                        
                        # Copy module files to remote system
                        Copy-Item -Path "$ModulePath\*" -Destination $DestinationPath -ToSession $session -Recurse -Force
                        
                        # Verify deployment
                        $verifyResult = Invoke-Command -Session $session -ScriptBlock {
                            param($destPath)
                            @{
                                ModuleExists = Test-Path $destPath
                                Files = if (Test-Path $destPath) { (Get-ChildItem $destPath).Count } else { 0 }
                            }
                        } -ArgumentList $DestinationPath
                        
                        if (-not $verifyResult.ModuleExists -or $verifyResult.Files -eq 0) {
                            throw "Module deployment verification failed"
                        }
                        
                        Write-Host "Successfully deployed $($verifyResult.Files) files to $DestinationPath" -ForegroundColor Green
                    }
                    finally {
                        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
                    }
                }
            }
            
            # Return deployment status
            return [PSCustomObject]@{
                ComputerName = $ComputerName
                ModuleName = 'SkyPSTest'
                SourcePath = $ModulePath
                DestinationPath = $DestinationPath
                DeploymentMethod = $deploymentMethod
                Status = 'Success'
                Timestamp = Get-Date
            }
        }
        catch {
            Write-Error "Deployment failed: $($_.Exception.Message)"
            
            return [PSCustomObject]@{
                ComputerName = $ComputerName
                ModuleName = 'SkyPSTest'
                SourcePath = $ModulePath
                DestinationPath = $DestinationPath
                DeploymentMethod = $deploymentMethod
                Status = 'Failed'
                Error = $_.Exception.Message
                Timestamp = Get-Date
            }
        }
    }
}