#!/usr/bin/env python3
"""
Azure As-Built Configuration Collector
Parses and processes Azure configuration data for documentation.

Author: Bios Data Center
Version: 1.0
"""

import json
import re
from datetime import datetime
from typing import Dict, Any, List, Optional

class WorkflowParser:
    """Parse Logic App workflow definitions to extract documentation."""
    
    @staticmethod
    def parse_workflow(definition: Dict[str, Any]) -> Dict[str, Any]:
        """Parse workflow definition into structured documentation."""
        result = {
            "triggers": [],
            "actions": [],
            "connections": [],
            "data_sources": [],
            "parameters": [],
            "variables": []
        }
        
        if not definition:
            return result
        
        # Parse triggers
        for name, trigger in definition.get("triggers", {}).items():
            result["triggers"].append({
                "name": name,
                "type": trigger.get("type"),
                "kind": trigger.get("kind"),
                "description": WorkflowParser._describe_trigger(trigger)
            })
        
        # Parse actions in order
        actions = definition.get("actions", {})
        ordered_actions = WorkflowParser._order_actions(actions)
        
        for action_name in ordered_actions:
            action = actions.get(action_name, {})
            action_info = {
                "name": action_name,
                "type": action.get("type"),
                "description": WorkflowParser._describe_action(action),
                "run_after": list(action.get("runAfter", {}).keys()),
                "inputs": WorkflowParser._sanitize_inputs(action.get("inputs", {}))
            }
            result["actions"].append(action_info)
            
            # Extract connections
            conn = WorkflowParser._extract_connection(action)
            if conn and conn not in result["connections"]:
                result["connections"].append(conn)
            
            # Identify data sources
            ds = WorkflowParser._identify_data_source(action)
            if ds:
                result["data_sources"].append(ds)
        
        return result
    
    @staticmethod
    def _order_actions(actions: Dict[str, Any]) -> List[str]:
        """Order actions by execution dependency."""
        ordered = []
        remaining = set(actions.keys())
        max_iterations = len(actions) * 2
        iteration = 0
        
        while remaining and iteration < max_iterations:
            iteration += 1
            for name in list(remaining):
                deps = actions[name].get("runAfter", {}).keys()
                if all(d in ordered for d in deps):
                    ordered.append(name)
                    remaining.remove(name)
                    break
            else:
                if remaining:
                    ordered.extend(remaining)
                    break
        
        return ordered
    
    @staticmethod
    def _describe_trigger(trigger: Dict[str, Any]) -> str:
        """Generate human-readable trigger description."""
        t_type = trigger.get("type", "Unknown")
        
        if t_type == "Request":
            method = trigger.get("inputs", {}).get("method", "POST")
            return f"HTTP {method} Request - Receives incoming API calls"
        
        if t_type == "Recurrence":
            rec = trigger.get("recurrence", {})
            freq = rec.get("frequency", "Day")
            interval = rec.get("interval", 1)
            return f"Scheduled - Runs every {interval} {freq.lower()}(s)"
        
        if t_type == "ApiConnection":
            return "API Connection - Triggered by external service event"
        
        return f"{t_type} trigger"
    
    @staticmethod
    def _describe_action(action: Dict[str, Any]) -> str:
        """Generate human-readable action description."""
        a_type = action.get("type", "Unknown")
        inputs = action.get("inputs", {})
        
        descriptions = {
            "Response": lambda: f"Return HTTP {inputs.get('statusCode', 200)} response",
            "Compose": lambda: "Transform/compose data",
            "ParseJson": lambda: "Parse JSON content",
            "Condition": lambda: "Conditional branch (If/Then/Else)",
            "ForEach": lambda: "Loop through collection",
            "Switch": lambda: "Switch/case evaluation",
            "Scope": lambda: "Grouped actions scope",
            "InitializeVariable": lambda: f"Initialize variable",
            "SetVariable": lambda: "Set variable value",
            "AppendToArrayVariable": lambda: "Append to array",
            "Http": lambda: f"HTTP {inputs.get('method', 'GET')} call to {inputs.get('uri', 'external service')[:50]}",
            "ApiConnection": lambda: WorkflowParser._describe_api_connection(inputs),
        }
        
        if a_type in descriptions:
            return descriptions[a_type]()
        
        return f"{a_type} action"
    
    @staticmethod
    def _describe_api_connection(inputs: Dict[str, Any]) -> str:
        """Describe API connection action."""
        host = inputs.get("host", {})
        api_id = host.get("apiId", "")
        path = inputs.get("path", "")
        method = inputs.get("method", "")
        
        if "sql" in api_id.lower():
            if "executestoredprocedure" in path.lower():
                proc = path.split("/")[-1] if "/" in path else "stored procedure"
                return f"Execute SQL stored procedure: {proc}"
            if "executequery" in path.lower():
                return "Execute SQL query"
            return "SQL Server operation"
        
        if "office365" in api_id.lower():
            return "Office 365 operation"
        
        if "keyvault" in api_id.lower():
            return "Key Vault secret operation"
        
        return f"API Connection: {method} {path[:50] if path else 'operation'}"
    
    @staticmethod
    def _extract_connection(action: Dict[str, Any]) -> Optional[str]:
        """Extract connection reference from action."""
        inputs = action.get("inputs", {})
        if isinstance(inputs, dict):
            host = inputs.get("host", {})
            if isinstance(host, dict):
                conn = host.get("connection", {})
                if isinstance(conn, dict):
                    return conn.get("referenceName")
        return None
    
    @staticmethod
    def _identify_data_source(action: Dict[str, Any]) -> Optional[Dict[str, str]]:
        """Identify if action interacts with a data source."""
        inputs = action.get("inputs", {})
        host = inputs.get("host", {}) if isinstance(inputs, dict) else {}
        api_id = host.get("apiId", "") if isinstance(host, dict) else ""
        
        if "sql" in api_id.lower():
            return {
                "type": "SQL Server",
                "action": action.get("type"),
                "operation": inputs.get("path", "").split("/")[-1] if inputs.get("path") else "query"
            }
        
        if "sharepointonline" in api_id.lower():
            return {"type": "SharePoint Online", "action": action.get("type")}
        
        if "azureblob" in api_id.lower():
            return {"type": "Azure Blob Storage", "action": action.get("type")}
        
        return None
    
    @staticmethod
    def _sanitize_inputs(inputs: Dict[str, Any]) -> Dict[str, Any]:
        """Remove sensitive data from inputs for documentation."""
        if not isinstance(inputs, dict):
            return {}
        
        sanitized = {}
        sensitive_keys = ["authentication", "password", "secret", "key", "token", "sig"]
        
        for k, v in inputs.items():
            if any(s in k.lower() for s in sensitive_keys):
                sanitized[k] = "[REDACTED]"
            elif isinstance(v, dict):
                sanitized[k] = WorkflowParser._sanitize_inputs(v)
            else:
                sanitized[k] = v
        
        return sanitized
    
    @staticmethod
    def generate_markdown(parsed: Dict[str, Any], workflow_name: str = "Workflow") -> str:
        """Generate markdown documentation for workflow."""
        lines = [f"## {workflow_name}\n"]
        
        # Triggers
        lines.append("### Trigger Configuration")
        for t in parsed.get("triggers", []):
            lines.append(f"- **{t['name']}** ({t['type']}): {t['description']}")
        lines.append("")
        
        # Actions
        lines.append("### Workflow Actions (Execution Order)")
        lines.append("")
        lines.append("| Step | Action | Type | Description | Depends On |")
        lines.append("|------|--------|------|-------------|------------|")
        for i, a in enumerate(parsed.get("actions", []), 1):
            deps = ", ".join(a.get("run_after", [])) or "-"
            lines.append(f"| {i} | {a['name']} | {a['type']} | {a['description']} | {deps} |")
        lines.append("")
        
        # Connections
        if parsed.get("connections"):
            lines.append("### API Connections")
            for c in parsed["connections"]:
                lines.append(f"- {c}")
            lines.append("")
        
        # Data sources
        if parsed.get("data_sources"):
            lines.append("### Data Sources")
            for ds in parsed["data_sources"]:
                lines.append(f"- **{ds['type']}**: {ds.get('operation', 'N/A')}")
            lines.append("")
        
        return "\n".join(lines)


class ConfigurationAggregator:
    """Aggregate configuration from multiple Azure resources."""
    
    def __init__(self):
        self.config = {
            "metadata": {
                "collection_date": datetime.now().isoformat(),
                "version": "1.0"
            },
            "shared_infrastructure": {},
            "service": {}
        }
    
    def set_metadata(self, service_name: str, environment: str, subscription: str):
        """Set documentation metadata."""
        self.config["metadata"].update({
            "service_name": service_name,
            "environment": environment,
            "subscription": subscription
        })
    
    def add_apim_config(self, apim_data: Dict[str, Any]):
        """Add APIM configuration."""
        self.config["service"]["apim"] = {
            "resource_name": apim_data.get("name"),
            "resource_group": apim_data.get("resourceGroup"),
            "region": apim_data.get("location"),
            "sku": apim_data.get("sku", {}).get("name"),
            "capacity": apim_data.get("sku", {}).get("capacity"),
            "gateway_url": apim_data.get("gatewayUrl"),
            "developer_portal_url": apim_data.get("developerPortalUrl"),
            "virtual_network_type": apim_data.get("virtualNetworkType"),
            "identity": {
                "type": apim_data.get("identity", {}).get("type"),
                "principal_id": apim_data.get("identity", {}).get("principalId")
            }
        }
    
    def add_api_config(self, api_data: Dict[str, Any]):
        """Add API configuration."""
        self.config["service"]["api"] = {
            "name": api_data.get("name"),
            "display_name": api_data.get("displayName"),
            "path": api_data.get("path"),
            "service_url": api_data.get("serviceUrl"),
            "protocols": api_data.get("protocols"),
            "subscription_required": api_data.get("subscriptionRequired"),
            "api_version": api_data.get("apiVersion"),
            "operations": api_data.get("operations", [])
        }
        
        # Parse backend URL to identify Logic App
        backend_url = api_data.get("serviceUrl", "")
        if backend_url:
            self.config["service"]["api"]["backend_type"] = self._identify_backend(backend_url)
    
    def add_logic_app_config(self, la_data: Dict[str, Any]):
        """Add Logic App configuration."""
        self.config["service"]["logic_app"] = {
            "resource_name": la_data.get("name"),
            "resource_group": la_data.get("resourceGroup"),
            "type": la_data.get("kind", "Standard"),
            "region": la_data.get("location"),
            "state": la_data.get("state"),
            "identity": la_data.get("identity", {})
        }
    
    def add_workflow_config(self, workflow_def: Dict[str, Any], workflow_name: str):
        """Add and parse workflow configuration."""
        parsed = WorkflowParser.parse_workflow(workflow_def)
        self.config["service"]["workflow"] = {
            "name": workflow_name,
            "parsed": parsed,
            "markdown": WorkflowParser.generate_markdown(parsed, workflow_name)
        }
    
    def add_connection_config(self, connections: List[Dict[str, Any]]):
        """Add API connections configuration."""
        self.config["service"]["connections"] = []
        
        for conn in connections:
            conn_info = {
                "name": conn.get("name"),
                "type": conn.get("api", {}).get("name"),
                "status": conn.get("statuses", [{}])[0].get("status") if conn.get("statuses") else "Unknown"
            }
            
            # Check for gateway connection
            params = conn.get("parameterValues", {})
            if params.get("gateway"):
                conn_info["gateway"] = params["gateway"]
            
            # Check for SQL connection
            if params.get("server"):
                conn_info["sql_server"] = params.get("server")
                conn_info["database"] = params.get("database")
            
            self.config["service"]["connections"].append(conn_info)
    
    def add_data_gateway_config(self, gateway_data: Dict[str, Any]):
        """Add On-Premises Data Gateway configuration."""
        self.config["service"]["data_gateway"] = {
            "name": gateway_data.get("name"),
            "resource_group": gateway_data.get("resourceGroup"),
            "region": gateway_data.get("location"),
            "type": gateway_data.get("properties", {}).get("connectionGatewayInstallation", {}).get("name"),
            "machine_name": gateway_data.get("properties", {}).get("connectionGatewayInstallation", {}).get("machineName")
        }
    
    def add_keyvault_config(self, kv_data: Dict[str, Any], secrets: List[Dict[str, Any]] = None):
        """Add Key Vault configuration."""
        self.config["service"]["key_vault"] = {
            "name": kv_data.get("name"),
            "resource_group": kv_data.get("resourceGroup"),
            "region": kv_data.get("location"),
            "sku": kv_data.get("properties", {}).get("sku", {}).get("name"),
            "vault_uri": kv_data.get("properties", {}).get("vaultUri"),
            "soft_delete_enabled": kv_data.get("properties", {}).get("enableSoftDelete"),
            "purge_protection": kv_data.get("properties", {}).get("enablePurgeProtection"),
            "secrets": [{"name": s.get("name"), "enabled": s.get("enabled")} for s in (secrets or [])]
        }
    
    def add_app_insights_config(self, ai_data: Dict[str, Any]):
        """Add Application Insights configuration."""
        self.config["service"]["app_insights"] = {
            "name": ai_data.get("name"),
            "resource_group": ai_data.get("resourceGroup"),
            "region": ai_data.get("location"),
            "instrumentation_key": ai_data.get("properties", {}).get("InstrumentationKey"),
            "connection_string": ai_data.get("properties", {}).get("ConnectionString"),
            "workspace_id": ai_data.get("properties", {}).get("WorkspaceResourceId"),
            "retention_days": ai_data.get("properties", {}).get("RetentionInDays")
        }
    
    def set_shared_infrastructure(self, front_door: Dict[str, Any] = None, waf: Dict[str, Any] = None):
        """Set shared infrastructure configuration (typically static)."""
        if front_door:
            self.config["shared_infrastructure"]["front_door"] = front_door
        if waf:
            self.config["shared_infrastructure"]["waf"] = waf
    
    def _identify_backend(self, url: str) -> Dict[str, str]:
        """Identify backend type from URL."""
        if "azurewebsites.net" in url:
            match = re.search(r"https://([^.]+)\.azurewebsites\.net", url)
            return {
                "type": "Logic App Standard",
                "name": match.group(1) if match else "Unknown"
            }
        if "logic.azure.com" in url:
            return {"type": "Logic App Consumption"}
        if "azure-api.net" in url:
            return {"type": "APIM Backend"}
        return {"type": "External"}
    
    def export_json(self, filepath: str):
        """Export configuration to JSON file."""
        with open(filepath, 'w') as f:
            json.dump(self.config, f, indent=2, default=str)
    
    def get_config(self) -> Dict[str, Any]:
        """Return the complete configuration."""
        return self.config


# Shared infrastructure defaults for Bios Data Center
BIOS_SHARED_INFRASTRUCTURE = {
    "front_door": {
        "resource_name": "[fd-bios-prod-001]",
        "resource_group": "[rg-networking-prod]",
        "sku": "Standard_AzureFrontDoor",
        "endpoint": "[endpoint].azurefd.net",
        "custom_domains": ["api.[client].co.za"],
        "ssl_certificate": "Azure Managed / Key Vault",
        "notes": "Shared Front Door instance - update custom domain per service"
    },
    "waf": {
        "policy_name": "[waf-bios-prod-001]",
        "resource_group": "[rg-networking-prod]",
        "mode": "Prevention",
        "rule_set": "Microsoft_DefaultRuleSet 2.1",
        "bot_protection": True,
        "ip_whitelist": "[Service-specific IPs added as custom rules]",
        "notes": "Shared WAF policy - add IP whitelist rules per service"
    }
}


if __name__ == "__main__":
    # Test workflow parser
    sample_workflow = {
        "triggers": {
            "manual": {
                "type": "Request",
                "kind": "Http",
                "inputs": {"method": "POST"}
            }
        },
        "actions": {
            "Parse_Request": {
                "type": "ParseJson",
                "runAfter": {}
            },
            "Execute_Stored_Procedure": {
                "type": "ApiConnection",
                "runAfter": {"Parse_Request": ["Succeeded"]},
                "inputs": {
                    "host": {
                        "apiId": "/providers/Microsoft.PowerApps/apis/sql",
                        "connection": {"referenceName": "sql-connection"}
                    },
                    "path": "/v2/datasets/@{encodeURIComponent()}/procedures/@{encodeURIComponent('sp_GetData')}"
                }
            },
            "Response": {
                "type": "Response",
                "runAfter": {"Execute_Stored_Procedure": ["Succeeded"]},
                "inputs": {"statusCode": 200}
            }
        }
    }
    
    parsed = WorkflowParser.parse_workflow(sample_workflow)
    print(WorkflowParser.generate_markdown(parsed, "Sample API Workflow"))
