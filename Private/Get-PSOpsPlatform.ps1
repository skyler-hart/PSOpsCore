function Get-PSOpsPlatform {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # PowerShell 6.0+ has automatic platform variables
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($IsWindows) { return 'Windows' }
        if ($IsMacOS)   { return 'macOS' }
        if ($IsLinux)   { return 'Linux' }
    }
    else {
        # PowerShell 5.1 and earlier (Windows PowerShell) - Windows only
        if ($PSVersionTable.PSEdition -eq 'Desktop' -or $env:OS -eq 'Windows_NT') {
            return 'Windows'
        }
    }

    # Fallback detection method
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return 'Windows'
    }
    elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        return 'macOS'
    }
    elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
        return 'Linux'
    }

    return 'Unknown'
}
