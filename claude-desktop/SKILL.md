---
name: azure-asbuilt-generator
description: |
  Automatically collect Azure API service configuration and generate professional As-Built documentation.
  Claude Desktop version - works cross-platform via manual script execution.
  
  Use when asked to create as-built documentation for Azure APIM services, Logic Apps integrations,
  or any Azure API service following the Front Door → WAF → APIM → Logic Apps → Data Gateway → SQL pattern.
---

# Azure As-Built Documentation Generator (Claude Desktop)

## Overview

This skill automates the collection of Azure service configuration and generation of professional As-Built documentation. This version is designed for **Claude Desktop** users on Windows, macOS, or Linux.

**Architecture Pattern Supported:**
```
Front Door → WAF → APIM → Logic Apps → On-Premises Data Gateway → SQL Server
```

## Prerequisites

1. **Claude Desktop** installed
2. **Azure CLI** installed and logged in (`az login`)
3. **Node.js 18+** installed
4. **PowerShell 7+** (cross-platform) OR **Bash** (Linux/macOS)
5. Appropriate Azure permissions (Reader role on resources)

## Quick Start

### Step 1: Install Dependencies

```bash
cd claude-desktop/scripts
npm install docx
```

### Step 2: Login to Azure

```bash
az login
az account set --subscription "Your Subscription Name"
```

### Step 3: Collect Configuration

**Windows (PowerShell):**
```powershell
.\Collect-AzureConfig.ps1 -ApimName "apim-prod" -ResourceGroup "rg-prod" -ApiName "my-api" -UseAzureCLI
```

**Linux/macOS (Bash):**
```bash
./collect_azure_config.sh "apim-prod" "rg-prod" "my-api" "../output"
```

### Step 4: Generate Document

```bash
node generate_asbuilt_doc.js "../output/config_my-api_*.json" "../output/AsBuilt.docx"
```

## Usage with Claude Desktop

Simply ask Claude to generate documentation:

```
User: Create as-built documentation for the Customer API in APIM instance 
      apim-company-prod, resource group rg-integration-prod

Claude: I'll help you generate that documentation. Please run these commands:

        1. Open PowerShell/Terminal and navigate to the scripts folder
        2. Run: .\Collect-AzureConfig.ps1 -ApimName "apim-company-prod" ...
        3. Run: node generate_asbuilt_doc.js ...
        
        The document will be created in the output folder.
```

## Scripts Reference

| Script | Platform | Description |
|--------|----------|-------------|
| `Collect-AzureConfig.ps1` | Windows/PowerShell 7 | Collects Azure config via CLI or Az Module |
| `collect_azure_config.sh` | Linux/macOS | Collects Azure config via Azure CLI |
| `generate_asbuilt_doc.js` | All platforms | Generates Word document from JSON |
| `azure_config_collector.py` | All platforms | Python workflow parser (optional) |

## PowerShell Parameters

```powershell
.\Collect-AzureConfig.ps1
    -ApimName <string>        # APIM instance name (required)
    -ResourceGroup <string>   # Resource group name (required)
    -ApiName <string>         # API name to document (required)
    -OutputPath <string>      # Output directory (default: ../output)
    -UseAzureCLI              # Use Azure CLI instead of Az Module
```

## Bash Arguments

```bash
./collect_azure_config.sh <apim-name> <resource-group> <api-name> [output-path]
```

## What Gets Documented

| Component | Information Collected |
|-----------|----------------------|
| **APIM** | SKU, capacity, gateway URL, VNet config |
| **API** | Operations, policies, backend URL |
| **Logic Apps** | Workflow actions, triggers, state |
| **Connections** | API connections, SQL, Service Bus |
| **Data Gateway** | Name, status, machine |
| **Key Vault** | Secret names (not values) |
| **App Insights** | Instrumentation key, retention |
| **Front Door/WAF** | From shared_infrastructure.json |

## Customization

### Shared Infrastructure

Edit `references/shared_infrastructure.json` with your organization's Front Door and WAF details:

```json
{
  "front_door": {
    "resource_name": "fd-yourcompany-prod-001",
    "endpoint_hostname": "api.yourcompany.com"
  },
  "waf": {
    "policy_name": "waf-yourcompany-prod-001"
  }
}
```

## Directory Structure

```
claude-desktop/
├── SKILL.md                              # This file
├── claude_desktop_config.example.json    # MCP config example
├── scripts/
│   ├── Collect-AzureConfig.ps1           # PowerShell collector
│   ├── collect_azure_config.sh           # Bash collector  
│   ├── generate_asbuilt_doc.js           # Document generator
│   └── azure_config_collector.py         # Workflow parser
├── references/
│   └── shared_infrastructure.json        # Shared infra template
├── output/                               # Generated files
└── templates/                            # Custom templates
```

## Troubleshooting

### Azure CLI not found
```bash
# Install Azure CLI
# Windows: winget install Microsoft.AzureCLI
# macOS: brew install azure-cli
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Node.js not found
Download from https://nodejs.org (LTS version recommended)

### docx module missing
```bash
cd scripts
npm install docx
```

### Authentication errors
```bash
az login
az account list --output table
az account set --subscription "Correct Subscription"
```

## Related Versions

- `windows/` - Optimized for Windows + Claude Code
- `linux/` - Optimized for Linux/macOS + Claude Code
- `claude-desktop/` - This version (cross-platform, Claude Desktop)
