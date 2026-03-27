# PSOpsCore

PSOpsCore is the internal cross-platform PowerShell foundation module for Sky's tooling and automation work.

It is intended to provide shared primitives for:

- secret retrieval
- repository publishing workflows
- platform detection
- common logging/output helpers
- reusable internal utility functions

The repository is public, but secrets are never stored in the repository. Secret access is expected to happen at runtime through the 1Password CLI.

## Prerequisites

### PowerShell

PSOpsCore supports both **PowerShell 5.1 (Windows PowerShell)** and **PowerShell 7+ (PowerShell Core)**.

- **PowerShell 5.1**: Windows-only functionality with full module compatibility
- **PowerShell 7+**: Full cross-platform support (Windows, macOS, Linux)

Check your version:

```powershell
$PSVersionTable.PSVersion
$PSVersionTable.PSEdition  # Shows 'Desktop' (5.1) or 'Core' (6+)
```

#### For PowerShell 7+ (Cross-Platform)

If needed, install PowerShell from the official docs:

- [Install PowerShell on Windows](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- [Install PowerShell on macOS](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos)
- [Install PowerShell on Linux](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)

#### For PowerShell 5.1 (Windows PowerShell)

PowerShell 5.1 comes pre-installed on Windows 10/11 and Windows Server 2016+. The module will automatically detect the version and provide Windows-only functionality.

### 1Password CLI

PSOpsCore expects secrets to be retrieved through the **1Password CLI (`op`)**.

After installation, verify it is available:

```powershell
op --version
```

#### Windows

Using winget:

```powershell
winget install AgileBits.1Password.CLI
```

Alternative install methods are available in the official docs:

- [1Password CLI for Windows](https://developer.1password.com/docs/cli/get-started/)

#### macOS

Using Homebrew:

```bash
brew install --cask 1password-cli
```

Official docs:

- [1Password CLI for macOS](https://developer.1password.com/docs/cli/get-started/)

#### Ubuntu / Debian

Use the official 1Password installation instructions for Debian-based Linux distributions:

- [1Password CLI for Linux](https://developer.1password.com/docs/cli/get-started/)

After installation, verify:

```bash
op --version
```

### Recommended PowerShell modules for development

Install Pester for local testing:

```powershell
Install-Module Pester -Scope CurrentUser -Force
```

## 1Password setup

Create a vault/item structure that is boring and predictable.

Example:

- Vault: `Development`
- Item: `BaGet`
- Field: `apiKey`
- Field: `sourceUrl`

Then test access:

```powershell
op read "op://Development/BaGet/apiKey"
op read "op://Development/BaGet/sourceUrl"
```

If you are using the desktop app integration, make sure the CLI can authenticate successfully first.


## Getting started

Clone the repo, then from the repository root:

```powershell
Import-Module ./PSOpsCore.psd1 -Force
Test-PSOpsPrerequisites
```

## Compatibility

PSOpsCore automatically detects the PowerShell version and adapts its behavior accordingly:

### PowerShell 5.1 (Windows PowerShell)
- **Platform**: Windows only
- **Features**: Full module functionality with Windows-specific paths
- **Limitations**: No cross-platform features (Get-PSOpsPlatform returns 'Windows')
- **REST API**: Uses compatibility layer for consistent behavior

### PowerShell 7+ (PowerShell Core)
- **Platform**: Windows, macOS, Linux
- **Features**: Full cross-platform functionality
- **Advanced**: Modern PowerShell features, improved REST API support
- **Performance**: Better array handling and generic collections

### Version Detection

You can check PowerShell compatibility in your scripts:

```powershell
$psInfo = Get-PSVersion
if ($psInfo.IsCore) {
    # Use PowerShell Core features
    Write-Host "Running on PowerShell Core $($psInfo.Version)"
} else {
    # Use PowerShell 5.1 compatible features
    Write-Host "Running on Windows PowerShell $($psInfo.Version)"
}
```

## Example usage

Read a secret from 1Password:

```powershell
Get-PSOpsCoreSecret -Path 'op://Development/BaGet/apiKey'
```

## Development notes

- Public functions live in `Public/`
- Internal helpers live in `Private/`
- The root module dot-sources all `.ps1` files in those folders
- Exported functions are controlled in the module manifest
- Secrets should never be committed to the repo

## Next recommended additions

- platyPS help generation
- module packaging helper
- semantic version bump helper
- repository registration helper for internal feeds
- centralized logging helper
- retry wrapper for CLI/network calls

## Security notes

- Do not commit API keys, PATs, passwords, or local config containing secrets
- Do not store secrets in the module manifest
- Do not base64-encode secrets and pretend that counts as security
- Use 1Password for local secret retrieval and GitHub secrets or another secret manager for CI/CD

## Other notes

- Modules on macOS get saved to: ~/.local/share/powershell/Modules