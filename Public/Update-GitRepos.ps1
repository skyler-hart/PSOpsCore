function Update-GitRepos {
    <#
    .SYNOPSIS
        Updates all Git repositories found in the development folder or specified path.

    .DESCRIPTION
        Searches for Git repositories and performs git fetch and pull operations on each.
        If no RootPath is specified, automatically finds the main development folder using Get-PSOpsDevFolder.

    .PARAMETER RootPath
        The root path to search for Git repositories. If not specified, uses Get-PSOpsDevFolder to find the main development folder.

    .PARAMETER Recurse
        Search for repositories recursively in subdirectories.

    .PARAMETER IncludeDirty
        Include repositories with uncommitted changes (normally skipped).

    .PARAMETER ThrottleLimit
        Maximum number of repositories to update in parallel (1-100). Default is 5.

    .PARAMETER PassThru
        Return detailed results for each repository processed.

    .EXAMPLE
        Update-GitRepos
        Updates all repositories in the automatically detected development folder.

    .EXAMPLE
        Update-GitRepos -RootPath '/Users/username/Projects' -Recurse
        Updates all repositories in the specified path and its subdirectories.

    .EXAMPLE
        Update-GitRepos -IncludeDirty -PassThru | Where-Object Status -eq 'Failed'
        Updates all repositories including dirty ones and shows only failed updates.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RootPath,

        [switch]$Recurse,
        [switch]$IncludeDirty,

        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = 5,

        [switch]$PassThru
    )

    # If no RootPath specified, try to find the development folder automatically
    if (-not $RootPath) {
        $RootPath = Get-PSOpsDevFolder
        if (-not $RootPath) {
            throw "Could not automatically find development folder. Please specify -RootPath parameter."
        }
        Write-Verbose "Using automatically detected development folder: $RootPath"
    }

    if (-not (Test-Path -LiteralPath $RootPath)) {
        throw "Path not found: $RootPath"
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or not available in PATH."
    }

    $folders = if ($Recurse) {
        Get-ChildItem -LiteralPath $RootPath -Directory -Recurse -ErrorAction Stop
    }
    else {
        Get-ChildItem -LiteralPath $RootPath -Directory -ErrorAction Stop
    }

    $repos = $folders | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName '.git')
    }

    if (-not $repos) {
        Write-Warning "No Git repositories found under: $RootPath"
        return
    }

    Write-Host "Found $($repos.Count) Git repo(s). Starting parallel update..." -ForegroundColor Cyan

    $results = $repos | ForEach-Object -Parallel {
        $repoPath = $_.FullName
        $repoName = $_.Name
        $includeDirty = $using:IncludeDirty

        $result = [pscustomobject]@{
            Name          = $repoName
            Repo          = $repoPath
            Branch        = $null
            Dirty         = $false
            FetchSucceeded = $false
            PullSucceeded  = $false
            Status        = $null
            Message       = $null
        }

        try {
            $branch = git -C $repoPath branch --show-current 2>$null
            if ($branch) {
                $result.Branch = $branch.Trim()
            }

            $statusOutput = git -C $repoPath status --porcelain 2>$null
            if ($statusOutput) {
                $result.Dirty = $true
            }

            if ($result.Dirty -and -not $includeDirty) {
                $result.Status = 'Skipped'
                $result.Message = 'Uncommitted changes detected'
                return $result
            }

            $fetchOutput = git -C $repoPath fetch --all --prune 2>&1
            if ($LASTEXITCODE -ne 0) {
                $result.Status = 'Failed'
                $result.Message = ($fetchOutput | Out-String).Trim()
                return $result
            }

            $result.FetchSucceeded = $true

            $pullOutput = git -C $repoPath pull --ff-only 2>&1
            if ($LASTEXITCODE -ne 0) {
                $result.Status = 'Failed'
                $result.Message = ($pullOutput | Out-String).Trim()
                return $result
            }

            $result.PullSucceeded = $true
            $result.Status = 'Updated'
            $result.Message = (($pullOutput | Out-String).Trim() -replace '\s+', ' ')
            return $result
        }
        catch {
            $result.Status = 'Failed'
            $result.Message = $_.Exception.Message
            return $result
        }
    } -ThrottleLimit $ThrottleLimit

    foreach ($item in $results | Sort-Object Repo) {
        switch ($item.Status) {
            'Updated' {
                Write-Host "`n=== $($item.Repo) ===" -ForegroundColor Cyan
                Write-Host "Updated successfully" -ForegroundColor Green
                if ($item.Branch) {
                    Write-Host "Branch: $($item.Branch)" -ForegroundColor DarkGray
                }
            }
            'Skipped' {
                Write-Host "`n=== $($item.Repo) ===" -ForegroundColor Cyan
                Write-Host "Skipped: $($item.Message)" -ForegroundColor Yellow
                if ($item.Branch) {
                    Write-Host "Branch: $($item.Branch)" -ForegroundColor DarkGray
                }
            }
            'Failed' {
                Write-Host "`n=== $($item.Repo) ===" -ForegroundColor Cyan
                Write-Host "Failed: $($item.Message)" -ForegroundColor Red
                if ($item.Branch) {
                    Write-Host "Branch: $($item.Branch)" -ForegroundColor DarkGray
                }
            }
            default {
                Write-Host "`n=== $($item.Repo) ===" -ForegroundColor Cyan
                Write-Host "Unknown result" -ForegroundColor Magenta
            }
        }
    }

    $summary = [pscustomobject]@{
        RootPath = $RootPath
        Total    = $results.Count
        Updated  = @($results | Where-Object Status -eq 'Updated').Count
        Skipped  = @($results | Where-Object Status -eq 'Skipped').Count
        Failed   = @($results | Where-Object Status -eq 'Failed').Count
    }

    Write-Host "`nSummary" -ForegroundColor Cyan
    Write-Host "-------" -ForegroundColor Cyan
    Write-Host "Total   : $($summary.Total)"
    Write-Host "Updated : $($summary.Updated)" -ForegroundColor Green
    Write-Host "Skipped : $($summary.Skipped)" -ForegroundColor Yellow
    Write-Host "Failed  : $($summary.Failed)" -ForegroundColor Red

    if ($PassThru) {
        return $results | Sort-Object Repo
    }
}