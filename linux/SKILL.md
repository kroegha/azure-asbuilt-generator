---
name: azure-asbuilt-generator
description: |
  Automatically collect Azure API service configuration and generate professional As-Built documentation.
  Use when asked to create as-built documentation for Azure APIM services, Logic Apps integrations,
  or any Azure API service following the Front Door → WAF → APIM → Logic Apps → Data Gateway → SQL pattern.
  
  This skill uses Azure MCP tools to collect configuration and generates Word documents.
---

# Azure As-Built Documentation Generator

## Overview

This skill automates the collection of Azure service configuration and generation of professional As-Built documentation for API integration services. It supports the standard Bios Data Center architecture pattern:

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

1. **Azure MCP Tools** must be available (Docker MCP Gateway)
2. **Node.js** with `docx` package installed
3. **Python 3** for configuration parsing
4. Appropriate Azure permissions (Reader on relevant resources)

## Directory Structure

```
/home/claude/azure-asbuilt-automation/
├── SKILL.md                         # This file
├── scripts/
│   ├── azure_config_collector.py    # Configuration parsing utilities
│   ├── generate_asbuilt_doc.js      # Word document generator
│   └── Collect-AzureApiServiceConfig.ps1  # PowerShell collector (alternative)
├── templates/
│   └── (generated templates)
├── output/
│   └── (generated documents)
└── references/
    └── shared_infrastructure.json   # Shared Front Door/WAF config
```

## Collection Workflow

### Step 1: Identify Service Components

Gather from user:
- **APIM Instance Name** (e.g., `apim-bios-prod-001`)
- **APIM Resource Group** (e.g., `rg-integration-prod`)
- **API Name** (e.g., `fnb-bank-statements-api`)
- **Logic App Name** (if known, otherwise extract from API backend URL)
- **Workflow Name** (for Logic App Standard)

### Step 2: Collect Configuration Using Azure MCP

Execute the following MCP tool calls in sequence:

#### 2.1 Learn Available APIM Commands
```json
{
  "tool": "MCP_DOCKER:apim",
  "parameters": { "learn": true, "intent": "Learn available APIM commands" }
}
```

#### 2.2 Get APIM Instance Details
```json
{
  "tool": "MCP_DOCKER:apim",
  "parameters": {
    "intent": "Get API Management instance details",
    "command": "apim_show",
    "parameters": {
      "name": "<APIM_NAME>",
      "resource-group": "<RESOURCE_GROUP>"
    }
  }
}
```

#### 2.3 List APIs in APIM
```json
{
  "tool": "MCP_DOCKER:apim",
  "parameters": {
    "intent": "List APIs in APIM instance",
    "command": "api_list",
    "parameters": {
      "service-name": "<APIM_NAME>",
      "resource-group": "<RESOURCE_GROUP>"
    }
  }
}
```

#### 2.4 Get Specific API Configuration
```json
{
  "tool": "MCP_DOCKER:apim",
  "parameters": {
    "intent": "Get API details including backend URL",
    "command": "api_show",
    "parameters": {
      "api-id": "<API_NAME>",
      "service-name": "<APIM_NAME>",
      "resource-group": "<RESOURCE_GROUP>"
    }
  }
}
```

#### 2.5 Get Logic App / App Service Configuration
```json
{
  "tool": "MCP_DOCKER:appservice",
  "parameters": {
    "learn": true,
    "intent": "Learn App Service commands for Logic App Standard"
  }
}
```

#### 2.6 Get Workflow Definition (Logic App Standard)

For Logic App Standard workflows, use Azure CLI or REST API:
```bash
# Using Azure CLI extension
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Web/sites/{logicAppName}/hostruntime/runtime/webhooks/workflow/api/management/workflows/{workflowName}?api-version=2022-03-01"
```

#### 2.7 Get Key Vault Secrets List
```json
{
  "tool": "MCP_DOCKER:keyvault",
  "parameters": {
    "intent": "List secrets in Key Vault (names only, not values)",
    "command": "secret_list",
    "parameters": {
      "vault-name": "<KEYVAULT_NAME>"
    }
  }
}
```

#### 2.8 Get Application Insights
```json
{
  "tool": "MCP_DOCKER:applicationinsights",
  "parameters": {
    "learn": true,
    "intent": "Get Application Insights component configuration"
  }
}
```

### Step 3: Parse Workflow Definition

Use the Python WorkflowParser to extract documentation:

```python
import sys
sys.path.append('/home/claude/azure-asbuilt-automation/scripts')
from azure_config_collector import WorkflowParser, ConfigurationAggregator

# Parse the workflow definition JSON
parsed = WorkflowParser.parse_workflow(workflow_definition)

# Generate markdown documentation
markdown = WorkflowParser.generate_markdown(parsed, "Workflow Name")
print(markdown)
```

The parser extracts:
- Trigger configuration (HTTP, Schedule, etc.)
- Actions in execution order
- Connection references (SQL, SharePoint, etc.)
- Data sources used

### Step 4: Aggregate Configuration

```python
from azure_config_collector import ConfigurationAggregator

aggregator = ConfigurationAggregator()

# Set metadata
aggregator.set_metadata(
    service_name="FNB Bank Statements API",
    environment="Production",
    subscription="subscription-name"
)

# Add shared infrastructure (from references/shared_infrastructure.json)
aggregator.set_shared_infrastructure(
    front_door=shared_infra["front_door"],
    waf=shared_infra["waf"]
)

# Add collected service configuration
aggregator.add_apim_config(apim_data)
aggregator.add_api_config(api_data)
aggregator.add_logic_app_config(logic_app_data)
aggregator.add_workflow_config(workflow_definition, "workflow-name")
aggregator.add_connection_config(connections_data)
aggregator.add_data_gateway_config(gateway_data)
aggregator.add_keyvault_config(keyvault_data, secrets_list)
aggregator.add_app_insights_config(app_insights_data)

# Export to JSON
aggregator.export_json("/home/claude/azure-asbuilt-automation/output/config.json")
```

### Step 5: Generate Architecture Diagram

Use the `infrastructure-diagrams` skill:

```python
from diagrams import Diagram, Cluster, Edge
from diagrams.azure.network import FrontDoors
from diagrams.azure.integration import APIManagement, LogicApps
from diagrams.azure.security import KeyVaults
from diagrams.onprem.database import MSSQL
from diagrams.onprem.compute import Server

with Diagram("Service Architecture", show=False, 
             filename="/home/claude/azure-asbuilt-automation/output/architecture",
             direction="LR"):
    # Create diagram nodes and edges
    # ... see infrastructure-diagrams skill for full example
```

### Step 6: Generate Word Document

```bash
cd /home/claude/azure-asbuilt-automation/scripts
npm install docx  # If not installed

node generate_asbuilt_doc.js \
  ../output/config.json \
  ../output/AsBuilt_ServiceName.docx \
  --diagram ../output/architecture.png
```

### Step 7: Present Output Files

Copy to outputs and present:
```bash
cp /home/claude/azure-asbuilt-automation/output/*.docx /mnt/user-data/outputs/
cp /home/claude/azure-asbuilt-automation/output/*.png /mnt/user-data/outputs/
```

## Shared Infrastructure Configuration

For Bios Data Center, the following infrastructure is typically **shared** across services and stays relatively static:

### Front Door
- Shared instance for all API services
- Custom domains added per service
- Update: `references/shared_infrastructure.json`

### WAF Policy
- Shared policy with common rule set
- **Per-Service Customization**: IP whitelist rules
- Custom rules added for specific client IPs

Create `references/shared_infrastructure.json`:
```json
{
  "front_door": {
    "resource_name": "fd-bios-prod-001",
    "resource_group": "rg-networking-prod",
    "sku": "Standard_AzureFrontDoor",
    "endpoint": "bios-api.azurefd.net",
    "ssl_certificate": "Azure Managed",
    "notes": "Add custom domain per service"
  },
  "waf": {
    "policy_name": "waf-bios-prod-001",
    "resource_group": "rg-networking-prod",
    "mode": "Prevention",
    "rule_set": "Microsoft_DefaultRuleSet 2.1",
    "bot_protection": true,
    "notes": "Add IP whitelist custom rules per service"
  }
}
```

## Document Sections Generated

| Section | Content |
|---------|---------|
| Executive Summary | Service overview, purpose, metadata |
| Architecture | Diagram, data flow description |
| Shared Infrastructure | Front Door, WAF (static config) |
| API Management | APIM instance, API definition, operations |
| Logic App | Instance config, workflow actions table |
| Data Connectivity | API connections, Data Gateway, SQL |
| Security | Key Vault, secrets inventory |
| Monitoring | Application Insights configuration |

## Error Handling

### MCP Tool Not Available
```json
{
  "tool": "MCP_DOCKER:mcp-find",
  "parameters": { "query": "azure apim" }
}
```
Then add with `MCP_DOCKER:mcp-add`.

### Permission Issues
- Requires Reader role on resources
- Logic App workflow access may need Contributor

### Workflow Definition Access (Logic App Standard)
Use REST API directly if MCP doesn't support:
```bash
az account get-access-token --query accessToken -o tsv
# Then use curl with Bearer token
```

## Example Conversation

**User**: Create as-built documentation for the FNB Bank Statements API

**Claude**:
1. Asks: What's the APIM instance name and resource group?
2. Uses MCP tools to collect APIM, API, Logic App configs
3. Parses workflow to document all actions
4. Generates architecture diagram
5. Creates Word document
6. Presents files to user

## Related Skills

- `/mnt/skills/user/infrastructure-diagrams/SKILL.md` - Architecture diagrams
- `/mnt/skills/public/docx/SKILL.md` - Word document manipulation
- `/mnt/skills/user/logic-apps-qos-reporter/SKILL.md` - Logic Apps monitoring

## Files Reference

| File | Purpose |
|------|---------|
| `scripts/azure_config_collector.py` | Parse workflows, aggregate config |
| `scripts/generate_asbuilt_doc.js` | Generate Word document |
| `scripts/Collect-AzureApiServiceConfig.ps1` | PowerShell alternative |
| `references/shared_infrastructure.json` | Static Front Door/WAF config |
| `output/` | Generated documents |
