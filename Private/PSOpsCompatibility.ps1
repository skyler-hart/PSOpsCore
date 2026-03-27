function New-PSOpsCompatibleList {
    <#
    .SYNOPSIS
        Creates a compatible list object for both PowerShell 5.1 and 7+.

    .DESCRIPTION
        Creates a list collection that works consistently across PowerShell versions.
        In PowerShell 5.1, some generic collections and ::new() syntax can be problematic,
        so this function provides a compatibility layer.

    .PARAMETER Type
        The type of objects the list will contain. Defaults to [string].

    .EXAMPLE
        $list = New-PSOpsCompatibleList
        $list.Add("item1")
        $list.Add("item2")

    .EXAMPLE
        $intList = New-PSOpsCompatibleList -Type ([int])
        $intList.Add(1)
        $intList.Add(2)
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [Type]$Type = [string]
    )

    $psInfo = Get-PSVersion
    
    if ($psInfo.IsCore) {
        # PowerShell Core/7+ - use modern syntax
        return [System.Collections.Generic.List[$Type]]::new()
    }
    else {
        # PowerShell 5.1 - use compatible syntax
        return New-Object "System.Collections.Generic.List[$($Type.Name)]"
    }
}

function Invoke-PSOpsRestMethod {
    <#
    .SYNOPSIS
        PowerShell version-compatible REST API wrapper.

    .DESCRIPTION
        Provides consistent REST API behavior across PowerShell 5.1 and 7+.
        Handles differences in error handling, response parsing, and parameter support.

    .PARAMETER Uri
        The URI to make the request to.

    .PARAMETER Method
        The HTTP method to use.

    .PARAMETER Headers
        Headers to include in the request.

    .PARAMETER Body
        Body content for the request.

    .PARAMETER ErrorAction
        Error action preference.

    .EXAMPLE
        $result = Invoke-PSOpsRestMethod -Uri $uri -Method GET -Headers $headers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [string]$Method = 'GET',

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [System.Management.Automation.ActionPreference]$ErrorAction = 'Continue'
    )

    $psInfo = Get-PSVersion
    
    # Build parameters that are common to both versions
    $restParams = @{
        Uri = $Uri
        Method = $Method
        ErrorAction = $ErrorAction
    }

    if ($Headers) {
        $restParams.Headers = $Headers
    }

    if ($Body) {
        $restParams.Body = $Body
    }

    # PowerShell 5.1 vs 7+ specific parameters and behavior
    if ($psInfo.IsDesktop) {
        # PowerShell 5.1 - may need UseBasicParsing for web requests
        if ($Method -eq 'GET' -or $Method -eq 'POST' -or $Method -eq 'PUT' -or $Method -eq 'DELETE') {
            $restParams.UseBasicParsing = $true
        }
    }

    try {
        return Invoke-RestMethod @restParams
    }
    catch {
        # Standardize error handling between versions
        throw "REST API call failed: $($_.Exception.Message)"
    }
}