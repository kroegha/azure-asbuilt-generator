<#
.SYNOPSIS
    Collects Azure API Service configuration for As-Built documentation.
    Windows/PowerShell compatible for use with Claude Code.

.DESCRIPTION
    Collects configuration from Azure APIM, Logic Apps, Data Gateway,
    Key Vault, App Insights and outputs JSON for document generation.

.PARAMETER ApimName
    The name of the Azure API Management instance.

.PARAMETER ResourceGroup
    The resource group containing the APIM instance.

.PARAMETER ApiName
    The name of the specific API to document.

.PARAMETER OutputPath
    Path where the JSON configuration will be saved.

.EXAMPLE
    .\Collect-AzureConfig.ps1 -ApimName "apim-sanparks-prod" -ResourceGroup "rg-integration-prod" -ApiName "fnb-bank-statements"

.NOTES
    Author: Bios Data Center
    Version: 2.0
    Requires: Az PowerShell module OR Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApimName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ApiName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output",

    [Parameter(Mandatory = $false)]
    [switch]$UseAzureCLI
)

$ErrorActionPreference = "Continue"

#region Helper Functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureConnection {
    if ($UseAzureCLI) {
        try {
            $null = az account show 2>&1
            return $true
        } catch {
            return $false
        }
    } else {
        try {
            $null = Get-AzContext -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }
}

function Get-SubscriptionInfo {
    if ($UseAzureCLI) {
        $sub = az account show --query "{id:id, name:name, tenantId:tenantId}" -o json | ConvertFrom-Json
        return @{
            Id = $sub.id
            Name = $sub.name
            TenantId = $sub.tenantId
        }
    } else {
        $ctx = Get-AzContext
        return @{
            Id = $ctx.Subscription.Id
            Name = $ctx.Subscription.Name
            TenantId = $ctx.Tenant.Id
        }
    }
}
#endregion

#region Collection Functions (Azure CLI)
function Get-ApimConfigCLI {
    param([string]$Name, [string]$RG)
    
    Write-Log "Collecting APIM configuration (CLI)..."
    try {
        $apim = az apim show --name $Name --resource-group $RG -o json 2>$null | ConvertFrom-Json
        if ($apim) {
            return @{
                resource_name = $apim.name
                resource_group = $apim.resourceGroup
                resource_id = $apim.id
                region = $apim.location
                sku = $apim.sku.name
                capacity = $apim.sku.capacity
                gateway_url = $apim.gatewayUrl
                developer_portal_url = $apim.developerPortalUrl
                virtual_network_type = $apim.virtualNetworkType
                identity = @{
                    type = $apim.identity.type
                    principal_id = $apim.identity.principalId
                }
            }
        }
    } catch {
        Write-Log "Failed to get APIM config: $_" -Level "ERROR"
    }
    return $null
}

function Get-ApiConfigCLI {
    param([string]$ApiId, [string]$ServiceName, [string]$RG)
    
    Write-Log "Collecting API configuration (CLI)..."
    try {
        $api = az apim api show --api-id $ApiId --service-name $ServiceName --resource-group $RG -o json 2>$null | ConvertFrom-Json
        $operations = az apim api operation list --api-id $ApiId --service-name $ServiceName --resource-group $RG -o json 2>$null | ConvertFrom-Json
        
        if ($api) {
            return @{
                name = $api.name
                display_name = $api.displayName
                description = $api.description
                path = $api.path
                service_url = $api.serviceUrl
                protocols = $api.protocols
                subscription_required = $api.subscriptionRequired
                api_version = $api.apiVersion
                operations = @($operations | ForEach-Object {
                    @{
                        name = $_.name
                        display_name = $_.displayName
                        method = $_.method
                        url_template = $_.urlTemplate
                    }
                })
            }
        }
    } catch {
        Write-Log "Failed to get API config: $_" -Level "ERROR"
    }
    return $null
}

function Get-LogicAppConfigCLI {
    param([string]$Name, [string]$RG)
    
    Write-Log "Collecting Logic App configuration (CLI)..."
    try {
        $la = az webapp show --name $Name --resource-group $RG -o json 2>$null | ConvertFrom-Json
        if ($la) {
            return @{
                resource_name = $la.name
                resource_group = $la.resourceGroup
                resource_id = $la.id
                type = "Standard"
                region = $la.location
                state = $la.state
                default_hostname = $la.defaultHostName
                identity = @{
                    type = $la.identity.type
                    principal_id = $la.identity.principalId
                    tenant_id = $la.identity.tenantId
                }
            }
        }
    } catch {
        Write-Log "Failed to get Logic App config: $_" -Level "ERROR"
    }
    return $null
}

function Get-WorkflowDefinitionCLI {
    param([string]$LogicAppName, [string]$RG, [string]$WorkflowName, [string]$SubscriptionId)
    
    Write-Log "Collecting workflow definition (CLI)..."
    try {
        $token = az account get-access-token --query accessToken -o tsv
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$RG/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/$WorkflowName`?api-version=2022-03-01"
        
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        
        # Parse workflow to extract actions
        $definition = $response.properties.definition
        $triggers = @()
        $actions = @()
        $connections = @()
        $dataSources = @()
        
        # Extract triggers
        if ($definition.triggers) {
            foreach ($triggerName in $definition.triggers.PSObject.Properties.Name) {
                $trigger = $definition.triggers.$triggerName
                $triggers += @{
                    name = $triggerName
                    type = $trigger.type
                    kind = $trigger.kind
                    description = Get-TriggerDescription -Trigger $trigger
                }
            }
        }
        
        # Extract actions
        if ($definition.actions) {
            $actionOrder = Get-ActionOrder -Actions $definition.actions
            foreach ($actionName in $actionOrder) {
                $action = $definition.actions.$actionName
                $actions += @{
                    name = $actionName
                    type = $action.type
                    description = Get-ActionDescription -Action $action
                    run_after = @($action.runAfter.PSObject.Properties.Name)
                }
                
                # Extract connections
                if ($action.inputs.host.connection.referenceName) {
                    $connRef = $action.inputs.host.connection.referenceName
                    if ($connRef -notin $connections) {
                        $connections += $connRef
                    }
                }
                
                # Identify data sources
                $apiId = $action.inputs.host.apiId
                if ($apiId -and $apiId -match "sql") {
                    $dataSources += @{
                        type = "SQL Server"
                        action = $actionName
                        operation = if ($action.inputs.path) { ($action.inputs.path -split "/")[-1] } else { "query" }
                    }
                }
            }
        }
        
        return @{
            name = $WorkflowName
            state = $response.properties.state
            triggers = $triggers
            actions = $actions
            connections = $connections
            data_sources = $dataSources
            parsed = @{
                triggers = $triggers
                actions = $actions
                connections = $connections
                data_sources = $dataSources
            }
        }
    } catch {
        Write-Log "Failed to get workflow definition: $_" -Level "ERROR"
    }
    return $null
}

function Get-TriggerDescription {
    param($Trigger)
    
    switch ($Trigger.type) {
        "Request" { return "HTTP Request trigger - receives incoming API calls" }
        "Recurrence" { 
            $freq = $Trigger.recurrence.frequency
            $interval = $Trigger.recurrence.interval
            return "Scheduled trigger - runs every $interval $freq"
        }
        "ApiConnection" { return "API Connection trigger" }
        "ApiConnectionWebhook" { return "Webhook trigger" }
        default { return "$($Trigger.type) trigger" }
    }
}

function Get-ActionDescription {
    param($Action)
    
    $type = $Action.type
    $inputs = $Action.inputs
    
    switch ($type) {
        "Response" { return "Return HTTP $($inputs.statusCode) response" }
        "Compose" { return "Transform/compose data" }
        "ParseJson" { return "Parse JSON content" }
        "Condition" { return "Conditional branch (If/Then/Else)" }
        "ForEach" { return "Loop through collection" }
        "Switch" { return "Switch/case evaluation" }
        "Scope" { return "Grouped actions scope" }
        "InitializeVariable" { return "Initialize variable" }
        "SetVariable" { return "Set variable value" }
        "Http" { return "HTTP $($inputs.method) call" }
        "ApiConnection" {
            $apiId = $inputs.host.apiId
            $path = $inputs.path
            if ($apiId -match "sql") {
                if ($path -match "executestoredprocedure") {
                    $proc = ($path -split "/")[-1]
                    return "Execute SQL stored procedure: $proc"
                }
                return "SQL Server operation"
            }
            return "API Connection call"
        }
        default { return "$type action" }
    }
}

function Get-ActionOrder {
    param($Actions)
    
    $ordered = @()
    $remaining = @($Actions.PSObject.Properties.Name)
    $maxIterations = $remaining.Count * 2
    $iteration = 0
    
    while ($remaining.Count -gt 0 -and $iteration -lt $maxIterations) {
        $iteration++
        foreach ($name in $remaining) {
            $action = $Actions.$name
            $deps = @($action.runAfter.PSObject.Properties.Name)
            
            $allDepsOrdered = $true
            foreach ($dep in $deps) {
                if ($dep -notin $ordered) {
                    $allDepsOrdered = $false
                    break
                }
            }
            
            if ($allDepsOrdered) {
                $ordered += $name
                $remaining = $remaining | Where-Object { $_ -ne $name }
                break
            }
        }
    }
    
    # Add any remaining
    $ordered += $remaining
    return $ordered
}

function Get-ApiConnectionsCLI {
    param([string]$RG)
    
    Write-Log "Collecting API connections (CLI)..."
    try {
        $connections = az resource list --resource-group $RG --resource-type "Microsoft.Web/connections" -o json 2>$null | ConvertFrom-Json
        
        $result = @()
        foreach ($conn in $connections) {
            $detail = az resource show --ids $conn.id -o json 2>$null | ConvertFrom-Json
            
            $connInfo = @{
                name = $conn.name
                type = $detail.properties.api.name
                status = if ($detail.properties.statuses) { $detail.properties.statuses[0].status } else { "Unknown" }
            }
            
            # Check for gateway
            if ($detail.properties.parameterValues.gateway) {
                $connInfo.gateway = @{
                    id = $detail.properties.parameterValues.gateway.id
                    name = $detail.properties.parameterValues.gateway.name
                }
            }
            
            # Check for SQL connection
            if ($detail.properties.parameterValues.server) {
                $connInfo.sql_server = $detail.properties.parameterValues.server
                $connInfo.database = $detail.properties.parameterValues.database
            }
            
            $result += $connInfo
        }
        
        return $result
    } catch {
        Write-Log "Failed to get connections: $_" -Level "ERROR"
    }
    return @()
}

function Get-DataGatewayConfigCLI {
    param([string]$RG)
    
    Write-Log "Searching for Data Gateway (CLI)..."
    try {
        $gateways = az resource list --resource-group $RG --resource-type "Microsoft.Web/connectionGateways" -o json 2>$null | ConvertFrom-Json
        
        if ($gateways -and $gateways.Count -gt 0) {
            $gw = $gateways[0]
            $detail = az resource show --ids $gw.id -o json 2>$null | ConvertFrom-Json
            
            return @{
                name = $gw.name
                resource_group = $RG
                region = $gw.location
                type = $detail.properties.connectionGatewayInstallation.name
                machine_name = $detail.properties.connectionGatewayInstallation.machineName
            }
        }
    } catch {
        Write-Log "No Data Gateway found: $_" -Level "WARN"
    }
    return $null
}

function Get-KeyVaultConfigCLI {
    param([string]$RG)
    
    Write-Log "Searching for Key Vault (CLI)..."
    try {
        $vaults = az keyvault list --resource-group $RG -o json 2>$null | ConvertFrom-Json
        
        if ($vaults -and $vaults.Count -gt 0) {
            $kv = $vaults[0]
            Write-Log "Found Key Vault: $($kv.name)" -Level "SUCCESS"
            
            # Get secrets list
            $secrets = az keyvault secret list --vault-name $kv.name -o json 2>$null | ConvertFrom-Json
            
            return @{
                name = $kv.name
                resource_group = $RG
                region = $kv.location
                sku = $kv.properties.sku.name
                vault_uri = $kv.properties.vaultUri
                soft_delete_enabled = $kv.properties.enableSoftDelete
                purge_protection = $kv.properties.enablePurgeProtection
                secrets = @($secrets | ForEach-Object {
                    @{
                        name = $_.name
                        enabled = $_.attributes.enabled
                    }
                })
            }
        }
    } catch {
        Write-Log "No Key Vault found: $_" -Level "WARN"
    }
    return $null
}

function Get-AppInsightsConfigCLI {
    param([string]$RG)
    
    Write-Log "Searching for Application Insights (CLI)..."
    try {
        $ai = az monitor app-insights component list --resource-group $RG -o json 2>$null | ConvertFrom-Json
        
        if ($ai -and $ai.Count -gt 0) {
            $comp = $ai[0]
            Write-Log "Found App Insights: $($comp.name)" -Level "SUCCESS"
            
            return @{
                name = $comp.name
                resource_group = $RG
                region = $comp.location
                instrumentation_key = $comp.instrumentationKey
                connection_string = $comp.connectionString
                workspace_id = $comp.workspaceResourceId
                retention_days = $comp.retentionInDays
            }
        }
    } catch {
        Write-Log "No App Insights found: $_" -Level "WARN"
    }
    return $null
}
#endregion

#region Collection Functions (Az PowerShell Module)
function Get-ApimConfigPS {
    param([string]$Name, [string]$RG)
    
    Write-Log "Collecting APIM configuration (PowerShell)..."
    try {
        $apim = Get-AzApiManagement -ResourceGroupName $RG -Name $Name -ErrorAction Stop
        
        return @{
            resource_name = $apim.Name
            resource_group = $RG
            resource_id = $apim.Id
            region = $apim.Location
            sku = $apim.Sku.Name
            capacity = $apim.Sku.Capacity
            gateway_url = $apim.GatewayUrl
            developer_portal_url = $apim.DeveloperPortalUrl
            virtual_network_type = $apim.VirtualNetworkType
            identity = @{
                type = $apim.Identity.Type
                principal_id = $apim.Identity.PrincipalId
            }
        }
    } catch {
        Write-Log "Failed to get APIM config: $_" -Level "ERROR"
    }
    return $null
}

function Get-ApiConfigPS {
    param([string]$ApiId, [string]$ServiceName, [string]$RG)
    
    Write-Log "Collecting API configuration (PowerShell)..."
    try {
        $ctx = New-AzApiManagementContext -ResourceGroupName $RG -ServiceName $ServiceName
        $api = Get-AzApiManagementApi -Context $ctx -ApiId $ApiId -ErrorAction Stop
        $operations = Get-AzApiManagementOperation -Context $ctx -ApiId $ApiId
        
        return @{
            name = $api.ApiId
            display_name = $api.Name
            description = $api.Description
            path = $api.Path
            service_url = $api.ServiceUrl
            protocols = $api.Protocols
            subscription_required = $api.SubscriptionRequired
            api_version = $api.ApiVersion
            operations = @($operations | ForEach-Object {
                @{
                    name = $_.Name
                    display_name = $_.Name
                    method = $_.Method
                    url_template = $_.UrlTemplate
                }
            })
        }
    } catch {
        Write-Log "Failed to get API config: $_" -Level "ERROR"
    }
    return $null
}

function Get-LogicAppConfigPS {
    param([string]$Name, [string]$RG)
    
    Write-Log "Collecting Logic App configuration (PowerShell)..."
    try {
        $la = Get-AzWebApp -ResourceGroupName $RG -Name $Name -ErrorAction Stop
        
        return @{
            resource_name = $la.Name
            resource_group = $RG
            resource_id = $la.Id
            type = "Standard"
            region = $la.Location
            state = $la.State
            default_hostname = $la.DefaultHostName
            identity = @{
                type = $la.Identity.Type
                principal_id = $la.Identity.PrincipalId
                tenant_id = $la.Identity.TenantId
            }
        }
    } catch {
        Write-Log "Failed to get Logic App config: $_" -Level "ERROR"
    }
    return $null
}

function Get-KeyVaultConfigPS {
    param([string]$RG)
    
    Write-Log "Searching for Key Vault (PowerShell)..."
    try {
        $vaults = Get-AzKeyVault -ResourceGroupName $RG
        
        if ($vaults -and $vaults.Count -gt 0) {
            $kv = Get-AzKeyVault -VaultName $vaults[0].VaultName -ResourceGroupName $RG
            Write-Log "Found Key Vault: $($kv.VaultName)" -Level "SUCCESS"
            
            $secrets = Get-AzKeyVaultSecret -VaultName $kv.VaultName
            
            return @{
                name = $kv.VaultName
                resource_group = $RG
                region = $kv.Location
                sku = $kv.Sku
                vault_uri = $kv.VaultUri
                soft_delete_enabled = $kv.EnableSoftDelete
                purge_protection = $kv.EnablePurgeProtection
                secrets = @($secrets | ForEach-Object {
                    @{
                        name = $_.Name
                        enabled = $_.Enabled
                    }
                })
            }
        }
    } catch {
        Write-Log "No Key Vault found: $_" -Level "WARN"
    }
    return $null
}

function Get-AppInsightsConfigPS {
    param([string]$RG)
    
    Write-Log "Searching for Application Insights (PowerShell)..."
    try {
        $ai = Get-AzApplicationInsights -ResourceGroupName $RG -ErrorAction SilentlyContinue
        
        if ($ai -and $ai.Count -gt 0) {
            $comp = $ai[0]
            Write-Log "Found App Insights: $($comp.Name)" -Level "SUCCESS"
            
            return @{
                name = $comp.Name
                resource_group = $RG
                region = $comp.Location
                instrumentation_key = $comp.InstrumentationKey
                connection_string = $comp.ConnectionString
                workspace_id = $comp.WorkspaceResourceId
                retention_days = $comp.RetentionInDays
            }
        }
    } catch {
        Write-Log "No App Insights found: $_" -Level "WARN"
    }
    return $null
}
#endregion

#region Main Execution
Write-Log "=========================================="
Write-Log "Azure As-Built Configuration Collector"
Write-Log "=========================================="
Write-Log "APIM: $ApimName"
Write-Log "Resource Group: $ResourceGroup"
Write-Log "API: $ApiName"
Write-Log "Mode: $(if ($UseAzureCLI) { 'Azure CLI' } else { 'Az PowerShell' })"

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Check Azure connection
if (-not (Test-AzureConnection)) {
    Write-Log "Not connected to Azure. Please run 'az login' or 'Connect-AzAccount'" -Level "ERROR"
    exit 1
}

# Get subscription info
$subscription = Get-SubscriptionInfo
Write-Log "Subscription: $($subscription.Name) ($($subscription.Id))" -Level "SUCCESS"

# Initialize configuration
$config = @{
    metadata = @{
        collection_date = (Get-Date).ToString("o")
        version = "2.0"
        subscription = $subscription.Name
        subscription_id = $subscription.Id
        tenant_id = $subscription.TenantId
        service_name = $ApiName
        environment = "Production"
    }
    shared_infrastructure = @{
        front_door = @{
            resource_name = "[fd-bios-prod-001]"
            notes = "Update with actual Front Door configuration"
        }
        waf = @{
            policy_name = "[waf-bios-prod-001]"
            notes = "Update with actual WAF configuration"
        }
    }
    service = @{}
}

# Collect configuration based on mode
if ($UseAzureCLI) {
    # APIM
    $config.service.apim = Get-ApimConfigCLI -Name $ApimName -RG $ResourceGroup
    
    # API
    $config.service.api = Get-ApiConfigCLI -ApiId $ApiName -ServiceName $ApimName -RG $ResourceGroup
    
    # Logic App (from backend URL)
    if ($config.service.api.service_url -match "https://([^.]+)\.azurewebsites\.net") {
        $logicAppName = $Matches[1]
        Write-Log "Detected Logic App: $logicAppName" -Level "SUCCESS"
        
        # Find Logic App resource group
        $laRg = az webapp list --query "[?name=='$logicAppName'].resourceGroup" -o tsv 2>$null | Select-Object -First 1
        
        if ($laRg) {
            $config.service.logic_app = Get-LogicAppConfigCLI -Name $logicAppName -RG $laRg
            
            # Extract workflow name
            $workflowName = $null
            if ($config.service.api.service_url -match "/api/([^/]+)/") {
                $workflowName = $Matches[1]
            } elseif ($config.service.api.service_url -match "/workflows/([^/]+)/") {
                $workflowName = $Matches[1]
            }
            
            if ($workflowName) {
                $config.service.workflow = Get-WorkflowDefinitionCLI -LogicAppName $logicAppName -RG $laRg -WorkflowName $workflowName -SubscriptionId $subscription.Id
            }
            
            # Connections
            $config.service.connections = Get-ApiConnectionsCLI -RG $laRg
            
            # Data Gateway
            $config.service.data_gateway = Get-DataGatewayConfigCLI -RG $laRg
        }
    }
    
    # Key Vault
    $config.service.key_vault = Get-KeyVaultConfigCLI -RG $ResourceGroup
    
    # App Insights
    $config.service.app_insights = Get-AppInsightsConfigCLI -RG $ResourceGroup
    
} else {
    # Az PowerShell Module
    $config.service.apim = Get-ApimConfigPS -Name $ApimName -RG $ResourceGroup
    $config.service.api = Get-ApiConfigPS -ApiId $ApiName -ServiceName $ApimName -RG $ResourceGroup
    
    # Logic App
    if ($config.service.api.service_url -match "https://([^.]+)\.azurewebsites\.net") {
        $logicAppName = $Matches[1]
        $laResource = Get-AzResource -Name $logicAppName -ResourceType "Microsoft.Web/sites" -ErrorAction SilentlyContinue
        
        if ($laResource) {
            $laRg = $laResource.ResourceGroupName
            $config.service.logic_app = Get-LogicAppConfigPS -Name $logicAppName -RG $laRg
            
            # Workflow (use REST API - same as CLI)
            $workflowName = $null
            if ($config.service.api.service_url -match "/api/([^/]+)/") {
                $workflowName = $Matches[1]
            }
            
            if ($workflowName) {
                $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
                $config.service.workflow = Get-WorkflowDefinitionCLI -LogicAppName $logicAppName -RG $laRg -WorkflowName $workflowName -SubscriptionId $subscription.Id
            }
        }
    }
    
    $config.service.key_vault = Get-KeyVaultConfigPS -RG $ResourceGroup
    $config.service.app_insights = Get-AppInsightsConfigPS -RG $ResourceGroup
}

# Generate output filename
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $OutputPath "config_${ApiName}_${timestamp}.json"

# Export configuration
$config | ConvertTo-Json -Depth 20 | Out-File $outputFile -Encoding UTF8

Write-Log "=========================================="
Write-Log "Configuration saved to: $outputFile" -Level "SUCCESS"
Write-Log "=========================================="

# Print summary
Write-Host ""
Write-Host "Collection Summary:" -ForegroundColor Cyan
Write-Host "  APIM: $($config.service.apim.resource_name)"
Write-Host "  API: $($config.service.api.name)"
Write-Host "  Logic App: $($config.service.logic_app.resource_name)"
Write-Host "  Workflow: $($config.service.workflow.name)"
Write-Host "  Actions: $($config.service.workflow.actions.Count)"
Write-Host "  Connections: $($config.service.connections.Count)"
Write-Host "  Key Vault: $($config.service.key_vault.name)"
Write-Host "  App Insights: $($config.service.app_insights.name)"
Write-Host ""
Write-Host "Next step:" -ForegroundColor Yellow
Write-Host "  node .\generate_asbuilt_doc.js `"$outputFile`" `".\output\AsBuilt_$ApiName.docx`""

# Return config for pipeline use
return $config
#endregion
