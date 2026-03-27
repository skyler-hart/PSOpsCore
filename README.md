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

PSOpsCore targets **PowerShell 7+**.

Check your version:

```powershell
$PSVersionTable.PSVersion
```

If needed, install PowerShell from the official docs:

- [Install PowerShell on Windows](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- [Install PowerShell on macOS](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos)
- [Install PowerShell on Linux](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)

### 1Password CLI

PSOpsCore expects secrets to be retrieved through the **1Password CLI (`op`)**.

After installation, verify it is available:

```powershell
op --version
```

#### Windows

Using winget:

```powershell
winget install 1Password.CLI
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

## Example usage

Read a secret from 1Password:

```powershell
Get-PSOpsCoreSecret -Path 'op://Development/BaGet/apiKey'
```

Publish a package to BaGet:

```powershell
Publish-PSOpsPackage -NupkgPath ./output/MyModule.1.0.0.nupkg
```

Override the source path directly:

```powershell
Publish-PSOpsPackage \
    -NupkgPath ./output/MyModule.1.0.0.nupkg \
    -SourceUrl 'https://baget.example.com/v3/index.json'
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
