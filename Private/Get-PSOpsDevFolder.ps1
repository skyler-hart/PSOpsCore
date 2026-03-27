function Get-PSOpsDevFolder {
    <#
    .SYNOPSIS
        Finds the main development folder across different machines and platforms.

    .DESCRIPTION
        This function searches for common development folder locations across Windows, macOS, and Linux.
        It checks for typical patterns like 'dev', 'development', 'projects', 'code', 'source', etc.
        and returns the first existing folder found, or allows you to specify custom search paths.

    .PARAMETER CustomPaths
        An array of custom paths to search for development folders.

    .PARAMETER IncludeSubdirectories
        Include subdirectories in the search (like ~/Documents/GitHub, ~/Documents/Projects).

    .EXAMPLE
        Get-PSOpsDevFolder
        Returns the first development folder found using default search patterns.

    .EXAMPLE
        Get-PSOpsDevFolder -CustomPaths @('C:\MyProjects', '/home/user/workspace')
        Searches custom paths in addition to default locations.

    .EXAMPLE
        Get-PSOpsDevFolder -IncludeSubdirectories
        Includes subdirectories like ~/Documents/GitHub in the search.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string[]]$CustomPaths = @(),

        [Parameter()]
        [switch]$IncludeSubdirectories
    )

    # Get platform information
    $platform = Get-PSOpsPlatform

    # Define common development folder names
    $commonNames = @('VSCode', 'VS_Code', '.GitHub','source', 'repos', 'dev', 'development', 'projects', 'code', 'git', 'workspace')
    
    # Define platform-specific base paths
    $basePaths = @()
    
    switch ($platform) {
        'Windows' {
            $basePaths += @(
                $env:USERPROFILE,
                "$env:USERPROFILE\Documents",
                'C:\dev',
                'C:\projects',
                'D:\dev',
                'D:\projects'
            )
        }
        'macOS' {
            $basePaths += @(
                $env:HOME,
                "$env:HOME/Documents",
                "$env:HOME/Desktop",
                '/usr/local/dev',
                '/opt/dev'
            )
        }
        'Linux' {
            $basePaths += @(
                $env:HOME,
                "$env:HOME/Documents",
                '/home/dev',
                '/opt/dev',
                '/usr/local/dev'
            )
        }
    }

    # Add subdirectories if requested
    if ($IncludeSubdirectories) {
        $subdirs = @('GitHub', 'GitLab', 'Bitbucket', 'Azure', 'VS_Code', 'VSCode')
        switch ($platform) {
            'Windows' {
                $subdirs | ForEach-Object {
                    $basePaths += "$env:USERPROFILE\Documents\$_"
                }
            }
            default {
                $subdirs | ForEach-Object {
                    $basePaths += "$env:HOME/Documents/$_"
                    $basePaths += "$env:HOME/$_"
                }
            }
        }
    }

    # Create search paths by combining base paths with common names
    $searchPaths = @()
    
    # Add base paths as-is (in case they are already development folders)
    $searchPaths += $basePaths
    
    # Add combinations of base paths and common names
    foreach ($basePath in $basePaths) {
        foreach ($name in $commonNames) {
            $searchPaths += Join-Path $basePath $name
        }
    }

    # Add custom paths
    $searchPaths += $CustomPaths

    # Find the first existing directory
    foreach ($path in $searchPaths) {
        if (Test-Path -Path $path -PathType Container) {
            Write-Verbose "Found development folder: $path"
            return $path
        }
    }

    Write-Warning "No development folder found. Searched paths: $($searchPaths -join ', ')"
    return $null
}