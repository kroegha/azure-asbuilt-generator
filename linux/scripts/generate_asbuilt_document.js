const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, ImageRun,
        Header, Footer, AlignmentType, LevelFormat,
        TableOfContents, HeadingLevel, BorderStyle, WidthType, ShadingType,
        PageNumber, PageBreak } = require('docx');
const fs = require('fs');
const path = require('path');

/**
 * Azure API Service As-Built Document Generator
 * 
 * Takes collected Azure configuration JSON and generates a populated Word document.
 * 
 * Usage:
 *   node generate_asbuilt_document.js <config.json> [output.docx] [options.json]
 */

// === Configuration ===
const FONT = "Arial";
const HEADER_FILL = "1E3A5F";
const ALT_ROW_FILL = "F5F5F5";
const BORDER = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const BORDERS = { top: BORDER, bottom: BORDER, left: BORDER, right: BORDER };

// === Helper Functions ===

function createHeaderCell(text, width = 3120) {
    return new TableCell({
        borders: BORDERS,
        width: { size: width, type: WidthType.DXA },
        shading: { fill: HEADER_FILL, type: ShadingType.CLEAR },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        children: [new Paragraph({ 
            children: [new TextRun({ text: String(text || ''), bold: true, color: "FFFFFF", font: FONT, size: 20 })] 
        })]
    });
}

function createCell(text, width = 3120, fill = "FFFFFF") {
    return new TableCell({
        borders: BORDERS,
        width: { size: width, type: WidthType.DXA },
        shading: { fill, type: ShadingType.CLEAR },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        children: [new Paragraph({ 
            children: [new TextRun({ text: String(text || '-'), font: FONT, size: 20 })] 
        })]
    });
}

function createHeading(text, level) {
    return new Paragraph({
        heading: level,
        children: [new TextRun({ text, font: FONT })]
    });
}

function createParagraph(text, spacing = { after: 200 }) {
    return new Paragraph({
        spacing,
        children: [new TextRun({ text, font: FONT, size: 22 })]
    });
}

function createBoldParagraph(label, value, spacing = { after: 120 }) {
    return new Paragraph({
        spacing,
        children: [
            new TextRun({ text: label, bold: true, font: FONT, size: 22 }),
            new TextRun({ text: String(value || '-'), font: FONT, size: 22 })
        ]
    });
}

function createConfigTable(items, colWidths = [3120, 6240]) {
    const rows = [
        new TableRow({ children: [
            createHeaderCell("Configuration Item", colWidths[0]), 
            createHeaderCell("Value", colWidths[1])
        ]})
    ];
    
    items.forEach((item, index) => {
        const fill = index % 2 === 1 ? ALT_ROW_FILL : "FFFFFF";
        rows.push(new TableRow({ children: [
            createCell(item.label, colWidths[0], fill),
            createCell(item.value, colWidths[1], fill)
        ]}));
    });
    
    return new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        columnWidths: colWidths,
        rows
    });
}

function formatValue(value) {
    if (value === null || value === undefined) return '-';
    if (typeof value === 'boolean') return value ? 'Yes' : 'No';
    if (Array.isArray(value)) return value.join(', ') || '-';
    if (typeof value === 'object') return JSON.stringify(value);
    return String(value);
}

// === Document Generation Functions ===

function generateApimSection(config) {
    const apim = config.apim || {};
    const items = [
        { label: "Resource Name", value: apim.resource_name || apim.resourceName },
        { label: "Resource Group", value: apim.resource_group || apim.resourceGroup },
        { label: "Region", value: apim.region || apim.location },
        { label: "SKU/Tier", value: apim.sku },
        { label: "Capacity Units", value: apim.capacity },
        { label: "Gateway URL", value: apim.gateway_url || apim.gatewayUrl },
        { label: "Developer Portal URL", value: apim.developer_portal_url || apim.developerPortalUrl },
        { label: "Virtual Network Mode", value: apim.virtual_network_type || apim.virtualNetworkType || "None" },
        { label: "Managed Identity", value: apim.identity?.type || "None" },
        { label: "Identity Object ID", value: apim.identity?.principal_id || apim.identity?.principalId }
    ];
    
    return [
        createHeading("Azure API Management", HeadingLevel.HEADING_2),
        createParagraph("Azure API Management provides the API gateway functionality for this service."),
        createConfigTable(items),
        new Paragraph({ spacing: { after: 300 } })
    ];
}

function generateApiSection(config) {
    const api = config.api || {};
    const items = [
        { label: "API ID", value: api.api_id || api.apiId },
        { label: "Display Name", value: api.display_name || api.displayName || api.name },
        { label: "Description", value: api.description },
        { label: "Path", value: api.path },
        { label: "Backend URL", value: api.service_url || api.serviceUrl },
        { label: "Protocols", value: formatValue(api.protocols) },
        { label: "API Version", value: api.api_version || api.apiVersion || "-" },
        { label: "Subscription Required", value: formatValue(api.subscription_required ?? api.subscriptionRequired) }
    ];
    
    const sections = [
        createHeading("API Configuration", HeadingLevel.HEADING_3),
        createConfigTable(items),
        new Paragraph({ spacing: { after: 200 } })
    ];
    
    // Add operations table if available
    const operations = api.operations || [];
    if (operations.length > 0) {
        sections.push(createHeading("API Operations", HeadingLevel.HEADING_3));
        
        const opRows = [
            new TableRow({ children: [
                createHeaderCell("Operation", 2340),
                createHeaderCell("Method", 1560),
                createHeaderCell("URL Template", 3120),
                createHeaderCell("Description", 2340)
            ]})
        ];
        
        operations.forEach((op, index) => {
            const fill = index % 2 === 1 ? ALT_ROW_FILL : "FFFFFF";
            opRows.push(new TableRow({ children: [
                createCell(op.name || op.operation_id || op.operationId, 2340, fill),
                createCell(op.method, 1560, fill),
                createCell(op.url_template || op.urlTemplate, 3120, fill),
                createCell(op.description || "-", 2340, fill)
            ]}));
        });
        
        sections.push(new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            columnWidths: [2340, 1560, 3120, 2340],
            rows: opRows
        }));
        sections.push(new Paragraph({ spacing: { after: 300 } }));
    }
    
    return sections;
}

function generateLogicAppSection(config) {
    const logicApp = config.logic_app || config.logicApp || {};
    const items = [
        { label: "Resource Name", value: logicApp.resource_name || logicApp.resourceName },
        { label: "Resource Group", value: logicApp.resource_group || logicApp.resourceGroup },
        { label: "Region", value: logicApp.region || logicApp.location },
        { label: "Type", value: logicApp.type },
        { label: "State", value: logicApp.state },
        { label: "Default Host Name", value: logicApp.default_host_name || logicApp.defaultHostName },
        { label: "Managed Identity", value: logicApp.identity?.type || "None" },
        { label: "Identity Object ID", value: logicApp.identity?.principal_id || logicApp.identity?.principalId }
    ];
    
    return [
        createHeading("Logic Apps", HeadingLevel.HEADING_2),
        createParagraph("Logic Apps provide the serverless integration workflow for processing API requests."),
        createConfigTable(items),
        new Paragraph({ spacing: { after: 300 } })
    ];
}

function generateWorkflowSection(config) {
    const workflow = config.workflow || {};
    const sections = [];
    
    if (!workflow.workflow_name && !workflow.workflowName) {
        return sections;
    }
    
    const items = [
        { label: "Workflow Name", value: workflow.workflow_name || workflow.workflowName },
        { label: "State", value: workflow.state },
        { label: "Trigger Type", value: workflow.triggers?.[0]?.type || "-" },
        { label: "Trigger Method", value: workflow.triggers?.[0]?.method || "-" },
        { label: "Connection References", value: formatValue(workflow.connection_references || workflow.connectionReferences) }
    ];
    
    sections.push(createHeading("Workflow Configuration", HeadingLevel.HEADING_3));
    sections.push(createConfigTable(items));
    sections.push(new Paragraph({ spacing: { after: 200 } }));
    
    // Add workflow actions table
    const actions = workflow.actions || [];
    if (actions.length > 0) {
        sections.push(createHeading("Workflow Actions", HeadingLevel.HEADING_3));
        
        const actionRows = [
            new TableRow({ children: [
                createHeaderCell("Action Name", 2808),
                createHeaderCell("Type", 2340),
                createHeaderCell("Connection", 2340),
                createHeaderCell("Runs After", 1872)
            ]})
        ];
        
        actions.forEach((action, index) => {
            const fill = index % 2 === 1 ? ALT_ROW_FILL : "FFFFFF";
            const runAfter = Array.isArray(action.run_after || action.runAfter) 
                ? (action.run_after || action.runAfter).join(", ") 
                : "-";
            
            actionRows.push(new TableRow({ children: [
                createCell(action.name, 2808, fill),
                createCell(action.type, 2340, fill),
                createCell(action.connection || "-", 2340, fill),
                createCell(runAfter, 1872, fill)
            ]}));
        });
        
        sections.push(new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            columnWidths: [2808, 2340, 2340, 1872],
            rows: actionRows
        }));
        sections.push(new Paragraph({ spacing: { after: 300 } }));
    }
    
    return sections;
}

function generateConnectionsSection(config) {
    const connections = config.connections || [];
    const sections = [];
    
    if (connections.length === 0) {
        return sections;
    }
    
    sections.push(createHeading("API Connections", HeadingLevel.HEADING_3));
    sections.push(createParagraph("The Logic App uses the following managed API connections:"));
    
    connections.forEach((conn, index) => {
        const items = [
            { label: "Connection Name", value: conn.name },
            { label: "Type", value: conn.type },
            { label: "Display Name", value: conn.display_name || conn.displayName },
            { label: "Status", value: conn.status }
        ];
        
        if (conn.gateway) {
            items.push({ label: "Data Gateway", value: conn.gateway.name });
        }
        
        if (conn.sql_info || conn.sqlInfo) {
            const sqlInfo = conn.sql_info || conn.sqlInfo;
            items.push({ label: "SQL Server", value: sqlInfo.server });
            items.push({ label: "Database", value: sqlInfo.database });
            items.push({ label: "Authentication", value: sqlInfo.auth_type || sqlInfo.authType });
        }
        
        sections.push(createParagraph(`Connection ${index + 1}: ${conn.name}`));
        sections.push(createConfigTable(items));
        sections.push(new Paragraph({ spacing: { after: 200 } }));
    });
    
    return sections;
}

function generateDataGatewaySection(config) {
    const gateway = config.data_gateway || config.dataGateway || {};
    
    if (!gateway.name) {
        return [];
    }
    
    const items = [
        { label: "Gateway Name", value: gateway.name },
        { label: "Resource Group", value: gateway.resource_group || gateway.resourceGroup },
        { label: "Region", value: gateway.region || gateway.location },
        { label: "Type", value: gateway.type },
        { label: "Status", value: gateway.status },
        { label: "Host Machine", value: gateway.machine_name || gateway.machineName },
        { label: "Cluster Members", value: formatValue(gateway.cluster_members || gateway.clusterMembers) || "Single node" }
    ];
    
    return [
        createHeading("On-Premises Data Gateway", HeadingLevel.HEADING_2),
        createParagraph("The On-Premises Data Gateway provides secure connectivity between Azure Logic Apps and on-premises SQL Server."),
        createConfigTable(items),
        new Paragraph({ spacing: { after: 200 } }),
        createHeading("Firewall Requirements", HeadingLevel.HEADING_3),
        createParagraph("The Data Gateway requires the following outbound connectivity from the host server:"),
        createParagraph("• TCP 443 (HTTPS): Azure Service Bus relay"),
        createParagraph("• TCP 9350-9354: Service Bus connectivity"),
        createParagraph("• TCP 5671-5672: AMQP with TLS"),
        new Paragraph({ spacing: { after: 300 } })
    ];
}

function generateSqlSection(config) {
    // Extract SQL info from connections
    const connections = config.connections || [];
    const sqlConn = connections.find(c => c.type === 'sql' || c.sql_info || c.sqlInfo);
    
    if (!sqlConn) {
        return [];
    }
    
    const sqlInfo = sqlConn.sql_info || sqlConn.sqlInfo || {};
    
    const items = [
        { label: "Server Name", value: sqlInfo.server },
        { label: "Database Name", value: sqlInfo.database },
        { label: "Authentication", value: sqlInfo.auth_type || sqlInfo.authType },
        { label: "Port", value: sqlInfo.port || "1433" },
        { label: "TLS Encryption", value: "Enabled (TLS 1.2)" }
    ];
    
    return [
        createHeading("SQL Server Database", HeadingLevel.HEADING_2),
        createParagraph("The SQL Server database provides persistent data storage for the integration service."),
        createConfigTable(items),
        new Paragraph({ spacing: { after: 300 } })
    ];
}

function generateKeyVaultSection(config) {
    const kv = config.key_vault || config.keyVault || {};
    
    if (!kv.name) {
        return [];
    }
    
    const items = [
        { label: "Resource Name", value: kv.name },
        { label: "Resource Group", value: kv.resource_group || kv.resourceGroup },
        { label: "Region", value: kv.region || kv.location },
        { label: "SKU", value: kv.sku },
        { label: "Vault URI", value: kv.vault_uri || kv.vaultUri },
        { label: "Soft Delete", value: formatValue(kv.enable_soft_delete ?? kv.enableSoftDelete) },
        { label: "Purge Protection", value: formatValue(kv.enable_purge_protection ?? kv.enablePurgeProtection) },
        { label: "RBAC Authorization", value: formatValue(kv.enable_rbac_authorization ?? kv.enableRbacAuthorization) }
    ];
    
    const sections = [
        createHeading("Azure Key Vault", HeadingLevel.HEADING_2),
        createConfigTable(items),
        new Paragraph({ spacing: { after: 200 } })
    ];
    
    // Add secrets inventory
    const secrets = kv.secrets || [];
    if (secrets.length > 0) {
        sections.push(createHeading("Secrets Inventory", HeadingLevel.HEADING_3));
        
        const secretRows = [
            new TableRow({ children: [
                createHeaderCell("Secret Name", 4680),
                createHeaderCell("Enabled", 2340),
                createHeaderCell("Expiry", 2340)
            ]})
        ];
        
        secrets.forEach((secret, index) => {
            const fill = index % 2 === 1 ? ALT_ROW_FILL : "FFFFFF";
            secretRows.push(new TableRow({ children: [
                createCell(secret.name, 4680, fill),
                createCell(formatValue(secret.enabled), 2340, fill),
                createCell(secret.expires || "Never", 2340, fill)
            ]}));
        });
        
        sections.push(new Table({
            width: { size: 100, type: WidthType.PERCENTAGE },
            columnWidths: [4680, 2340, 2340],
            rows: secretRows
        }));
        sections.push(new Paragraph({ spacing: { after: 300 } }));
    }
    
    return sections;
}

function generateAppInsightsSection(config) {
    const ai = config.app_insights || config.appInsights || {};
    
    if (!ai.name) {
        return [];
    }
    
    const items = [
        { label: "Resource Name", value: ai.name },
        { label: "Resource Group", value: ai.resource_group || ai.resourceGroup },
        { label: "Region", value: ai.region || ai.location },
        { label: "Instrumentation Key", value: ai.instrumentation_key || ai.instrumentationKey },
        { label: "Connection String", value: (ai.connection_string || ai.connectionString || "").substring(0, 50) + "..." },
        { label: "Retention (Days)", value: ai.retention_in_days || ai.retentionInDays },
        { label: "Workspace Resource ID", value: ai.workspace_resource_id || ai.workspaceResourceId || "-" }
    ];
    
    return [
        createHeading("Application Insights", HeadingLevel.HEADING_2),
        createConfigTable(items),
        new Paragraph({ spacing: { after: 300 } })
    ];
}

function generateDocumentControlTable(config) {
    const meta = config.metadata || {};
    const api = config.api || {};
    
    return new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        columnWidths: [3120, 6240],
        rows: [
            new TableRow({ children: [createHeaderCell("Document Property", 3120), createHeaderCell("Value", 6240)] }),
            new TableRow({ children: [createCell("Document Title", 3120), createCell(`As-Built Documentation - ${api.display_name || api.displayName || api.name || 'API Service'}`, 6240)] }),
            new TableRow({ children: [createCell("Document Number", 3120, ALT_ROW_FILL), createCell(`ASBUILT-${(api.api_id || api.apiId || 'SERVICE').toUpperCase()}`, 6240, ALT_ROW_FILL)] }),
            new TableRow({ children: [createCell("Version", 3120), createCell("1.0", 6240)] }),
            new TableRow({ children: [createCell("Status", 3120, ALT_ROW_FILL), createCell("Generated - Pending Review", 6240, ALT_ROW_FILL)] }),
            new TableRow({ children: [createCell("Subscription", 3120), createCell(meta.subscription_name || meta.subscriptionName || "-", 6240)] }),
            new TableRow({ children: [createCell("Generated By", 3120, ALT_ROW_FILL), createCell("Azure As-Built Automation", 6240, ALT_ROW_FILL)] }),
            new TableRow({ children: [createCell("Generated Date", 3120), createCell(meta.collection_date || meta.collectionDate || new Date().toISOString(), 6240)] }),
        ]
    });
}

// === Main Document Generation ===

async function generateDocument(config, outputPath, options = {}) {
    const api = config.api || {};
    const serviceName = api.display_name || api.displayName || api.name || 'API Service';
    
    // Build document sections
    const children = [
        // Title Page
        new Paragraph({ spacing: { after: 2400 } }),
        new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: "AS-BUILT DOCUMENTATION", font: FONT, size: 56, bold: true, color: HEADER_FILL })]
        }),
        new Paragraph({ spacing: { after: 400 } }),
        new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: serviceName, font: FONT, size: 40, bold: true, color: "333333" })]
        }),
        new Paragraph({
            alignment: AlignmentType.CENTER,
            spacing: { after: 400 },
            children: [new TextRun({ text: "Azure API Integration Service", font: FONT, size: 28, color: "666666" })]
        }),
        new Paragraph({ spacing: { after: 1600 } }),
        generateDocumentControlTable(config),
        
        new Paragraph({ children: [new PageBreak()] }),
        
        // Table of Contents
        createHeading("Table of Contents", HeadingLevel.HEADING_1),
        new TableOfContents("Table of Contents", { hyperlink: true, headingStyleRange: "1-3" }),
        
        new Paragraph({ children: [new PageBreak()] }),
        
        // Executive Summary
        createHeading("Executive Summary", HeadingLevel.HEADING_1),
        createHeading("Service Overview", HeadingLevel.HEADING_2),
        createBoldParagraph("Service Name: ", serviceName),
        createBoldParagraph("API Path: ", api.path || "-"),
        createBoldParagraph("Environment: ", "Production"),
        createBoldParagraph("Region: ", config.apim?.region || config.apim?.location || "South Africa North"),
        createBoldParagraph("Generated: ", config.metadata?.collection_date || config.metadata?.collectionDate || new Date().toISOString()),
        new Paragraph({ spacing: { after: 200 } }),
        createParagraph("This As-Built document was automatically generated from the Azure resource configuration. It provides comprehensive technical documentation for the API integration service deployed to production."),
        
        new Paragraph({ children: [new PageBreak()] }),
        
        // Component Configuration
        createHeading("Component Configuration", HeadingLevel.HEADING_1),
        
        // APIM Section
        ...generateApimSection(config),
        
        // API Section
        ...generateApiSection(config),
        
        new Paragraph({ children: [new PageBreak()] }),
        
        // Logic Apps Section
        ...generateLogicAppSection(config),
        
        // Workflow Section
        ...generateWorkflowSection(config),
        
        // Connections Section
        ...generateConnectionsSection(config),
        
        new Paragraph({ children: [new PageBreak()] }),
        
        // Data Gateway Section
        ...generateDataGatewaySection(config),
        
        // SQL Section
        ...generateSqlSection(config),
        
        new Paragraph({ children: [new PageBreak()] }),
        
        // Security Configuration
        createHeading("Security Configuration", HeadingLevel.HEADING_1),
        
        // Key Vault Section
        ...generateKeyVaultSection(config),
        
        new Paragraph({ children: [new PageBreak()] }),
        
        // Monitoring Section
        createHeading("Monitoring and Alerting", HeadingLevel.HEADING_1),
        
        // App Insights Section
        ...generateAppInsightsSection(config),
        
        // Operational Procedures (template sections)
        new Paragraph({ children: [new PageBreak()] }),
        createHeading("Operational Procedures", HeadingLevel.HEADING_1),
        createHeading("Routine Maintenance", HeadingLevel.HEADING_2),
        createParagraph("• Daily: Review Application Insights for errors and anomalies"),
        createParagraph("• Weekly: Review Data Gateway health and logs"),
        createParagraph("• Monthly: Review and rotate secrets approaching expiration"),
        createParagraph("• Quarterly: Review WAF rule effectiveness and update as needed"),
        new Paragraph({ spacing: { after: 200 } }),
        
        createHeading("Incident Response", HeadingLevel.HEADING_2),
        createParagraph("• Severity 1 (Critical): Service completely unavailable - Response within 15 minutes"),
        createParagraph("• Severity 2 (High): Significant degradation - Response within 1 hour"),
        createParagraph("• Severity 3 (Medium): Minor issues - Response within 4 hours"),
        createParagraph("• Severity 4 (Low): Informational - Response within 24 hours"),
    ];
    
    // Create document
    const doc = new Document({
        styles: {
            default: { document: { run: { font: FONT, size: 22 } } },
            paragraphStyles: [
                { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
                    run: { size: 36, bold: true, font: FONT, color: HEADER_FILL },
                    paragraph: { spacing: { before: 360, after: 240 }, outlineLevel: 0 } },
                { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
                    run: { size: 28, bold: true, font: FONT, color: "333333" },
                    paragraph: { spacing: { before: 280, after: 180 }, outlineLevel: 1 } },
                { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
                    run: { size: 24, bold: true, font: FONT, color: "555555" },
                    paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 2 } },
            ]
        },
        sections: [{
            properties: {
                page: {
                    size: { width: 12240, height: 15840 },
                    margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
                }
            },
            headers: {
                default: new Header({
                    children: [new Paragraph({
                        children: [
                            new TextRun({ text: "As-Built Documentation | ", font: FONT, size: 18, color: "666666" }),
                            new TextRun({ text: serviceName, font: FONT, size: 18, color: "666666", bold: true }),
                            new TextRun({ text: " | CONFIDENTIAL", font: FONT, size: 18, color: "CC0000" })
                        ],
                        alignment: AlignmentType.RIGHT
                    })]
                })
            },
            footers: {
                default: new Footer({
                    children: [new Paragraph({
                        children: [
                            new TextRun({ text: "Bios Data Center | ", font: FONT, size: 18, color: "666666" }),
                            new TextRun({ text: "Page ", font: FONT, size: 18, color: "666666" }),
                            new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 18, color: "666666" }),
                            new TextRun({ text: " of ", font: FONT, size: 18, color: "666666" }),
                            new TextRun({ children: [PageNumber.TOTAL_PAGES], font: FONT, size: 18, color: "666666" })
                        ],
                        alignment: AlignmentType.CENTER
                    })]
                })
            },
            children: children
        }]
    });
    
    // Save document
    const buffer = await Packer.toBuffer(doc);
    fs.writeFileSync(outputPath, buffer);
    
    console.log(`Document generated: ${outputPath}`);
    return outputPath;
}

// === CLI Entry Point ===

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 1) {
        console.log("Usage: node generate_asbuilt_document.js <config.json> [output.docx]");
        console.log("");
        console.log("Arguments:");
        console.log("  config.json   Path to the collected Azure configuration JSON");
        console.log("  output.docx   Path for the generated Word document (optional)");
        process.exit(1);
    }
    
    const configPath = args[0];
    
    if (!fs.existsSync(configPath)) {
        console.error(`Error: Configuration file not found: ${configPath}`);
        process.exit(1);
    }
    
    // Load configuration
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    
    // Determine output path
    const outputPath = args[1] || configPath.replace('.json', '_AsBuilt.docx');
    
    // Generate document
    await generateDocument(config, outputPath);
}

// Run if called directly
if (require.main === module) {
    main().catch(err => {
        console.error("Error:", err);
        process.exit(1);
    });
}

module.exports = { generateDocument };
