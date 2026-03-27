function Test-PSOpsPrerequisites {
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
