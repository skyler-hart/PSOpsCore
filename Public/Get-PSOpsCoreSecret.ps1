function Get-PSOpsCoreSecret {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-PSOpsCommand -Name 'op')) {
        throw 'The 1Password CLI (op) was not found in PATH. Install it and try again.'
    }

    $value = & op read $Path 2>$null

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        throw "Failed to retrieve secret from 1Password path [$Path]. Ensure you are signed in and the path exists."
    }

    return $value.Trim()
}
