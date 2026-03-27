function Get-PSOpsCoreSecret {
    <#
    .SYNOPSIS
        Retrieves a secret value from 1Password using the 1Password CLI.

    .DESCRIPTION
        This function uses the 1Password CLI (op) to securely retrieve secret values from 1Password vaults.
        The function validates that the 1Password CLI is available and that you are signed in before attempting
        to retrieve the secret. It returns the trimmed secret value or throws an error if the operation fails.

    .PARAMETER Path
        The 1Password secret reference path in the format 'op://vault/item/field'.
        Examples:
        - 'op://DevOps/API Key/password'
        - 'op://Infrastructure/Database/username'
        - 'op://Shared/Service Account/token'

    .EXAMPLE
        Get-PSOpsCoreSecret -Path 'op://DevOps/GitHub Token/password'
        Retrieves the GitHub token from the DevOps vault.

    .EXAMPLE
        $apiKey = Get-PSOpsCoreSecret -Path 'op://Infrastructure/BaGet - PKGS-H/password'
        Stores the API key from 1Password in a variable for later use.

    .EXAMPLE
        Get-PSOpsCoreSecret -Path 'op://Shared/Database Connection/connectionstring'
        Retrieves a database connection string from the Shared vault.

    .INPUTS
        String. The 1Password secret reference path.

    .OUTPUTS
        String. The secret value retrieved from 1Password, with leading/trailing whitespace removed.

    .NOTES
        Prerequisites:
        - 1Password CLI (op) must be installed and available in PATH
        - You must be signed in to 1Password CLI (op signin)
        - The specified vault and item must exist and be accessible
        - You must have appropriate permissions to access the secret

        The function will throw an error if:
        - 1Password CLI is not found
        - You are not signed in to 1Password
        - The specified path does not exist
        - You don't have permission to access the secret

    .LINK
        https://developer.1password.com/docs/cli/
    #>
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
