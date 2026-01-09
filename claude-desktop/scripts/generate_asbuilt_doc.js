/**
 * Azure As-Built Document Generator
 * Windows/Cross-platform compatible
 * 
 * Usage:
 *   node generate_asbuilt_doc.js <config.json> <output.docx> [--diagram <diagram.png>]
 * 
 * Author: Bios Data Center
 * Version: 2.0 (Windows Compatible)
 */

const fs = require('fs');
const path = require('path');

// Check for docx module
let docx;
try {
    docx = require('docx');
} catch (e) {
    console.error('ERROR: docx module not found. Install it with: npm install docx');
    process.exit(1);
}

const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, ImageRun,
        Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType, 
        ShadingType, PageNumber, PageBreak, TableOfContents } = docx;

// Styling
const FONT = "Arial";
const HEADER_FILL = "1E3A5F";
const ALT_ROW_FILL = "F5F5F5";
const BORDER = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const BORDERS = { top: BORDER, bottom: BORDER, left: BORDER, right: BORDER };

// Helpers
function headerCell(text, width = 3120) {
    return new TableCell({
        borders: BORDERS,
        width: { size: width, type: WidthType.DXA },
        shading: { fill: HEADER_FILL, type: ShadingType.CLEAR },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        children: [new Paragraph({ 
            children: [new TextRun({ text: String(text || ""), bold: true, color: "FFFFFF", font: FONT, size: 20 })] 
        })]
    });
}

function cell(text, width = 3120, fill = "FFFFFF") {
    return new TableCell({
        borders: BORDERS,
        width: { size: width, type: WidthType.DXA },
        shading: { fill, type: ShadingType.CLEAR },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        children: [new Paragraph({ 
            children: [new TextRun({ text: String(text ?? "N/A"), font: FONT, size: 20 })] 
        })]
    });
}

function heading(text, level) {
    return new Paragraph({
        heading: level,
        children: [new TextRun({ text, font: FONT })]
    });
}

function para(text, opts = {}) {
    return new Paragraph({
        spacing: opts.spacing || { after: 200 },
        alignment: opts.alignment,
        children: [new TextRun({ 
            text, 
            font: FONT, 
            size: opts.size || 22,
            bold: opts.bold,
            italics: opts.italics,
            color: opts.color
        })]
    });
}

function kvTable(data, title = null) {
    const rows = [];
    if (title) {
        rows.push(new TableRow({ children: [headerCell(title, 9360)] }));
    }
    rows.push(new TableRow({ children: [headerCell("Property", 3120), headerCell("Value", 6240)] }));
    
    let alt = false;
    for (const [key, val] of Object.entries(data || {})) {
        if (val !== null && val !== undefined && typeof val !== 'object') {
            const fill = alt ? ALT_ROW_FILL : "FFFFFF";
            const displayKey = key.replace(/_/g, ' ').replace(/([A-Z])/g, ' $1').trim();
            rows.push(new TableRow({ children: [cell(displayKey, 3120, fill), cell(String(val), 6240, fill)] }));
            alt = !alt;
        }
    }
    
    return new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, columnWidths: [3120, 6240], rows });
}

function formatDate(d) {
    if (!d) return "N/A";
    try {
        return new Date(d).toLocaleDateString('en-ZA', { year: 'numeric', month: 'long', day: 'numeric' });
    } catch { return d; }
}

async function generateDocument(config, outputPath, diagramPath = null) {
    const meta = config.metadata || {};
    const svc = config.service || {};
    const shared = config.shared_infrastructure || {};
    
    const serviceName = meta.service_name || "[SERVICE NAME]";
    const env = meta.environment || "Production";
    const collectionDate = formatDate(meta.collection_date);
    
    // Load diagram
    let diagramImage = null;
    if (diagramPath && fs.existsSync(diagramPath)) {
        diagramImage = fs.readFileSync(diagramPath);
    }
    
    const children = [];
    
    // === TITLE PAGE ===
    children.push(new Paragraph({ spacing: { after: 2400 } }));
    children.push(new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "AS-BUILT DOCUMENTATION", font: FONT, size: 56, bold: true, color: HEADER_FILL })]
    }));
    children.push(new Paragraph({ spacing: { after: 400 } }));
    children.push(new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: serviceName, font: FONT, size: 40, bold: true, color: "333333" })]
    }));
    children.push(new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 400 },
        children: [new TextRun({ text: "Azure API Integration Service", font: FONT, size: 28, color: "666666" })]
    }));
    children.push(new Paragraph({ spacing: { after: 1600 } }));
    
    // Doc info table
    children.push(new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        columnWidths: [3120, 6240],
        rows: [
            new TableRow({ children: [headerCell("Document Property", 3120), headerCell("Value", 6240)] }),
            new TableRow({ children: [cell("Service Name", 3120), cell(serviceName, 6240)] }),
            new TableRow({ children: [cell("Environment", 3120, ALT_ROW_FILL), cell(env, 6240, ALT_ROW_FILL)] }),
            new TableRow({ children: [cell("Subscription", 3120), cell(meta.subscription || "N/A", 6240)] }),
            new TableRow({ children: [cell("Collection Date", 3120, ALT_ROW_FILL), cell(collectionDate, 6240, ALT_ROW_FILL)] }),
            new TableRow({ children: [cell("Document Version", 3120), cell("1.0", 6240)] }),
        ]
    }));
    
    children.push(new Paragraph({ children: [new PageBreak()] }));
    
    // === TOC ===
    children.push(heading("Table of Contents", HeadingLevel.HEADING_1));
    children.push(new TableOfContents("Table of Contents", { hyperlink: true, headingStyleRange: "1-3" }));
    children.push(new Paragraph({ children: [new PageBreak()] }));
    
    // === EXECUTIVE SUMMARY ===
    children.push(heading("Executive Summary", HeadingLevel.HEADING_1));
    children.push(heading("Purpose", HeadingLevel.HEADING_2));
    children.push(para(`This As-Built document provides comprehensive technical documentation for the ${serviceName} API integration service.`));
    
    children.push(heading("Service Overview", HeadingLevel.HEADING_2));
    children.push(kvTable({
        "Service Name": serviceName,
        "Environment": env,
        "Region": svc.apim?.region || svc.logic_app?.region || "South Africa North",
        "APIM Instance": svc.apim?.resource_name,
        "API Name": svc.api?.name,
        "Backend Type": svc.logic_app?.type || "Logic App"
    }));
    
    // === ARCHITECTURE ===
    children.push(new Paragraph({ children: [new PageBreak()] }));
    children.push(heading("Architecture Overview", HeadingLevel.HEADING_1));
    
    if (diagramImage) {
        children.push(heading("Architecture Diagram", HeadingLevel.HEADING_2));
        children.push(new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new ImageRun({
                type: "png",
                data: diagramImage,
                transformation: { width: 580, height: 320 },
                altText: { title: "Architecture", description: "Service Architecture", name: "arch" }
            })]
        }));
        children.push(para("Figure 1: Service Architecture", { alignment: AlignmentType.CENTER, italics: true, color: "666666" }));
    }
    
    children.push(heading("Data Flow", HeadingLevel.HEADING_2));
    children.push(para("1. API consumers send HTTPS requests to Azure Front Door."));
    children.push(para("2. Front Door routes traffic through WAF for security inspection."));
    children.push(para("3. WAF validates requests and passes to API Management."));
    children.push(para("4. APIM authenticates, applies policies, and routes to the backend Logic App."));
    children.push(para("5. Logic App executes business logic and connects to on-premises SQL via Data Gateway."));
    children.push(para("6. Response flows back through the same path to the consumer."));
    
    // === SHARED INFRASTRUCTURE ===
    children.push(new Paragraph({ children: [new PageBreak()] }));
    children.push(heading("Shared Infrastructure", HeadingLevel.HEADING_1));
    children.push(para("These components are shared across multiple API services.", { italics: true, color: "666666" }));
    
    if (shared.front_door) {
        children.push(heading("Azure Front Door", HeadingLevel.HEADING_2));
        children.push(kvTable(shared.front_door));
    }
    
    if (shared.waf) {
        children.push(new Paragraph({ spacing: { after: 300 } }));
        children.push(heading("Web Application Firewall (WAF)", HeadingLevel.HEADING_2));
        children.push(kvTable(shared.waf));
    }
    
    // === APIM ===
    children.push(new Paragraph({ children: [new PageBreak()] }));
    children.push(heading("API Management Configuration", HeadingLevel.HEADING_1));
    
    if (svc.apim) {
        children.push(heading("APIM Instance", HeadingLevel.HEADING_2));
        children.push(kvTable({
            "Resource Name": svc.apim.resource_name,
            "Resource Group": svc.apim.resource_group,
            "Region": svc.apim.region,
            "SKU": svc.apim.sku,
            "Capacity": svc.apim.capacity,
            "Gateway URL": svc.apim.gateway_url,
            "Developer Portal": svc.apim.developer_portal_url,
            "VNet Type": svc.apim.virtual_network_type,
            "Identity Type": svc.apim.identity?.type
        }));
    }
    
    if (svc.api) {
        children.push(new Paragraph({ spacing: { after: 300 } }));
        children.push(heading("API Definition", HeadingLevel.HEADING_2));
        children.push(kvTable({
            "API Name": svc.api.name,
            "Display Name": svc.api.display_name,
            "Path": svc.api.path,
            "Service URL": svc.api.service_url,
            "Protocols": Array.isArray(svc.api.protocols) ? svc.api.protocols.join(", ") : svc.api.protocols,
            "Subscription Required": svc.api.subscription_required
        }));
        
        // Operations
        if (svc.api.operations?.length > 0) {
            children.push(new Paragraph({ spacing: { after: 200 } }));
            children.push(heading("API Operations", HeadingLevel.HEADING_3));
            
            const opRows = [new TableRow({ children: [
                headerCell("Method", 1560), headerCell("Path", 3900), headerCell("Name", 3900)
            ]})];
            
            let alt = false;
            for (const op of svc.api.operations) {
                const fill = alt ? ALT_ROW_FILL : "FFFFFF";
                opRows.push(new TableRow({ children: [
                    cell(op.method || "GET", 1560, fill),
                    cell(op.url_template || op.urlTemplate || "/", 3900, fill),
                    cell(op.name || op.display_name, 3900, fill)
                ]}));
                alt = !alt;
            }
            
            children.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, columnWidths: [1560, 3900, 3900], rows: opRows }));
        }
    }
    
    // === LOGIC APP ===
    children.push(new Paragraph({ children: [new PageBreak()] }));
    children.push(heading("Logic App Configuration", HeadingLevel.HEADING_1));
    
    if (svc.logic_app) {
        children.push(heading("Logic App Instance", HeadingLevel.HEADING_2));
        children.push(kvTable({
            "Resource Name": svc.logic_app.resource_name,
            "Resource Group": svc.logic_app.resource_group,
            "Type": svc.logic_app.type,
            "Region": svc.logic_app.region,
            "State": svc.logic_app.state,
            "Hostname": svc.logic_app.default_hostname,
            "Identity Type": svc.logic_app.identity?.type
        }));
    }
    
    // Workflow
    if (svc.workflow) {
        children.push(new Paragraph({ spacing: { after: 300 } }));
        children.push(heading(`Workflow: ${svc.workflow.name || "Main"}`, HeadingLevel.HEADING_2));
        
        const parsed = svc.workflow.parsed || svc.workflow;
        
        // Triggers
        if (parsed.triggers?.length > 0) {
            children.push(heading("Trigger", HeadingLevel.HEADING_3));
            for (const t of parsed.triggers) {
                children.push(para(`${t.name} (${t.type}): ${t.description}`));
            }
        }
        
        // Actions
        if (parsed.actions?.length > 0) {
            children.push(new Paragraph({ spacing: { after: 200 } }));
            children.push(heading("Workflow Actions", HeadingLevel.HEADING_3));
            
            const actRows = [new TableRow({ children: [
                headerCell("Step", 780), headerCell("Action", 2340), headerCell("Type", 1560), headerCell("Description", 4680)
            ]})];
            
            let step = 1, alt = false;
            for (const a of parsed.actions) {
                const fill = alt ? ALT_ROW_FILL : "FFFFFF";
                actRows.push(new TableRow({ children: [
                    cell(String(step++), 780, fill),
                    cell(a.name, 2340, fill),
                    cell(a.type, 1560, fill),
                    cell(a.description || "", 4680, fill)
                ]}));
                alt = !alt;
            }
            
            children.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, columnWidths: [780, 2340, 1560, 4680], rows: actRows }));
        }
        
        // Data sources
        if (parsed.data_sources?.length > 0) {
            children.push(new Paragraph({ spacing: { after: 200 } }));
            children.push(heading("Data Sources", HeadingLevel.HEADING_3));
            for (const ds of parsed.data_sources) {
                children.push(para(`${ds.type}: ${ds.operation || 'query'}`));
            }
        }
    }
    
    // === CONNECTIONS ===
    children.push(new Paragraph({ children: [new PageBreak()] }));
    children.push(heading("Data Connectivity", HeadingLevel.HEADING_1));
    
    if (svc.connections?.length > 0) {
        children.push(heading("API Connections", HeadingLevel.HEADING_2));
        
        const connRows = [new TableRow({ children: [
            headerCell("Connection Name", 2340), headerCell("Type", 2340), headerCell("Status", 1560), headerCell("Details", 3120)
        ]})];
        
        let alt = false;
        for (const c of svc.connections) {
            const fill = alt ? ALT_ROW_FILL : "FFFFFF";
            let details = "";
            if (c.sql_server) details = `Server: ${c.sql_server}`;
            if (c.database) details += `, DB: ${c.database}`;
            if (c.gateway) details = `Gateway: ${c.gateway.name || c.gateway}`;
            
            connRows.push(new TableRow({ children: [
                cell(c.name, 2340, fill),
                cell(c.type, 2340, fill),
                cell(c.status || "Connected", 1560, fill),
                cell(details || "N/A", 3120, fill)
            ]}));
            alt = !alt;
        }
        
        children.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, columnWidths: [2340, 2340, 1560, 3120], rows: connRows }));
    }
    
    // Data Gateway
    if (svc.data_gateway) {
        children.push(new Paragraph({ spacing: { after: 300 } }));
        children.push(heading("On-Premises Data Gateway", HeadingLevel.HEADING_2));
        children.push(kvTable({
            "Gateway Name": svc.data_gateway.name,
            "Resource Group": svc.data_gateway.resource_group,
            "Region": svc.data_gateway.region,
            "Gateway Type": svc.data_gateway.type,
            "Host Machine": svc.data_gateway.machine_name
        }));
        
        children.push(new Paragraph({ spacing: { after: 200 } }));
        children.push(heading("Firewall Requirements", HeadingLevel.HEADING_3));
        children.push(para("TCP 443 (HTTPS) - Azure Service Bus relay"));
        children.push(para("TCP 9350-9354 - Service Bus connectivity"));
        children.push(para("TCP 5671-5672 - AMQP with TLS"));
    }
    
    // === KEY VAULT ===
    if (svc.key_vault) {
        children.push(new Paragraph({ children: [new PageBreak()] }));
        children.push(heading("Security Configuration", HeadingLevel.HEADING_1));
        children.push(heading("Azure Key Vault", HeadingLevel.HEADING_2));
        children.push(kvTable({
            "Vault Name": svc.key_vault.name,
            "Resource Group": svc.key_vault.resource_group,
            "Region": svc.key_vault.region,
            "SKU": svc.key_vault.sku,
            "Vault URI": svc.key_vault.vault_uri,
            "Soft Delete": svc.key_vault.soft_delete_enabled ? "Enabled" : "Disabled",
            "Purge Protection": svc.key_vault.purge_protection ? "Enabled" : "Disabled"
        }));
        
        if (svc.key_vault.secrets?.length > 0) {
            children.push(new Paragraph({ spacing: { after: 200 } }));
            children.push(heading("Secrets Inventory", HeadingLevel.HEADING_3));
            
            const secRows = [new TableRow({ children: [headerCell("Secret Name", 6240), headerCell("Enabled", 3120)] })];
            let alt = false;
            for (const s of svc.key_vault.secrets) {
                const fill = alt ? ALT_ROW_FILL : "FFFFFF";
                secRows.push(new TableRow({ children: [
                    cell(s.name, 6240, fill),
                    cell(s.enabled ? "Yes" : "No", 3120, fill)
                ]}));
                alt = !alt;
            }
            
            children.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, columnWidths: [6240, 3120], rows: secRows }));
        }
    }
    
    // === APP INSIGHTS ===
    if (svc.app_insights) {
        children.push(new Paragraph({ children: [new PageBreak()] }));
        children.push(heading("Monitoring Configuration", HeadingLevel.HEADING_1));
        children.push(heading("Application Insights", HeadingLevel.HEADING_2));
        children.push(kvTable({
            "Resource Name": svc.app_insights.name,
            "Resource Group": svc.app_insights.resource_group,
            "Region": svc.app_insights.region,
            "Instrumentation Key": svc.app_insights.instrumentation_key,
            "Workspace ID": svc.app_insights.workspace_id,
            "Retention Days": svc.app_insights.retention_days
        }));
    }
    
    // === BUILD DOCUMENT ===
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
                page: { size: { width: 12240, height: 15840 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } }
            },
            headers: {
                default: new Header({
                    children: [new Paragraph({
                        children: [
                            new TextRun({ text: `As-Built: ${serviceName}`, font: FONT, size: 18, color: "666666" }),
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
                            new TextRun({ text: "Bios Data Center | Page ", font: FONT, size: 18, color: "666666" }),
                            new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 18, color: "666666" }),
                            new TextRun({ text: " of ", font: FONT, size: 18, color: "666666" }),
                            new TextRun({ children: [PageNumber.TOTAL_PAGES], font: FONT, size: 18, color: "666666" })
                        ],
                        alignment: AlignmentType.CENTER
                    })]
                })
            },
            children
        }]
    });
    
    const buffer = await Packer.toBuffer(doc);
    fs.writeFileSync(outputPath, buffer);
    console.log(`Document generated: ${outputPath}`);
    return outputPath;
}

// CLI
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 2) {
        console.log("Azure As-Built Document Generator");
        console.log("");
        console.log("Usage: node generate_asbuilt_doc.js <config.json> <output.docx> [--diagram <image.png>]");
        console.log("");
        console.log("Examples:");
        console.log("  node generate_asbuilt_doc.js config.json AsBuilt.docx");
        console.log("  node generate_asbuilt_doc.js config.json AsBuilt.docx --diagram architecture.png");
        process.exit(1);
    }
    
    const configPath = args[0];
    const outputPath = args[1];
    let diagramPath = null;
    
    const diagIdx = args.indexOf('--diagram');
    if (diagIdx !== -1 && args[diagIdx + 1]) {
        diagramPath = args[diagIdx + 1];
    }
    
    // Handle glob patterns on Windows (config_*.json)
    let actualConfigPath = configPath;
    if (configPath.includes('*')) {
        const dir = path.dirname(configPath);
        const pattern = path.basename(configPath).replace('*', '');
        const files = fs.readdirSync(dir).filter(f => f.includes(pattern.replace('.json', '')) && f.endsWith('.json'));
        if (files.length > 0) {
            // Get most recent
            actualConfigPath = path.join(dir, files.sort().pop());
            console.log(`Using config file: ${actualConfigPath}`);
        }
    }
    
    if (!fs.existsSync(actualConfigPath)) {
        console.error(`Config file not found: ${actualConfigPath}`);
        process.exit(1);
    }
    
    const config = JSON.parse(fs.readFileSync(actualConfigPath, 'utf8'));
    await generateDocument(config, outputPath, diagramPath);
}

module.exports = { generateDocument };

if (require.main === module) {
    main().catch(err => {
        console.error('Error:', err.message);
        process.exit(1);
    });
}
