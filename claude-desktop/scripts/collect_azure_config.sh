#!/bin/bash
#
# Azure As-Built Configuration Collector
# Collects APIM, Logic App, and related service configuration
#
# Usage: ./collect_azure_config.sh <apim-name> <resource-group> <api-name> [output-dir]
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - jq installed for JSON parsing
#
# Author: Bios Data Center
# Version: 1.0

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    command -v az &> /dev/null || { log_error "Azure CLI not installed"; exit 1; }
    command -v jq &> /dev/null || { log_error "jq not installed"; exit 1; }
    az account show &> /dev/null || { log_error "Not logged in. Run 'az login'"; exit 1; }
}

APIM_NAME="${1:?Error: APIM name required}"
RESOURCE_GROUP="${2:?Error: Resource group required}"
API_NAME="${3:?Error: API name required}"
OUTPUT_DIR="${4:-./output}"

mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/config_${API_NAME}_$(date +%Y%m%d_%H%M%S).json"

log_info "Starting Azure configuration collection..."
check_prerequisites

SUBSCRIPTION=$(az account show --query '{id:id, name:name}' -o json)
SUBSCRIPTION_ID=$(echo "$SUBSCRIPTION" | jq -r '.id')

CONFIG='{"metadata":{},"shared_infrastructure":{},"service":{}}'
CONFIG=$(echo "$CONFIG" | jq --arg date "$(date -Iseconds)" --arg name "$API_NAME" \
    --arg sub "$(echo "$SUBSCRIPTION" | jq -r '.name')" --arg subid "$SUBSCRIPTION_ID" \
    '.metadata = {collection_date: $date, service_name: $name, subscription: $sub, subscription_id: $subid, environment: "Production"}')

# 1. APIM
log_info "Collecting APIM configuration..."
APIM_CONFIG=$(az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" \
    --query '{resource_name:name,resource_group:resourceGroup,region:location,sku:sku.name,capacity:sku.capacity,gateway_url:gatewayUrl,developer_portal_url:developerPortalUrl,virtual_network_type:virtualNetworkType,identity:identity}' \
    -o json 2>/dev/null || echo '{}')
CONFIG=$(echo "$CONFIG" | jq --argjson v "$APIM_CONFIG" '.service.apim = $v')

# 2. API
log_info "Collecting API configuration..."
API_CONFIG=$(az apim api show --api-id "$API_NAME" --service-name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" \
    --query '{name:name,display_name:displayName,path:path,service_url:serviceUrl,protocols:protocols,subscription_required:subscriptionRequired}' \
    -o json 2>/dev/null || echo '{}')
API_OPS=$(az apim api operation list --api-id "$API_NAME" --service-name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" \
    --query '[].{name:name,method:method,urlTemplate:urlTemplate}' -o json 2>/dev/null || echo '[]')
API_CONFIG=$(echo "$API_CONFIG" | jq --argjson ops "$API_OPS" '. + {operations: $ops}')
CONFIG=$(echo "$CONFIG" | jq --argjson v "$API_CONFIG" '.service.api = $v')

# 3. Logic App (from backend URL)
BACKEND_URL=$(echo "$API_CONFIG" | jq -r '.service_url // empty')
if [[ "$BACKEND_URL" == *"azurewebsites.net"* ]]; then
    LOGIC_APP_NAME=$(echo "$BACKEND_URL" | sed -n 's|https://\([^.]*\)\.azurewebsites\.net.*|\1|p')
    LOGIC_APP_RG=$(az webapp list --query "[?name=='$LOGIC_APP_NAME'].resourceGroup" -o tsv 2>/dev/null | head -1)
    
    if [[ -n "$LOGIC_APP_RG" ]]; then
        log_info "Collecting Logic App: $LOGIC_APP_NAME"
        LA_CONFIG=$(az webapp show --name "$LOGIC_APP_NAME" --resource-group "$LOGIC_APP_RG" \
            --query '{resource_name:name,resource_group:resourceGroup,region:location,state:state,identity:identity}' \
            -o json 2>/dev/null || echo '{}')
        LA_CONFIG=$(echo "$LA_CONFIG" | jq '. + {type: "Standard"}')
        CONFIG=$(echo "$CONFIG" | jq --argjson v "$LA_CONFIG" '.service.logic_app = $v')
        
        # Workflow
        WORKFLOW_NAME=$(echo "$BACKEND_URL" | sed -n 's|.*/api/\([^/]*\)/.*|\1|p')
        [[ -z "$WORKFLOW_NAME" ]] && WORKFLOW_NAME=$(echo "$BACKEND_URL" | sed -n 's|.*/workflows/\([^/]*\)/.*|\1|p')
        
        if [[ -n "$WORKFLOW_NAME" ]]; then
            log_info "Collecting workflow: $WORKFLOW_NAME"
            TOKEN=$(az account get-access-token --query accessToken -o tsv)
            WF=$(curl -s -H "Authorization: Bearer $TOKEN" \
                "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$LOGIC_APP_RG/providers/Microsoft.Web/sites/$LOGIC_APP_NAME/hostruntime/runtime/webhooks/workflow/api/management/workflows/$WORKFLOW_NAME?api-version=2022-03-01" \
                2>/dev/null || echo '{}')
            
            if [[ "$WF" != *"error"* ]]; then
                WF_CONFIG=$(echo "$WF" | jq '{name:.name,state:.properties.state,definition:.properties.definition}' 2>/dev/null || echo '{}')
                CONFIG=$(echo "$CONFIG" | jq --argjson v "$WF_CONFIG" '.service.workflow = $v')
            fi
        fi
        
        # Connections
        log_info "Collecting API connections..."
        CONNS=$(az resource list --resource-group "$LOGIC_APP_RG" --resource-type "Microsoft.Web/connections" \
            --query '[].{name:name,id:id}' -o json 2>/dev/null || echo '[]')
        CONN_DETAILS="[]"
        for CID in $(echo "$CONNS" | jq -r '.[].id'); do
            CD=$(az resource show --ids "$CID" --query '{name:name,type:properties.api.name}' -o json 2>/dev/null || echo '{}')
            CONN_DETAILS=$(echo "$CONN_DETAILS" | jq --argjson c "$CD" '. + [$c]')
        done
        CONFIG=$(echo "$CONFIG" | jq --argjson v "$CONN_DETAILS" '.service.connections = $v')
    fi
fi

# 4. Key Vault
log_info "Searching for Key Vault..."
KV=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query '[0].name' -o tsv 2>/dev/null || echo "")
if [[ -n "$KV" ]]; then
    log_info "Found Key Vault: $KV"
    KV_CONFIG=$(az keyvault show --name "$KV" --query '{name:name,region:location,sku:properties.sku.name,vault_uri:properties.vaultUri}' -o json 2>/dev/null || echo '{}')
    SECRETS=$(az keyvault secret list --vault-name "$KV" --query '[].{name:name,enabled:attributes.enabled}' -o json 2>/dev/null || echo '[]')
    KV_CONFIG=$(echo "$KV_CONFIG" | jq --argjson s "$SECRETS" '. + {secrets: $s}')
    CONFIG=$(echo "$CONFIG" | jq --argjson v "$KV_CONFIG" '.service.key_vault = $v')
fi

# 5. App Insights
log_info "Searching for Application Insights..."
AI=$(az monitor app-insights component list --resource-group "$RESOURCE_GROUP" --query '[0]' -o json 2>/dev/null || echo 'null')
if [[ "$AI" != "null" && -n "$AI" ]]; then
    AI_CONFIG=$(echo "$AI" | jq '{name:.name,region:.location,instrumentation_key:.instrumentationKey,retention_days:.retentionInDays}' 2>/dev/null || echo '{}')
    CONFIG=$(echo "$CONFIG" | jq --argjson v "$AI_CONFIG" '.service.app_insights = $v')
fi

# Save
echo "$CONFIG" | jq '.' > "$OUTPUT_FILE"

log_info "Configuration saved to: $OUTPUT_FILE"
echo ""
echo "Summary:"
echo "  APIM: $(echo "$CONFIG" | jq -r '.service.apim.resource_name // "N/A"')"
echo "  API: $(echo "$CONFIG" | jq -r '.service.api.name // "N/A"')"
echo "  Logic App: $(echo "$CONFIG" | jq -r '.service.logic_app.resource_name // "N/A"')"
echo "  Workflow: $(echo "$CONFIG" | jq -r '.service.workflow.name // "N/A"')"
echo "  Connections: $(echo "$CONFIG" | jq '.service.connections | length')"
echo ""
echo "Next: node generate_asbuilt_doc.js $OUTPUT_FILE output.docx"
