BeforeAll {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $moduleRoot 'PSOpsCore.psd1') -Force
}

Describe 'PSOpsCore manifest' {
    It 'imports successfully' {
        Get-Module PSOpsCore | Should -Not -BeNullOrEmpty
    }

    It 'exports expected public functions' {
        $commands = Get-Command -Module PSOpsCore | Select-Object -ExpandProperty Name
        $commands | Should -Contain 'Get-PSOpsCoreSecret'
        $commands | Should -Contain 'Publish-PSOpsPackage'
        $commands | Should -Contain 'Test-PSOpsPrerequisites'
    }
}
