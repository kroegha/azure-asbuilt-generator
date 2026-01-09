# Azure As-Built Generator - Claude Desktop Version

This version is designed for use with **Claude Desktop** (claude.ai web interface or desktop app).

## Overview

Unlike Claude Code which has direct file system access, Claude Desktop requires a different approach:

1. **Upload the SKILL.md** to your conversation or project
2. **Execute scripts manually** in your terminal
3. **Upload results** back to Claude for document generation

## Installation Options

### Option 1: Project Knowledge (Recommended)

1. Create a new **Project** in Claude Desktop
2. Go to **Project Knowledge**
3. Upload `SKILL.md` from this directory
4. The skill will be available in all project conversations

### Option 2: Per-Conversation Upload

1. Start a new conversation
2. Upload `SKILL.md` using the attachment button
3. Ask Claude to follow the skill instructions

### Option 3: Reference Skill File Path

If you have Claude Desktop with MCP filesystem access:

1. Edit your Claude Desktop config (see `claude_desktop_config.example.json`)
2. Add the filesystem MCP server with this directory in allowed paths
3. Claude can then read files directly

## Usage Workflow

### Step 1: Collect Azure Configuration

Open PowerShell/Terminal and run:

```powershell
# Windows
cd "C:\Azure-As-Built\azure-asbuilt-generator\claude-desktop"
.\scripts\Collect-AzureConfig.ps1 `
    -ApimName "your-apim-name" `
    -ResourceGroup "your-resource-group" `
    -ApiName "your-api-name" `
    -UseAzureCLI
```

```bash
# Linux/macOS
cd ~/azure-asbuilt-generator/claude-desktop
./scripts/collect_azure_config.sh \
    "your-apim-name" \
    "your-resource-group" \
    "your-api-name"
```

### Step 2: Upload Configuration to Claude

1. Find the generated JSON file in `output/config_*.json`
2. Upload it to your Claude Desktop conversation
3. Ask Claude to generate the As-Built document

### Step 3: Get Generated Document

Claude will use the configuration to create a professional Word document.

## Files in This Directory

| File | Purpose |
|------|---------|  
| `SKILL.md` | Skill definition for Claude |
| `claude_desktop_config.example.json` | Example MCP config |
| `scripts/Collect-AzureConfig.ps1` | PowerShell collector |
| `scripts/collect_azure_config.sh` | Bash collector |
| `scripts/azure_config_collector.py` | Python parser |
| `scripts/generate_asbuilt_doc.js` | Node.js document generator |
| `references/shared_infrastructure.json` | Shared config template |

## Prerequisites

### For Script Execution

- **Azure CLI** (`az login`)
- **Node.js** 18+ (for document generation)
- **PowerShell 5.1+** (Windows) or **Bash** (Linux/macOS)

### For Claude Desktop

- Claude Desktop app or claude.ai web access
- Project feature (for Project Knowledge option)

## Example Conversation

```
User: [Uploads SKILL.md]
       I need to create as-built documentation for our FNB API.
       The APIM is "apim-sanparks-prod" in resource group "rg-integration-prod".

Claude: I'll help you create the as-built documentation. 
        First, please run this command to collect the Azure configuration:
        
        .\scripts\Collect-AzureConfig.ps1 -ApimName "apim-sanparks-prod" ...
        
        Then upload the generated JSON file.

User: [Uploads config_fnb-api_20250109.json]

Claude: I've analyzed the configuration. Here's your As-Built document:
        [Generates and provides Word document]
```

## Differences from Claude Code Version

| Feature | Claude Code | Claude Desktop |
|---------|-------------|----------------|
| File System Access | Direct | Via upload/download |
| Script Execution | Automatic | Manual in terminal |
| Workflow | Fully automated | Semi-automated |
| Best For | Frequent use | Occasional use |

## Troubleshooting

### "Script not found"

Make sure you're in the correct directory:
```powershell
cd "C:\Azure-As-Built\azure-asbuilt-generator\claude-desktop"
dir scripts
```

### "Not logged into Azure"

```powershell
az login
az account set --subscription "Your Subscription"
```

### "Node modules not found"

```powershell
cd scripts
npm install docx
```

## Support

For issues or questions, see the main [README.md](../README.md) in the repository root.
