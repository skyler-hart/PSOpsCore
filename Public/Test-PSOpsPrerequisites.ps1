function Test-PSOpsPrerequisites {
    <#
    .SYNOPSIS
        Tests whether required prerequisites for PSOpsCore are installed.

    .DESCRIPTION
        Validates that all required dependencies and tools for PSOpsCore module operation
        are properly installed and accessible. This includes PowerShell version, 1Password CLI,
        and .NET CLI components.

    .EXAMPLE
        Test-PSOpsPrerequisites
        Checks all prerequisites and returns a detailed status report.

    .EXAMPLE
        Test-PSOpsPrerequisites | Where-Object { -not $_.Installed }
        Shows only the prerequisites that are missing or not properly installed.

    .EXAMPLE
        $results = Test-PSOpsPrerequisites
        $results | Format-Table -AutoSize
        Stores results and displays them in a formatted table.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        PSCustomObject[]. Returns an array of objects with Name, Installed, and Detail properties
        for each prerequisite checked.

    .NOTES
        Prerequisites checked:
        - PowerShell 7 or higher
        - 1Password CLI (op command)
        - .NET CLI (dotnet command)

        The function uses Test-PSOpsCommand to verify command availability.

    .LINK
        Test-PSOpsCommand
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $results = [System.Collections.Generic.List[object]]::new()

    $results.Add([pscustomobject]@{
        Name      = 'PowerShell 7+'
        Installed = $PSVersionTable.PSVersion.Major -ge 7
        Detail    = $PSVersionTable.PSVersion.ToString()
    })

    $results.Add([pscustomobject]@{
        Name      = '1Password CLI (op)'
        Installed = [bool](Test-PSOpsCommand -Name 'op')
        Detail    = if (Test-PSOpsCommand -Name 'op') { (& op --version 2>$null) } else { 'Not found' }
    })

    $results.Add([pscustomobject]@{
        Name      = 'dotnet CLI'
        Installed = [bool](Test-PSOpsCommand -Name 'dotnet')
        Detail    = if (Test-PSOpsCommand -Name 'dotnet') { (& dotnet --version 2>$null) } else { 'Not found' }
    })

    return $results
}
