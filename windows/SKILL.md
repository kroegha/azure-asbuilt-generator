---
name: azure-asbuilt-generator
description: |
  Automatically collect Azure API service configuration and generate professional As-Built documentation.
  Windows/PowerShell compatible for use with Claude Code.
  
  Use when asked to create as-built documentation for Azure APIM services, Logic Apps integrations,
  or any Azure API service following the Front Door → WAF → APIM → Logic Apps → Data Gateway → SQL pattern.
---

# Azure As-Built Documentation Generator (Windows/PowerShell)

## Overview

This skill automates the collection of Azure service configuration and generation of professional As-Built documentation. Fully compatible with **Windows** and **Claude Code** using PowerShell.

**Architecture Pattern Supported:**
```
Front Door → WAF → APIM → Logic Apps → On-Premises Data Gateway → SQL Server
```

## When to Use This Skill

Use this skill when the user asks to:
- Create as-built documentation for an Azure API service
- Document an APIM API configuration
- Generate technical documentation for a Logic App workflow
- Document an integration service going to production

## Prerequisites

1. **PowerShell 5.1+** or **PowerShell 7+** (Windows/cross-platform)
2. **Azure CLI** installed and logged in (`az login`) OR **Az PowerShell Module** (`Connect-AzAccount`)
3. **Node.js** (for document generation)
4. Appropriate Azure permissions (Reader role on resources)

### Check Prerequisites
```powershell
# Check Azure CLI
az --version
az account show

# OR Check Az PowerShell Module
Get-Module -ListAvailable Az.Accounts
Get-AzContext
```

## Directory Structure

```
azure-asbuilt-generator/
├── SKILL.md                          # This file
├── scripts/
│   ├── Collect-AzureConfig.ps1       # Main collection script
│   └── Generate-AsBuiltDoc.ps1       # Document generator wrapper
├── references/
│   └── shared_infrastructure.json    # Static Front Door/WAF config
├── templates/
└── output/                           # Generated files
```

## Quick Start

### Step 1: Collect Configuration

```powershell
# Using Azure CLI (recommended)
.\scripts\Collect-AzureConfig.ps1 `
    -ApimName "apim-sanparks-prod" `
    -ResourceGroup "rg-integration-prod" `
    -ApiName "fnb-bank-statements" `
    -UseAzureCLI

# Using Az PowerShell Module
.\scripts\Collect-AzureConfig.ps1 `
    -ApimName "apim-sanparks-prod" `
    -ResourceGroup "rg-integration-prod" `
    -ApiName "fnb-bank-statements"
```

### Step 2: Generate Document

```powershell
# Install docx package if needed
npm install docx

# Generate Word document
node .\scripts\generate_asbuilt_doc.js `
    ".\output\config_fnb-bank-statements_*.json" `
    ".\output\AsBuilt_FNB_BankStatements.docx"
```

## Detailed Workflow

### Phase 1: Information Gathering

Before running collection, gather from user:

| Parameter | Description | Example |
|-----------|-------------|---------|
| ApimName | APIM instance name | `apim-sanparks-prod` |
| ResourceGroup | APIM resource group | `rg-integration-prod` |
| ApiName | Specific API to document | `fnb-bank-statements` |

### Phase 2: Automated Collection

The script automatically collects:

1. **APIM Instance** - SKU, capacity, gateway URL, identity
2. **API Configuration** - Path, backend URL, operations, policies
3. **Logic App** - Detected from API backend URL (azurewebsites.net)
4. **Workflow Definition** - Triggers, actions, connections (via REST API)
5. **API Connections** - SQL, Data Gateway references
6. **Key Vault** - Secrets inventory (names only)
7. **Application Insights** - Instrumentation key, retention

### Phase 3: Document Generation

The generator creates a professional Word document with:

- Executive Summary
- Architecture Overview (with diagram if provided)
- Shared Infrastructure (Front Door, WAF)
- API Management Configuration
- Logic App & Workflow Details
- Data Connectivity (connections, gateway)
- Security Configuration (Key Vault)
- Monitoring (Application Insights)

## PowerShell Script Parameters

```powershell
.\Collect-AzureConfig.ps1
    -ApimName <string>           # Required: APIM instance name
    -ResourceGroup <string>      # Required: Resource group
    -ApiName <string>            # Required: API name to document
    [-OutputPath <string>]       # Optional: Output directory (default: .\output)
    [-UseAzureCLI]              # Optional: Use Azure CLI instead of Az module
```

## Manual Collection (If Script Fails)

If the automated script encounters issues, collect manually:

### Using Azure CLI

```powershell
# 1. APIM Instance
az apim show --name "apim-name" --resource-group "rg-name" -o json > apim.json

# 2. API Configuration
az apim api show --api-id "api-name" --service-name "apim-name" --resource-group "rg-name" -o json > api.json

# 3. API Operations
az apim api operation list --api-id "api-name" --service-name "apim-name" --resource-group "rg-name" -o json > operations.json

# 4. Logic App (Standard)
az webapp show --name "logic-app-name" --resource-group "rg-name" -o json > logicapp.json

# 5. Workflow Definition (REST API)
$token = az account get-access-token --query accessToken -o tsv
$subscriptionId = az account show --query id -o tsv
$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/rg-name/providers/Microsoft.Web/sites/logic-app-name/hostruntime/runtime/webhooks/workflow/api/management/workflows/workflow-name?api-version=2022-03-01"

Invoke-RestMethod -Uri $uri -Headers @{Authorization="Bearer $token"} -Method Get | ConvertTo-Json -Depth 20 > workflow.json

# 6. API Connections
az resource list --resource-group "rg-name" --resource-type "Microsoft.Web/connections" -o json > connections.json

# 7. Key Vault
az keyvault show --name "kv-name" -o json > keyvault.json
az keyvault secret list --vault-name "kv-name" -o json > secrets.json

# 8. Application Insights
az monitor app-insights component show --app "ai-name" --resource-group "rg-name" -o json > appinsights.json
```

### Using Az PowerShell Module

```powershell
# 1. APIM
$apim = Get-AzApiManagement -ResourceGroupName "rg-name" -Name "apim-name"

# 2. API
$ctx = New-AzApiManagementContext -ResourceGroupName "rg-name" -ServiceName "apim-name"
$api = Get-AzApiManagementApi -Context $ctx -ApiId "api-name"
$operations = Get-AzApiManagementOperation -Context $ctx -ApiId "api-name"

# 3. Logic App
$logicApp = Get-AzWebApp -ResourceGroupName "rg-name" -Name "logic-app-name"

# 4. Key Vault
$kv = Get-AzKeyVault -VaultName "kv-name" -ResourceGroupName "rg-name"
$secrets = Get-AzKeyVaultSecret -VaultName "kv-name"

# 5. App Insights
$ai = Get-AzApplicationInsights -ResourceGroupName "rg-name" -Name "ai-name"
```

## Shared Infrastructure Configuration

Front Door and WAF are typically shared across services. Update once in `references/shared_infrastructure.json`:

```json
{
  "front_door": {
    "resource_name": "fd-bios-prod-001",
    "resource_group": "rg-networking-prod",
    "sku": "Standard_AzureFrontDoor",
    "endpoint": "bios-api.azurefd.net",
    "custom_domains": ["api.client.co.za"],
    "ssl_certificate": "Azure Managed"
  },
  "waf": {
    "policy_name": "waf-bios-prod-001",
    "resource_group": "rg-networking-prod",
    "mode": "Prevention",
    "rule_set": "Microsoft_DefaultRuleSet 2.1",
    "bot_protection": true
  }
}
```

## Troubleshooting

### "Not connected to Azure"
```powershell
# Azure CLI
az login
az account set --subscription "Your Subscription Name"

# Az PowerShell
Connect-AzAccount
Set-AzContext -Subscription "Your Subscription Name"
```

### "Access denied to workflow definition"
Logic App Standard workflows require specific permissions:
- `Microsoft.Web/sites/hostruntime/webhooks/api/workflows/read`
- Try with Contributor or Website Contributor role

### "APIM API not found"
List available APIs first:
```powershell
az apim api list --service-name "apim-name" --resource-group "rg-name" --query "[].{name:name,path:path}" -o table
```

### "Node.js docx module not found"
```powershell
cd .\scripts
npm install docx
```

## Output Files

| File | Description |
|------|-------------|
| `config_<api>_<timestamp>.json` | Collected configuration |
| `AsBuilt_<api>.docx` | Generated Word document |
| `architecture.png` | Architecture diagram (if generated) |

## Integration with Claude Code

When using with Claude Code on Windows:

1. **Working Directory**: Ensure you're in the skill directory
2. **Execution Policy**: May need `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. **Path Separators**: Use backslashes (`\`) or forward slashes (`/`) - PowerShell accepts both

### Example Claude Code Session

```
User: Create as-built documentation for the FNB Bank Statements API

Claude: I'll collect the Azure configuration and generate the documentation.

1. First, let me run the collection script:
   [Runs Collect-AzureConfig.ps1]

2. Now generating the Word document:
   [Runs generate_asbuilt_doc.js]

3. Here's your As-Built documentation:
   [Presents AsBuilt_FNB_BankStatements.docx]
```

## Related Skills

- `infrastructure-diagrams` - Generate architecture diagrams
- `docx` - Advanced Word document manipulation
- `logic-apps-qos-reporter` - Logic Apps monitoring reports

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | 2025-01 | Windows/PowerShell compatible version |
| 1.0 | 2025-01 | Initial Linux/bash version |
