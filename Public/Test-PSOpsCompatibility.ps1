function Test-PSOpsCompatibility {
    <#
    .SYNOPSIS
        Tests PSOpsCore module compatibility across PowerShell versions.

    .DESCRIPTION
        Validates that PSOpsCore functions work correctly in both PowerShell 5.1 
        and PowerShell 7+. Tests platform detection, version detection, and basic
        functionality to ensure compatibility layer is working properly.

    .EXAMPLE
        Test-PSOpsCompatibility
        Runs compatibility tests for the current PowerShell version.

    .OUTPUTS
        PSCustomObject with test results and compatibility information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Host "Testing PSOpsCore Compatibility..." -ForegroundColor Cyan
    
    $results = New-PSOpsCompatibleList
    $psInfo = Get-PSVersion
    
    Write-Host "PowerShell Version: $($psInfo.Version) ($($psInfo.Edition))" -ForegroundColor Yellow
    Write-Host "Platform: $(Get-PSOpsPlatform)" -ForegroundColor Yellow
    
    # Test 1: Platform Detection
    try {
        $platform = Get-PSOpsPlatform
        $results.Add([PSCustomObject]@{
            Test = "Platform Detection"
            Status = "PASS"
            Result = $platform
            Message = "Successfully detected platform: $platform"
        })
    }
    catch {
        $results.Add([PSCustomObject]@{
            Test = "Platform Detection"
            Status = "FAIL"
            Result = $null
            Message = $_.Exception.Message
        })
    }

    # Test 2: Version Detection
    try {
        $versionInfo = Get-PSVersion
        $results.Add([PSCustomObject]@{
            Test = "Version Detection"
            Status = "PASS"
            Result = $versionInfo.Version.ToString()
            Message = "PowerShell $($versionInfo.Version) ($($versionInfo.Edition)) - Core: $($versionInfo.IsCore)"
        })
    }
    catch {
        $results.Add([PSCustomObject]@{
            Test = "Version Detection"
            Status = "FAIL"
            Result = $null
            Message = $_.Exception.Message
        })
    }

    # Test 3: Compatible List Creation
    try {
        $testList = New-PSOpsCompatibleList
        $testList.Add("test1")
        $testList.Add("test2")
        $count = $testList.Count
        
        $results.Add([PSCustomObject]@{
            Test = "Compatible Collections"
            Status = "PASS"
            Result = "$count items"
            Message = "Successfully created and populated list with $count items"
        })
    }
    catch {
        $results.Add([PSCustomObject]@{
            Test = "Compatible Collections"
            Status = "FAIL"
            Result = $null
            Message = $_.Exception.Message
        })
    }

    # Test 4: Prerequisites Check
    try {
        $prereqs = Test-PSOpsPrerequisites
        $passCount = @($prereqs | Where-Object Installed -eq $true).Count
        
        $results.Add([PSCustomObject]@{
            Test = "Prerequisites Check"
            Status = "PASS"
            Result = "$passCount/$($prereqs.Count) met"
            Message = "Prerequisites check completed successfully"
        })
    }
    catch {
        $results.Add([PSCustomObject]@{
            Test = "Prerequisites Check"
            Status = "FAIL"
            Result = $null
            Message = $_.Exception.Message
        })
    }

    # Summary
    $passCount = @($results | Where-Object Status -eq "PASS").Count
    $failCount = @($results | Where-Object Status -eq "FAIL").Count
    
    Write-Host "`nCompatibility Test Results:" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
    
    if ($failCount -eq 0) {
        Write-Host "✓ All tests passed! Module is compatible with PowerShell $($psInfo.Version)" -ForegroundColor Green
    } else {
        Write-Host "✗ $failCount tests failed. Review results above." -ForegroundColor Red
    }

    return [PSCustomObject]@{
        PowerShellVersion = $psInfo.Version
        PowerShellEdition = $psInfo.Edition
        Platform = Get-PSOpsPlatform
        TestsPassed = $passCount
        TestsFailed = $failCount
        TotalTests = $results.Count
        IsCompatible = ($failCount -eq 0)
        Results = $results
        Timestamp = Get-Date
    }
}