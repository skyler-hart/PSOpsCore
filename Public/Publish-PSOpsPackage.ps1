function Publish-PSOpsPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string]$NupkgPath,

        [Parameter()]
        [string]$SourceUrl,

        [Parameter()]
        [string]$ApiKey,

        [Parameter()]
        [string]$SourceSecretPath = 'op://Development/BaGet/sourceUrl',

        [Parameter()]
        [string]$ApiKeySecretPath = 'op://Development/BaGet/apiKey'
    )

    if (-not (Test-PSOpsCommand -Name 'dotnet')) {
        throw 'The dotnet CLI was not found in PATH. Install the .NET SDK/runtime with NuGet push support and try again.'
    }

    if (-not $SourceUrl) {
        $SourceUrl = Get-PSOpsCoreSecret -Path $SourceSecretPath
    }

    if (-not $ApiKey) {
        $ApiKey = Get-PSOpsCoreSecret -Path $ApiKeySecretPath
    }

    $resolvedPath = (Resolve-Path -LiteralPath $NupkgPath).Path
    $target       = "$resolvedPath -> $SourceUrl"

    if ($PSCmdlet.ShouldProcess($target, 'Publish package')) {
        $output = & dotnet nuget push $resolvedPath --source $SourceUrl --api-key $ApiKey 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Package publish failed.`n$output"
        }

        $output
    }
}
