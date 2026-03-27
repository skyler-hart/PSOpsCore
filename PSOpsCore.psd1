@{
    RootModule           = 'PSOpsCore.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '6e730f3c-f67b-4d44-8fa9-0c14cbacdc39'
    Author               = 'Skyler Hart'
    CompanyName          = 'Skyler Hart'
    Copyright            = '(c) Skyler Hart. All rights reserved.'
    Description          = 'Cross-platform internal PowerShell core module for automation, secrets, and publishing workflows.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Get-PSOpsCoreSecret',
        'Publish-PSOpsPackage',
        'Test-PSOpsPrerequisites'
    )

    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    DscResourcesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('PowerShell', 'CrossPlatform', 'Automation', 'Internal')
            ProjectUri   = 'https://github.com/REPLACE_WITH_YOUR_ORG_OR_USER/PSOpsCore'
            LicenseUri   = 'https://github.com/REPLACE_WITH_YOUR_ORG_OR_USER/PSOpsCore/blob/main/LICENSE'
            ReleaseNotes = 'Initial scaffold.'
        }
    }
}
