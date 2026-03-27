function Get-PSVersion {
    <#
    .SYNOPSIS
        Gets PowerShell version information for compatibility checks.

    .DESCRIPTION
        Returns detailed PowerShell version information including major version,
        edition (Desktop/Core), and platform compatibility. Used throughout the
        module for version-specific feature detection and compatibility handling.

    .EXAMPLE
        Get-PSVersion
        Returns version information for the current PowerShell session.

    .EXAMPLE
        $psInfo = Get-PSVersion
        if ($psInfo.IsCore) { 
            # Use PowerShell Core features
        }

    .OUTPUTS
        PSCustomObject with version details including:
        - Version: Full version object
        - MajorVersion: Major version number
        - IsCore: True if PowerShell Core/7+
        - IsDesktop: True if Windows PowerShell 5.1 or earlier
        - IsWindows51: True if specifically Windows PowerShell 5.1
        - SupportsCrossPlatform: True if cross-platform features available
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $version = $PSVersionTable.PSVersion
    $edition = $PSVersionTable.PSEdition
    $majorVersion = $version.Major

    [PSCustomObject]@{
        Version = $version
        MajorVersion = $majorVersion
        Edition = $edition
        IsCore = ($edition -eq 'Core' -or $majorVersion -ge 6)
        IsDesktop = ($edition -eq 'Desktop' -or $majorVersion -le 5)
        IsWindows51 = ($edition -eq 'Desktop' -and $majorVersion -eq 5 -and $version.Minor -eq 1)
        SupportsCrossPlatform = ($majorVersion -ge 6)
        SupportsModernRest = ($majorVersion -ge 6)
        SupportsAdvancedArrays = ($majorVersion -ge 6)
    }
}