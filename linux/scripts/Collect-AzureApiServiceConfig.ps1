<#
.SYNOPSIS
    Collects Azure API Service configuration for As-Built documentation.

.DESCRIPTION
    This script collects configuration from Azure APIM, Logic Apps, Data Gateway,
    and related resources to generate As-Built documentation.

.PARAMETER ApimName
    The name of the Azure API Management instance.

.PARAMETER ApimResourceGroup
    The resource group containing the APIM instance.

.PARAMETER ApiName
    The name of the specific API to document.

.PARAMETER OutputPath
    Path where the JSON configuration will be saved.

.EXAMPLE
    .\Collect-AzureApiServiceConfig.ps1 -ApimName "apim-bios-prod" -ApimResourceGroup "rg-integration-prod" -ApiName "fnb-bank-statements" -OutputPath ".\output"

.NOTES
    Author: Bios Data Center
    Version: 1.0
    Requires: Az PowerShell module, appropriate Azure permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApimName,

    [Parameter(Mandatory = $true)]
    [string]$ApimResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ApiName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeFrontDoor,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeWaf
)

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

function Get-AzureResourceId {
    param([string]$ResourceId)
    if ($ResourceId -match "/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/([^/]+)/([^/]+)/([^/]+)") {
        return @{
            SubscriptionId = $Matches[1]
            ResourceGroup = $Matches[2]
            Provider = $Matches[3]
            ResourceType = $Matches[4]
            ResourceName = $Matches[5]
        }
    }
    return $null
}

#endregion

#region Main Collection Functions

function Get-ApimConfiguration {
    param(
        [string]$ApimName,
        [string]$ResourceGroup
    )
    
    Write-Log "Collecting APIM configuration for: $ApimName"
    
    try {
        # Get APIM instance details
        $apim = Get-AzApiManagement -ResourceGroupName $ResourceGroup -Name $ApimName -ErrorAction Stop
        
        $config = @{
            ResourceName = $apim.Name
            ResourceGroup = $ResourceGroup
            ResourceId = $apim.Id
            Region = $apim.Location
            Sku = $apim.Sku.Name
            Capacity = $apim.Sku.Capacity
            GatewayUrl = $apim.GatewayUrl
            PortalUrl = $apim.PortalUrl
            DeveloperPortalUrl = $apim.DeveloperPortalUrl
            ManagementApiUrl = $apim.ManagementApiUrl
            PublicIpAddresses = $apim.PublicIpAddresses
            PrivateIpAddresses = $apim.PrivateIpAddresses
            VirtualNetworkType = $apim.VirtualNetworkType
            Identity = @{
                Type = $apim.Identity.Type
                PrincipalId = $apim.Identity.PrincipalId
                TenantId = $apim.Identity.TenantId
            }
            Tags = $apim.Tags
        }
        
        Write-Log "APIM configuration collected successfully" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect APIM configuration: $_" -Level "ERROR"
        return $null
    }
}

function Get-ApimApiConfiguration {
    param(
        [string]$ApimName,
        [string]$ResourceGroup,
        [string]$ApiName
    )
    
    Write-Log "Collecting API configuration for: $ApiName"
    
    try {
        # Get APIM context
        $apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroup -ServiceName $ApimName
        
        # Get API details
        $api = Get-AzApiManagementApi -Context $apimContext -ApiId $ApiName -ErrorAction Stop
        
        # Get API operations
        $operations = Get-AzApiManagementOperation -Context $apimContext -ApiId $ApiName
        
        # Get API policies
        $apiPolicy = $null
        try {
            $apiPolicy = Get-AzApiManagementPolicy -Context $apimContext -ApiId $ApiName -ErrorAction SilentlyContinue
        } catch { }
        
        # Get backend configuration
        $backends = Get-AzApiManagementBackend -Context $apimContext
        
        # Parse backend URL to identify Logic App
        $backendUrl = $api.ServiceUrl
        $logicAppInfo = $null
        
        if ($backendUrl -match "logic\.azure\.com" -or $backendUrl -match "azurewebsites\.net") {
            $logicAppInfo = @{
                Type = "LogicApp"
                Url = $backendUrl
            }
        }
        
        $config = @{
            ApiId = $api.ApiId
            Name = $api.Name
            DisplayName = $api.DisplayName
            Description = $api.Description
            Path = $api.Path
            ServiceUrl = $api.ServiceUrl
            Protocols = $api.Protocols
            ApiRevision = $api.ApiRevision
            ApiVersion = $api.ApiVersion
            IsCurrent = $api.IsCurrent
            SubscriptionRequired = $api.SubscriptionRequired
            Operations = @($operations | ForEach-Object {
                @{
                    OperationId = $_.OperationId
                    Name = $_.Name
                    Method = $_.Method
                    UrlTemplate = $_.UrlTemplate
                    Description = $_.Description
                }
            })
            Policy = $apiPolicy
            BackendInfo = $logicAppInfo
            Backends = @($backends | ForEach-Object {
                @{
                    BackendId = $_.BackendId
                    Url = $_.Url
                    Protocol = $_.Protocol
                    Title = $_.Title
                }
            })
        }
        
        Write-Log "API configuration collected: $($operations.Count) operations found" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect API configuration: $_" -Level "ERROR"
        return $null
    }
}

function Get-LogicAppConfiguration {
    param(
        [string]$LogicAppName,
        [string]$ResourceGroup
    )
    
    Write-Log "Collecting Logic App configuration for: $LogicAppName"
    
    try {
        # Try Logic App Standard first
        $logicApp = $null
        $isStandard = $false
        
        try {
            # Logic App Standard (Function App based)
            $logicApp = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $LogicAppName -ErrorAction Stop
            $isStandard = $true
            Write-Log "Found Logic App Standard: $LogicAppName"
        }
        catch {
            # Try Logic App Consumption
            try {
                $logicApp = Get-AzLogicApp -ResourceGroupName $ResourceGroup -Name $LogicAppName -ErrorAction Stop
                $isStandard = $false
                Write-Log "Found Logic App Consumption: $LogicAppName"
            }
            catch {
                throw "Logic App not found: $LogicAppName"
            }
        }
        
        if ($isStandard) {
            # Logic App Standard configuration
            $config = @{
                ResourceName = $logicApp.Name
                ResourceGroup = $ResourceGroup
                ResourceId = $logicApp.Id
                Type = "Standard"
                Region = $logicApp.Location
                State = $logicApp.State
                DefaultHostName = $logicApp.DefaultHostName
                HttpsOnly = $logicApp.HttpsOnly
                Identity = @{
                    Type = $logicApp.Identity.Type
                    PrincipalId = $logicApp.Identity.PrincipalId
                    TenantId = $logicApp.Identity.TenantId
                }
                AppSettings = @{}
                Workflows = @()
            }
            
            # Get app settings (contains workflow configurations)
            try {
                $appSettings = Get-AzWebAppSlotConfigName -ResourceGroupName $ResourceGroup -Name $LogicAppName
                $webapp = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $LogicAppName
                $config.AppSettings = $webapp.SiteConfig.AppSettings | ForEach-Object {
                    @{ $_.Name = $_.Value }
                }
            } catch { }
            
        }
        else {
            # Logic App Consumption configuration
            $config = @{
                ResourceName = $logicApp.Name
                ResourceGroup = $ResourceGroup
                ResourceId = $logicApp.Id
                Type = "Consumption"
                Region = $logicApp.Location
                State = $logicApp.State
                AccessEndpoint = $logicApp.AccessEndpoint
                Identity = @{
                    Type = $logicApp.Identity.Type
                    PrincipalId = $logicApp.Identity.PrincipalId
                    TenantId = $logicApp.Identity.TenantId
                }
                WorkflowDefinition = $logicApp.Definition
                Parameters = $logicApp.Parameters
            }
        }
        
        Write-Log "Logic App configuration collected successfully" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect Logic App configuration: $_" -Level "ERROR"
        return $null
    }
}

function Get-LogicAppWorkflowDefinition {
    param(
        [string]$LogicAppName,
        [string]$ResourceGroup,
        [string]$WorkflowName,
        [string]$SubscriptionId
    )
    
    Write-Log "Collecting workflow definition for: $WorkflowName"
    
    try {
        # For Logic App Standard, workflows are accessed via REST API
        $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
        
        # Get workflow definition
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/$WorkflowName`?api-version=2022-03-01"
        
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        
        $workflow = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        # Parse workflow to extract actions and connections
        $actions = @()
        $connections = @()
        $triggers = @()
        
        if ($workflow.properties.definition) {
            $definition = $workflow.properties.definition
            
            # Extract triggers
            if ($definition.triggers) {
                foreach ($triggerName in $definition.triggers.PSObject.Properties.Name) {
                    $trigger = $definition.triggers.$triggerName
                    $triggers += @{
                        Name = $triggerName
                        Type = $trigger.type
                        Kind = $trigger.kind
                        Inputs = $trigger.inputs
                    }
                }
            }
            
            # Extract actions
            if ($definition.actions) {
                foreach ($actionName in $definition.actions.PSObject.Properties.Name) {
                    $action = $definition.actions.$actionName
                    $actions += @{
                        Name = $actionName
                        Type = $action.type
                        RunAfter = $action.runAfter
                        Inputs = $action.inputs
                    }
                    
                    # Check for SQL or Data Gateway connections
                    if ($action.inputs.host.connection) {
                        $connRef = $action.inputs.host.connection.referenceName
                        if ($connRef -and $connRef -notin $connections) {
                            $connections += $connRef
                        }
                    }
                }
            }
        }
        
        $config = @{
            WorkflowName = $WorkflowName
            State = $workflow.properties.state
            Definition = $workflow.properties.definition
            Triggers = $triggers
            Actions = $actions
            ConnectionReferences = $connections
            CreatedTime = $workflow.properties.createdTime
            ChangedTime = $workflow.properties.changedTime
        }
        
        Write-Log "Workflow definition collected: $($actions.Count) actions, $($connections.Count) connections" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect workflow definition: $_" -Level "ERROR"
        return $null
    }
}

function Get-ApiConnectionsConfiguration {
    param(
        [string]$ResourceGroup,
        [string[]]$ConnectionNames
    )
    
    Write-Log "Collecting API connections configuration"
    
    $connections = @()
    
    try {
        # Get all API connections in the resource group
        $allConnections = Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType "Microsoft.Web/connections"
        
        foreach ($conn in $allConnections) {
            if (-not $ConnectionNames -or $conn.Name -in $ConnectionNames) {
                # Get detailed connection info
                $connDetail = Get-AzResource -ResourceId $conn.ResourceId -ExpandProperties
                
                $connectionConfig = @{
                    Name = $conn.Name
                    ResourceId = $conn.ResourceId
                    Type = $connDetail.Properties.api.name
                    DisplayName = $connDetail.Properties.displayName
                    Status = $connDetail.Properties.statuses
                    CreatedTime = $connDetail.Properties.createdTime
                    ChangedTime = $connDetail.Properties.changedTime
                }
                
                # Check for gateway connection
                if ($connDetail.Properties.parameterValues.gateway) {
                    $gatewayRef = $connDetail.Properties.parameterValues.gateway
                    $connectionConfig.Gateway = @{
                        Id = $gatewayRef.id
                        Name = $gatewayRef.name
                    }
                }
                
                # Check for SQL connection details
                if ($connDetail.Properties.api.name -eq "sql") {
                    $connectionConfig.SqlInfo = @{
                        Server = $connDetail.Properties.parameterValues.server
                        Database = $connDetail.Properties.parameterValues.database
                        AuthType = $connDetail.Properties.parameterValues.authType
                    }
                }
                
                $connections += $connectionConfig
            }
        }
        
        Write-Log "Collected $($connections.Count) API connections" -Level "SUCCESS"
        return $connections
    }
    catch {
        Write-Log "Failed to collect API connections: $_" -Level "ERROR"
        return @()
    }
}

function Get-OnPremDataGatewayConfiguration {
    param(
        [string]$GatewayResourceId
    )
    
    Write-Log "Collecting On-Premises Data Gateway configuration"
    
    try {
        if (-not $GatewayResourceId) {
            # Search for gateways in the subscription
            $gateways = Get-AzResource -ResourceType "Microsoft.Web/connectionGateways"
            
            return @($gateways | ForEach-Object {
                $detail = Get-AzResource -ResourceId $_.ResourceId -ExpandProperties
                @{
                    Name = $_.Name
                    ResourceId = $_.ResourceId
                    ResourceGroup = $_.ResourceGroupName
                    Region = $_.Location
                    Type = $detail.Properties.connectionGatewayInstallation.name
                    Status = $detail.Properties.status
                }
            })
        }
        else {
            $gateway = Get-AzResource -ResourceId $GatewayResourceId -ExpandProperties
            
            return @{
                Name = $gateway.Name
                ResourceId = $gateway.ResourceId
                ResourceGroup = $gateway.ResourceGroupName
                Region = $gateway.Location
                Type = $gateway.Properties.connectionGatewayInstallation.name
                Status = $gateway.Properties.status
                MachineName = $gateway.Properties.connectionGatewayInstallation.machineName
            }
        }
    }
    catch {
        Write-Log "Failed to collect Data Gateway configuration: $_" -Level "ERROR"
        return $null
    }
}

function Get-KeyVaultConfiguration {
    param(
        [string]$KeyVaultName,
        [string]$ResourceGroup
    )
    
    Write-Log "Collecting Key Vault configuration for: $KeyVaultName"
    
    try {
        $kv = Get-AzKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroup -ErrorAction Stop
        
        # Get secrets list (not values)
        $secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName | ForEach-Object {
            @{
                Name = $_.Name
                Enabled = $_.Enabled
                Created = $_.Created
                Updated = $_.Updated
                Expires = $_.Expires
                ContentType = $_.ContentType
            }
        }
        
        $config = @{
            Name = $kv.VaultName
            ResourceId = $kv.ResourceId
            ResourceGroup = $ResourceGroup
            Region = $kv.Location
            Sku = $kv.Sku
            TenantId = $kv.TenantId
            VaultUri = $kv.VaultUri
            EnableSoftDelete = $kv.EnableSoftDelete
            SoftDeleteRetentionInDays = $kv.SoftDeleteRetentionInDays
            EnablePurgeProtection = $kv.EnablePurgeProtection
            EnableRbacAuthorization = $kv.EnableRbacAuthorization
            NetworkRuleSet = @{
                DefaultAction = $kv.NetworkAcls.DefaultAction
                Bypass = $kv.NetworkAcls.Bypass
                IpRules = $kv.NetworkAcls.IpAddressRanges
                VirtualNetworkRules = $kv.NetworkAcls.VirtualNetworkResourceIds
            }
            Secrets = $secrets
        }
        
        Write-Log "Key Vault configuration collected: $($secrets.Count) secrets found" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect Key Vault configuration: $_" -Level "ERROR"
        return $null
    }
}

function Get-ApplicationInsightsConfiguration {
    param(
        [string]$AppInsightsName,
        [string]$ResourceGroup
    )
    
    Write-Log "Collecting Application Insights configuration"
    
    try {
        $appInsights = Get-AzApplicationInsights -ResourceGroupName $ResourceGroup -Name $AppInsightsName -ErrorAction Stop
        
        $config = @{
            Name = $appInsights.Name
            ResourceId = $appInsights.Id
            ResourceGroup = $ResourceGroup
            Region = $appInsights.Location
            InstrumentationKey = $appInsights.InstrumentationKey
            ConnectionString = $appInsights.ConnectionString
            ApplicationId = $appInsights.AppId
            ApplicationType = $appInsights.ApplicationType
            WorkspaceResourceId = $appInsights.WorkspaceResourceId
            RetentionInDays = $appInsights.RetentionInDays
            IngestionMode = $appInsights.IngestionMode
            PublicNetworkAccessForIngestion = $appInsights.PublicNetworkAccessForIngestion
            PublicNetworkAccessForQuery = $appInsights.PublicNetworkAccessForQuery
        }
        
        Write-Log "Application Insights configuration collected successfully" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect Application Insights configuration: $_" -Level "ERROR"
        return $null
    }
}

function Get-FrontDoorConfiguration {
    param(
        [string]$FrontDoorName,
        [string]$ResourceGroup
    )
    
    Write-Log "Collecting Front Door configuration for: $FrontDoorName"
    
    try {
        # Try Azure Front Door Standard/Premium first
        $frontDoor = Get-AzFrontDoorCdnProfile -ResourceGroupName $ResourceGroup -Name $FrontDoorName -ErrorAction SilentlyContinue
        
        if ($frontDoor) {
            # Front Door Standard/Premium
            $endpoints = Get-AzFrontDoorCdnEndpoint -ResourceGroupName $ResourceGroup -ProfileName $FrontDoorName
            $origins = @()
            $routes = @()
            
            foreach ($endpoint in $endpoints) {
                $originGroups = Get-AzFrontDoorCdnOriginGroup -ResourceGroupName $ResourceGroup -ProfileName $FrontDoorName -EndpointName $endpoint.Name -ErrorAction SilentlyContinue
                
                foreach ($og in $originGroups) {
                    $originsInGroup = Get-AzFrontDoorCdnOrigin -ResourceGroupName $ResourceGroup -ProfileName $FrontDoorName -OriginGroupName $og.Name -ErrorAction SilentlyContinue
                    $origins += $originsInGroup
                }
                
                $routesForEndpoint = Get-AzFrontDoorCdnRoute -ResourceGroupName $ResourceGroup -ProfileName $FrontDoorName -EndpointName $endpoint.Name -ErrorAction SilentlyContinue
                $routes += $routesForEndpoint
            }
            
            $config = @{
                Type = "Standard/Premium"
                Name = $frontDoor.Name
                ResourceId = $frontDoor.Id
                ResourceGroup = $ResourceGroup
                Sku = $frontDoor.SkuName
                State = $frontDoor.ResourceState
                Endpoints = @($endpoints | ForEach-Object {
                    @{
                        Name = $_.Name
                        HostName = $_.HostName
                        State = $_.EnabledState
                    }
                })
                Origins = @($origins | ForEach-Object {
                    @{
                        Name = $_.Name
                        HostName = $_.HostName
                        Priority = $_.Priority
                        Weight = $_.Weight
                        Enabled = $_.EnabledState
                    }
                })
                Routes = @($routes | ForEach-Object {
                    @{
                        Name = $_.Name
                        Patterns = $_.PatternsToMatch
                        ForwardingProtocol = $_.ForwardingProtocol
                    }
                })
            }
        }
        else {
            # Try Classic Front Door
            $frontDoor = Get-AzFrontDoor -ResourceGroupName $ResourceGroup -Name $FrontDoorName -ErrorAction Stop
            
            $config = @{
                Type = "Classic"
                Name = $frontDoor.Name
                ResourceId = $frontDoor.Id
                ResourceGroup = $ResourceGroup
                FrontendEndpoints = @($frontDoor.FrontendEndpoints | ForEach-Object {
                    @{
                        Name = $_.Name
                        HostName = $_.HostName
                        SessionAffinityEnabled = $_.SessionAffinityEnabledState
                        WebApplicationFirewallPolicyLink = $_.WebApplicationFirewallPolicyLink
                    }
                })
                BackendPools = @($frontDoor.BackendPools | ForEach-Object {
                    @{
                        Name = $_.Name
                        Backends = $_.Backends
                        HealthProbeSettings = $_.HealthProbeSettingsRef
                        LoadBalancingSettings = $_.LoadBalancingSettingsRef
                    }
                })
                RoutingRules = @($frontDoor.RoutingRules | ForEach-Object {
                    @{
                        Name = $_.Name
                        FrontendEndpoints = $_.FrontendEndpointRefs
                        AcceptedProtocols = $_.AcceptedProtocols
                        PatternsToMatch = $_.PatternsToMatch
                        RouteConfiguration = $_.RouteConfiguration
                    }
                })
            }
        }
        
        Write-Log "Front Door configuration collected successfully" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect Front Door configuration: $_" -Level "ERROR"
        return $null
    }
}

function Get-WafPolicyConfiguration {
    param(
        [string]$WafPolicyName,
        [string]$ResourceGroup
    )
    
    Write-Log "Collecting WAF Policy configuration for: $WafPolicyName"
    
    try {
        # Try Front Door WAF Policy
        $waf = Get-AzFrontDoorWafPolicy -ResourceGroupName $ResourceGroup -Name $WafPolicyName -ErrorAction Stop
        
        $config = @{
            Name = $waf.Name
            ResourceId = $waf.Id
            ResourceGroup = $ResourceGroup
            Mode = $waf.PolicyMode
            EnabledState = $waf.PolicyEnabledState
            ManagedRules = @($waf.ManagedRules.ManagedRuleSets | ForEach-Object {
                @{
                    RuleSetType = $_.RuleSetType
                    RuleSetVersion = $_.RuleSetVersion
                    RuleGroupOverrides = $_.RuleGroupOverrides
                }
            })
            CustomRules = @($waf.CustomRules.Rules | ForEach-Object {
                @{
                    Name = $_.Name
                    Priority = $_.Priority
                    RuleType = $_.RuleType
                    Action = $_.Action
                    MatchConditions = @($_.MatchConditions | ForEach-Object {
                        @{
                            MatchVariable = $_.MatchVariable
                            Operator = $_.Operator
                            MatchValue = $_.MatchValue
                            NegateCondition = $_.NegateCondition
                        }
                    })
                }
            })
            RedirectUrl = $waf.RedirectUrl
            CustomBlockResponseStatusCode = $waf.CustomBlockResponseStatusCode
            CustomBlockResponseBody = $waf.CustomBlockResponseBody
        }
        
        Write-Log "WAF Policy configuration collected: $($waf.CustomRules.Rules.Count) custom rules" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to collect WAF Policy configuration: $_" -Level "ERROR"
        return $null
    }
}

#endregion

#region Main Execution

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Set subscription context if provided
if ($SubscriptionId) {
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Write-Log "Set Azure context to subscription: $SubscriptionId"
}

$currentContext = Get-AzContext
$subscriptionId = $currentContext.Subscription.Id
Write-Log "Using subscription: $($currentContext.Subscription.Name) ($subscriptionId)"

# Initialize collection object
$collectedConfig = @{
    Metadata = @{
        CollectionDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SubscriptionId = $subscriptionId
        SubscriptionName = $currentContext.Subscription.Name
        TenantId = $currentContext.Tenant.Id
        CollectedBy = $currentContext.Account.Id
        ApiName = $ApiName
    }
    Apim = $null
    Api = $null
    LogicApp = $null
    Workflow = $null
    Connections = @()
    DataGateway = $null
    KeyVault = $null
    ApplicationInsights = $null
    FrontDoor = $null
    Waf = $null
}

# Collect APIM configuration
$collectedConfig.Apim = Get-ApimConfiguration -ApimName $ApimName -ResourceGroup $ApimResourceGroup

# Collect API configuration
$collectedConfig.Api = Get-ApimApiConfiguration -ApimName $ApimName -ResourceGroup $ApimResourceGroup -ApiName $ApiName

# If API has a backend Logic App, collect its configuration
if ($collectedConfig.Api.BackendInfo) {
    $backendUrl = $collectedConfig.Api.BackendInfo.Url
    
    # Parse Logic App name from URL
    if ($backendUrl -match "sites/([^/]+)/") {
        $logicAppName = $Matches[1]
        Write-Log "Detected Logic App: $logicAppName"
        
        # Try to find Logic App resource group
        $logicAppResource = Get-AzResource -Name $logicAppName -ResourceType "Microsoft.Web/sites" -ErrorAction SilentlyContinue
        
        if ($logicAppResource) {
            $collectedConfig.LogicApp = Get-LogicAppConfiguration -LogicAppName $logicAppName -ResourceGroup $logicAppResource.ResourceGroupName
            
            # If Logic App Standard, try to get workflow
            if ($collectedConfig.LogicApp.Type -eq "Standard") {
                # Extract workflow name from URL if present
                if ($backendUrl -match "/workflows/([^/\?]+)") {
                    $workflowName = $Matches[1]
                    $collectedConfig.Workflow = Get-LogicAppWorkflowDefinition -LogicAppName $logicAppName -ResourceGroup $logicAppResource.ResourceGroupName -WorkflowName $workflowName -SubscriptionId $subscriptionId
                    
                    # Collect connections used by workflow
                    if ($collectedConfig.Workflow.ConnectionReferences) {
                        $collectedConfig.Connections = Get-ApiConnectionsConfiguration -ResourceGroup $logicAppResource.ResourceGroupName -ConnectionNames $collectedConfig.Workflow.ConnectionReferences
                        
                        # Extract Data Gateway info from connections
                        foreach ($conn in $collectedConfig.Connections) {
                            if ($conn.Gateway) {
                                $collectedConfig.DataGateway = Get-OnPremDataGatewayConfiguration -GatewayResourceId $conn.Gateway.Id
                                break
                            }
                        }
                    }
                }
            }
        }
    }
}

# Generate output filename
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $OutputPath "AsBuilt_${ApiName}_${timestamp}.json"

# Export collected configuration
$collectedConfig | ConvertTo-Json -Depth 20 | Out-File $outputFile -Encoding UTF8

Write-Log "Configuration exported to: $outputFile" -Level "SUCCESS"
Write-Log "Collection complete!" -Level "SUCCESS"

# Return the collected config for pipeline use
return $collectedConfig

#endregion
