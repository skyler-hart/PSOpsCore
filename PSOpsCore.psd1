@{
    RootModule           = 'PSOpsCore.psm1'
    ModuleVersion        = '0.3.0'
    GUID                 = '6e730f3c-f67b-4d44-8fa9-0c14cbacdc39'
    Author               = 'Skyler Hart'
    CompanyName          = 'Skyler Hart'
    Copyright            = '(c) Skyler Hart. All rights reserved.'
    Description          = 'Cross-platform internal PowerShell core module for automation, secrets, and publishing workflows. Compatible with PowerShell 5.1+ (Desktop and Core editions).'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @(
        'Deploy-PSOpsCore',
        'Deploy-SkyPSTest',
        'Get-PSOpsCoreSecret',
        'Publish-PSOpsCore',
        'Publish-SkyPSTest',
        'Publish-SNPlatformToolsDev',
        'Register-PSOpsCoreRepo',
        'Remove-PSOpsCorePackage',
        'Remove-PSOpsOldPackages',
        'Test-PSOpsCompatibility',
        'Test-PSOpsPrerequisites',
        'Update-GitRepos'
    )

    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    DscResourcesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('PowerShell', 'CrossPlatform', 'Automation', 'Internal')
            ProjectUri   = 'https://github.com/skyler-hart/PSOpsCore'
            LicenseUri   = 'https://github.com/skyler-hart/PSOpsCore/blob/main/LICENSE'
            ReleaseNotes = 'Initial scaffold.'
        }
    }
}
