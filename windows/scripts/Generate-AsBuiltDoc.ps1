<#
.SYNOPSIS
    Generate As-Built documentation from collected configuration.

.DESCRIPTION
    Wrapper script that runs the Node.js document generator.
    Ensures npm dependencies are installed.

.PARAMETER ConfigFile
    Path to the JSON configuration file.

.PARAMETER OutputFile
    Path for the output Word document.

.PARAMETER DiagramFile
    Optional path to architecture diagram PNG.

.EXAMPLE
    .\Generate-AsBuiltDoc.ps1 -ConfigFile ".\output\config.json" -OutputFile ".\output\AsBuilt.docx"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [string]$DiagramFile
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is not installed. Please install Node.js from https://nodejs.org"
    exit 1
}

# Check/Install docx module
$nodeModulesPath = Join-Path $ScriptDir "node_modules"
$docxPath = Join-Path $nodeModulesPath "docx"

if (-not (Test-Path $docxPath)) {
    Write-Host "Installing docx npm package..." -ForegroundColor Yellow
    Push-Location $ScriptDir
    npm install docx
    Pop-Location
}

# Build arguments
$nodeScript = Join-Path $ScriptDir "generate_asbuilt_doc.js"
$args = @($nodeScript, $ConfigFile, $OutputFile)

if ($DiagramFile) {
    $args += @("--diagram", $DiagramFile)
}

# Run generator
Write-Host "Generating As-Built document..." -ForegroundColor Cyan
& node $args

if ($LASTEXITCODE -eq 0) {
    Write-Host "Document generated successfully: $OutputFile" -ForegroundColor Green
    
    # Open document if on Windows
    if ($env:OS -eq "Windows_NT") {
        $openDoc = Read-Host "Open document now? (y/n)"
        if ($openDoc -eq 'y') {
            Start-Process $OutputFile
        }
    }
} else {
    Write-Error "Document generation failed"
    exit 1
}
