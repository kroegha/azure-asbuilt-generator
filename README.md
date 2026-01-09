# Azure As-Built Documentation Generator

[![Azure](https://img.shields.io/badge/Azure-0089D6?style=flat&logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)](https://docs.microsoft.com/powershell/)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat&logo=node.js&logoColor=white)](https://nodejs.org)
[![Claude](https://img.shields.io/badge/Claude-Anthropic-orange)](https://claude.ai)

Automatically collect Azure API service configuration and generate professional As-Built documentation. This Claude Skill supports the standard enterprise integration architecture pattern used by organizations deploying APIs on Azure.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture Supported](#architecture-supported)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Claude Code (Windows)](#claude-code-windows)
  - [Claude Code (Linux/macOS)](#claude-code-linuxmacos)
  - [Claude Desktop](#claude-desktop)
- [Usage](#usage)
- [Script Reference](#script-reference)
- [Configuration Files](#configuration-files)
- [Output Examples](#output-examples)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

The **Azure As-Built Documentation Generator** is a Claude Skill that automates the tedious process of documenting Azure API integration services. Instead of manually gathering configuration from multiple Azure resources and copying into Word documents, this skill:

1. **Collects** configuration from Azure resources using Azure CLI or Az PowerShell
2. **Parses** Logic App workflows to document triggers, actions, and data flows
3. **Aggregates** all configuration into a structured JSON format
4. **Generates** professional Word documents with proper formatting, tables, and diagrams

### Why This Skill?

- **Time Savings**: Reduce documentation time from hours to minutes
- **Consistency**: Ensure all As-Built documents follow the same professional format
- **Accuracy**: Eliminate copy-paste errors by pulling directly from Azure
- **Compliance**: Meet audit requirements with comprehensive technical documentation
- **Automation**: Integrate into CI/CD pipelines for automatic doc updates

---

## Architecture Supported

This skill is designed for the common enterprise API integration pattern:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │      Azure Front Door         │
                    │   (Global Load Balancing)     │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │    Web Application Firewall   │
                    │   (WAF Policy - Prevention)   │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │    Azure API Management       │
                    │  (Authentication, Policies)   │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │    Logic Apps (Standard)      │
                    │   (Business Logic/Workflow)   │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │  On-Premises Data Gateway     │
                    │    (Hybrid Connectivity)      │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │      SQL Server Database      │
                    │     (On-Premises/Azure)       │
                    └───────────────────────────────┘

Supporting Services:
├── Azure Key Vault (Secrets Management)
└── Application Insights (Monitoring & Logging)
```

### Components Documented

| Component | Information Collected |
|-----------|----------------------|
| **Front Door** | Endpoints, custom domains, SSL, routing rules, health probes |
| **WAF** | Policy mode, rule sets, custom rules, IP whitelists |
| **API Management** | SKU, capacity, gateway URL, APIs, operations, policies |
| **Logic Apps** | Type, state, identity, workflow definition |
| **Workflows** | Triggers, actions (in order), connections, data sources |
| **Data Gateway** | Region, host machine, cluster members |
| **Key Vault** | SKU, secrets inventory (names only), access policies |
| **App Insights** | Instrumentation key, retention, workspace |

---

## Features

### ✅ Multi-Platform Support
- **Windows**: PowerShell 5.1+ with Azure CLI or Az Module
- **Linux/macOS**: Bash with Azure CLI
- **Claude Desktop**: Cross-platform via MCP server

### ✅ Intelligent Collection
- Auto-detects Logic App from APIM backend URL
- Parses workflow definitions via Azure REST API
- Identifies SQL and Data Gateway connections
- Finds associated Key Vault and App Insights

### ✅ Workflow Documentation
- Extracts triggers with descriptions
- Orders actions by execution dependency
- Identifies data sources (SQL, SharePoint, etc.)
- Lists all API connections

### ✅ Professional Output
- Word document with Table of Contents
- Consistent formatting and styling
- Header/footer with confidentiality notice
- Architecture diagram support
- Alternating row colors in tables

---

## Repository Structure

```
azure-asbuilt-generator/
│
├── README.md                           # This file
├── LICENSE                             # MIT License
│
├── windows/                            # Windows/PowerShell version
│   ├── SKILL.md                        # Claude Skill definition
│   ├── scripts/
│   │   ├── Collect-AzureConfig.ps1     # Main collection script
│   │   ├── Generate-AsBuiltDoc.ps1     # Document generation wrapper
│   │   └── generate_asbuilt_doc.js     # Node.js document generator
│   ├── references/
│   │   └── shared_infrastructure.json  # Front Door/WAF template
│   ├── output/                         # Generated files
│   └── templates/                      # Custom templates (future)
│
├── linux/                              # Linux/Bash version
│   ├── SKILL.md                        # Claude Skill definition
│   ├── scripts/
│   │   ├── collect_azure_config.sh     # Bash collection script
│   │   ├── azure_config_collector.py   # Python workflow parser
│   │   └── generate_asbuilt_doc.js     # Node.js document generator
│   ├── references/
│   │   └── shared_infrastructure.json
│   ├── output/
│   └── templates/
│
├── claude-desktop/                     # Claude Desktop version
│   ├── SKILL.md                        # Claude Skill definition
│   ├── claude_desktop_config.example.json
│   ├── scripts/
│   │   ├── Collect-AzureConfig.ps1     # PowerShell collector
│   │   ├── collect_azure_config.sh     # Bash collector
│   │   ├── azure_config_collector.py   # Python workflow parser
│   │   └── generate_asbuilt_doc.js     # Node.js document generator
│   ├── references/
│   │   └── shared_infrastructure.json
│   ├── output/
│   └── templates/
│
├── examples/
│   ├── sample_config.json              # Example collected configuration
│   └── Sample_AsBuilt.docx             # Example generated document
│
└── diagrams/
    └── apim_architecture.png           # Architecture diagram
```

---

## Prerequisites

### All Platforms

| Requirement | Version | Purpose |
|-------------|---------|--------|
| Node.js | 18+ | Document generation |
| Azure CLI | 2.50+ | Azure resource collection |
| Azure Subscription | - | Reader access to resources |

### Windows Additional

| Requirement | Version | Purpose |
|-------------|---------|--------|
| PowerShell | 5.1+ or 7+ | Script execution |
| Az PowerShell Module | 9.0+ | Alternative to Azure CLI |

### Linux/macOS Additional

| Requirement | Version | Purpose |
|-------------|---------|--------|
| Bash | 4.0+ | Script execution |
| jq | 1.6+ | JSON parsing |
| Python | 3.8+ | Workflow parsing (optional) |

### Azure Permissions

The following RBAC roles are required:

| Resource | Minimum Role |
|----------|-------------|
| API Management | Reader |
| Logic Apps | Reader |
| Key Vault | Reader + Secrets List |
| Application Insights | Reader |
| Connections/Gateways | Reader |

For Logic App Standard workflow definitions, you may need:
- `Microsoft.Web/sites/hostruntime/webhooks/api/workflows/read`
- Or **Website Contributor** role

---

## Installation

### Claude Code (Windows)

Claude Code is Anthropic's command-line tool for agentic coding. Skills are automatically detected from the skills folder.

#### Step 1: Clone Repository

```powershell
# Clone to your preferred location
git clone https://github.com/kroegha/azure-asbuilt-generator.git C:\Azure-As-Built\azure-asbuilt-generator
```

#### Step 2: Copy Skill to Skills Folder

```powershell
# Create skills directory if it doesn't exist
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude\skills" -Force

# Copy the Windows skill
Copy-Item -Recurse "C:\Azure-As-Built\azure-asbuilt-generator\windows" "$env:USERPROFILE\.claude\skills\azure-asbuilt-generator"
```

Claude Code automatically detects skills in `~/.claude/skills/` - no configuration required.

#### Step 3: Install Dependencies

```powershell
cd "$env:USERPROFILE\.claude\skills\azure-asbuilt-generator\scripts"
npm install docx
```

#### Step 4: Verify Installation

```powershell
# Test script help
Get-Help .\Collect-AzureConfig.ps1
```

---

### Claude Code (Linux/macOS)

#### Step 1: Clone Repository

```bash
# Clone to your preferred location
git clone https://github.com/kroegha/azure-asbuilt-generator.git ~/azure-asbuilt-generator
```

#### Step 2: Copy Skill to Skills Folder

```bash
# Create skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Copy the Linux skill
cp -r ~/azure-asbuilt-generator/linux ~/.claude/skills/azure-asbuilt-generator
```

Claude Code automatically detects skills in `~/.claude/skills/` - no configuration required.

#### Step 3: Install Dependencies

```bash
cd ~/.claude/skills/azure-asbuilt-generator/scripts
npm install docx
chmod +x collect_azure_config.sh
```

#### Step 4: Verify Installation

```bash
# Check prerequisites
which az jq node

# Test script
./collect_azure_config.sh --help
```

---

### Claude Desktop

Claude Desktop uses MCP (Model Context Protocol) servers. To add this skill:

#### Step 1: Locate Config File

| OS | Config Location |
|----|----------------|
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Linux | `~/.config/Claude/claude_desktop_config.json` |

#### Step 2: Add Skill Configuration

Edit the config file and add:

```json
{
  "mcpServers": {
    "azure-asbuilt": {
      "command": "node",
      "args": [
        "/path/to/azure-asbuilt-generator/mcp-server.js"
      ],
      "env": {
        "AZURE_SUBSCRIPTION_ID": "your-subscription-id"
      }
    }
  }
}
```

> **Note**: MCP server implementation (`mcp-server.js`) is planned for future release. Currently, use Claude Code or manual execution.

#### Step 3: Alternative - Manual Skill Reference

Without MCP, you can reference the skill in Claude Desktop by:

1. Uploading `SKILL.md` to your conversation
2. Claude will read the skill definition and follow the instructions
3. Use Claude's computer use feature to execute scripts

---

## Usage

### Quick Start (Windows)

```powershell
# 1. Login to Azure
az login
az account set --subscription "Your Subscription"

# 2. Navigate to skill
cd "$env:USERPROFILE\.claude\skills\azure-asbuilt-generator"

# 3. Collect configuration
.\scripts\Collect-AzureConfig.ps1 `
    -ApimName "apim-company-prod" `
    -ResourceGroup "rg-integration-prod" `
    -ApiName "my-api" `
    -UseAzureCLI

# 4. Generate document
.\scripts\Generate-AsBuiltDoc.ps1 `
    -ConfigFile ".\output\config_my-api_*.json" `
    -OutputFile ".\output\AsBuilt_MyAPI.docx"
```

### Quick Start (Linux/macOS)

```bash
# 1. Login to Azure
az login
az account set --subscription "Your Subscription"

# 2. Navigate to skill
cd ~/.claude/skills/azure-asbuilt-generator

# 3. Collect configuration
./scripts/collect_azure_config.sh \
    "apim-company-prod" \
    "rg-integration-prod" \
    "my-api"

# 4. Generate document
node scripts/generate_asbuilt_doc.js \
    output/config_my-api_*.json \
    output/AsBuilt_MyAPI.docx
```

### With Claude (Conversational)

When using with Claude Code or Claude Desktop:

```
User: Create as-built documentation for the FNB Bank Statements API 
      in apim-sanparks-prod, resource group rg-integration-prod

Claude: I'll collect the Azure configuration and generate the documentation.

[Claude executes Collect-AzureConfig.ps1]
[Claude executes Generate-AsBuiltDoc.ps1]

Here's your As-Built documentation for the FNB Bank Statements API.
The document includes:
- Executive summary and service overview
- Architecture diagram and data flow
- APIM configuration with 2 API operations
- Logic App workflow with 5 actions
- SQL Server connection via Data Gateway
- Key Vault secrets inventory
- Application Insights monitoring setup
```

### Adding Architecture Diagram

```powershell
# Generate with diagram
.\scripts\Generate-AsBuiltDoc.ps1 `
    -ConfigFile ".\output\config_my-api.json" `
    -OutputFile ".\output\AsBuilt_MyAPI.docx" `
    -DiagramFile ".\diagrams\architecture.png"
```

---

## Script Reference

### Collect-AzureConfig.ps1 (Windows)

PowerShell script for collecting Azure configuration.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|------------|
| `-ApimName` | String | Yes | API Management instance name |
| `-ResourceGroup` | String | Yes | Resource group containing APIM |
| `-ApiName` | String | Yes | Specific API to document |
| `-OutputPath` | String | No | Output directory (default: `.\output`) |
| `-UseAzureCLI` | Switch | No | Use Azure CLI instead of Az module |

#### Examples

```powershell
# Basic usage with Az module
.\Collect-AzureConfig.ps1 -ApimName "apim-prod" -ResourceGroup "rg-prod" -ApiName "customer-api"

# Using Azure CLI
.\Collect-AzureConfig.ps1 -ApimName "apim-prod" -ResourceGroup "rg-prod" -ApiName "customer-api" -UseAzureCLI

# Custom output path
.\Collect-AzureConfig.ps1 -ApimName "apim-prod" -ResourceGroup "rg-prod" -ApiName "customer-api" -OutputPath "C:\Docs"
```

#### What It Collects

1. **APIM Instance**: `az apim show`
2. **API Definition**: `az apim api show`
3. **API Operations**: `az apim api operation list`
4. **Logic App**: Detected from backend URL, `az webapp show`
5. **Workflow Definition**: REST API call to Logic App runtime
6. **API Connections**: `az resource list --resource-type Microsoft.Web/connections`
7. **Data Gateway**: `az resource list --resource-type Microsoft.Web/connectionGateways`
8. **Key Vault**: `az keyvault show` + `az keyvault secret list`
9. **App Insights**: `az monitor app-insights component show`

---

### collect_azure_config.sh (Linux)

Bash script for collecting Azure configuration.

#### Usage

```bash
./collect_azure_config.sh <apim-name> <resource-group> <api-name> [output-dir]
```

#### Arguments

| Position | Name | Required | Description |
|----------|------|----------|------------|
| 1 | apim-name | Yes | API Management instance name |
| 2 | resource-group | Yes | Resource group containing APIM |
| 3 | api-name | Yes | Specific API to document |
| 4 | output-dir | No | Output directory (default: `./output`) |

#### Example

```bash
./collect_azure_config.sh apim-prod rg-prod customer-api ./docs
```

---

### generate_asbuilt_doc.js (Cross-Platform)

Node.js script for generating Word documents from collected JSON.

#### Usage

```bash
node generate_asbuilt_doc.js <config.json> <output.docx> [--diagram <image.png>]
```

#### Arguments

| Argument | Required | Description |
|----------|----------|------------|
| config.json | Yes | Collected configuration JSON file |
| output.docx | Yes | Output Word document path |
| --diagram | No | Architecture diagram image (PNG) |

#### Example

```bash
node generate_asbuilt_doc.js config.json AsBuilt.docx --diagram architecture.png
```

#### Document Sections Generated

1. **Title Page**: Service name, environment, metadata
2. **Table of Contents**: Auto-generated with hyperlinks
3. **Executive Summary**: Purpose, service overview table
4. **Architecture Overview**: Diagram (if provided), data flow steps
5. **Shared Infrastructure**: Front Door, WAF configuration
6. **API Management**: APIM instance, API definition, operations table
7. **Logic App Configuration**: Instance details, workflow actions table
8. **Data Connectivity**: API connections, Data Gateway, firewall requirements
9. **Security Configuration**: Key Vault, secrets inventory
10. **Monitoring**: Application Insights configuration

---

### azure_config_collector.py (Linux)

Python module for parsing Logic App workflow definitions.

#### Classes

**WorkflowParser**
- `parse_workflow(definition)`: Parse workflow JSON into structured documentation
- `generate_markdown(parsed, name)`: Generate markdown documentation

**ConfigurationAggregator**
- `add_apim_config(data)`: Add APIM configuration
- `add_logic_app_config(data)`: Add Logic App configuration
- `add_workflow_config(definition, name)`: Add and parse workflow
- `export_json(filepath)`: Export to JSON file

#### Usage

```python
from azure_config_collector import WorkflowParser, ConfigurationAggregator

# Parse a workflow
parser = WorkflowParser()
parsed = parser.parse_workflow(workflow_definition)
print(parser.generate_markdown(parsed, "My Workflow"))

# Aggregate configuration
aggregator = ConfigurationAggregator()
aggregator.set_metadata("Service Name", "Production", "subscription")
aggregator.add_apim_config(apim_data)
aggregator.add_workflow_config(workflow_def, "workflow-name")
aggregator.export_json("config.json")
```

---

## Configuration Files

### shared_infrastructure.json

Template for shared Front Door and WAF configuration. Update this once for your organization:

```json
{
  "front_door": {
    "resource_name": "fd-company-prod-001",
    "resource_group": "rg-networking-prod",
    "sku": "Standard_AzureFrontDoor",
    "endpoint_hostname": "api.company.com",
    "custom_domains": ["api.client1.com", "api.client2.com"],
    "ssl_certificate": "Azure Managed"
  },
  "waf": {
    "policy_name": "waf-company-prod-001",
    "resource_group": "rg-networking-prod",
    "mode": "Prevention",
    "rule_set": "Microsoft_DefaultRuleSet 2.1",
    "bot_protection": true
  }
}
```

### Output JSON Schema

The collected configuration follows this structure:

```json
{
  "metadata": {
    "collection_date": "2025-01-09T12:00:00Z",
    "service_name": "API Name",
    "subscription": "Subscription Name",
    "environment": "Production"
  },
  "shared_infrastructure": {
    "front_door": { },
    "waf": { }
  },
  "service": {
    "apim": { },
    "api": { },
    "logic_app": { },
    "workflow": {
      "name": "workflow-name",
      "parsed": {
        "triggers": [ ],
        "actions": [ ],
        "connections": [ ],
        "data_sources": [ ]
      }
    },
    "connections": [ ],
    "data_gateway": { },
    "key_vault": { },
    "app_insights": { }
  }
}
```

---

## Output Examples

### Sample Generated Document

The tool generates professional Word documents with:

![Document Preview](examples/doc_preview.png)

**Included Sections:**
- Cover page with document metadata
- Auto-generated table of contents
- Formatted tables with alternating row colors
- Workflow actions in execution order
- Secrets inventory (names only, no values)
- Confidential header/footer

### Sample Workflow Documentation

| Step | Action | Type | Description |
|------|--------|------|------------|
| 1 | Parse_Request | ParseJson | Parse JSON content |
| 2 | Get_Account_Details | ApiConnection | Execute SQL stored procedure: sp_GetAccountDetails |
| 3 | Query_Statements | ApiConnection | Execute SQL stored procedure: sp_GetBankStatements |
| 4 | Transform_Response | Compose | Transform/compose data |
| 5 | Response | Response | Return HTTP 200 response |

---

## Troubleshooting

### Common Issues

#### "Not connected to Azure"

```powershell
# Windows - Azure CLI
az login
az account set --subscription "Your Subscription"

# Windows - Az Module
Connect-AzAccount
Set-AzContext -Subscription "Your Subscription"

# Linux
az login
```

#### "API not found in APIM"

List available APIs first:

```bash
az apim api list --service-name "apim-name" --resource-group "rg-name" \
    --query "[].{name:name, path:path}" -o table
```

#### "Access denied to workflow definition"

Logic App Standard workflows require additional permissions:

```bash
# Assign Website Contributor role
az role assignment create \
    --assignee your-user@domain.com \
    --role "Website Contributor" \
    --scope /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{logic-app}
```

#### "docx module not found"

```bash
cd scripts
npm install docx
```

#### "jq: command not found" (Linux)

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# RHEL/CentOS
sudo yum install jq
```

### Debug Mode

Enable verbose output:

```powershell
# Windows
$VerbosePreference = "Continue"
.\Collect-AzureConfig.ps1 -ApimName "..." -ResourceGroup "..." -ApiName "..." -Verbose

# Linux
bash -x ./collect_azure_config.sh apim-name rg-name api-name
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone repo
git clone https://github.com/kroegha/azure-asbuilt-generator.git
cd azure-asbuilt-generator

# Install dependencies
cd windows/scripts && npm install
cd ../../linux/scripts && npm install

# Run tests
npm test
```

### Roadmap

- [ ] MCP server for Claude Desktop integration
- [ ] Support for Logic App Consumption
- [ ] Azure Functions documentation
- [ ] Container Apps documentation
- [ ] Bicep/Terraform output
- [ ] PDF export option
- [ ] Multi-language support

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Anthropic](https://anthropic.com) for Claude and Claude Code
- [docx](https://github.com/dolanmiu/docx) for Word document generation
- [Azure CLI](https://docs.microsoft.com/cli/azure/) for Azure resource access

---

## Support

- **Issues**: [GitHub Issues](https://github.com/kroegha/azure-asbuilt-generator/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kroegha/azure-asbuilt-generator/discussions)
- **Author**: Bios Data Center

---

*Built with ❤️ for Azure architects and integration specialists*
