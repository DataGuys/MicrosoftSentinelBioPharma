#!/bin/bash
# Bio-Pharmaceutical System Connector Configuration Script - Improved Version
# This script configures data connectors for specialized bio-pharma systems

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default parameters
RESOURCE_GROUP=""
PREFIX=""
SYSTEMS=("ELN" "LIMS" "CTMS" "MES" "PV" "INSTRUMENTS" "COLDCHAIN")
LOG_DIRS=()  # Will be populated based on systems

# Parse command line arguments
function parse_args() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -g|--resource-group)
                RESOURCE_GROUP="$2"
                shift
                shift
                ;;
            -p|--prefix)
                PREFIX="$2"
                shift
                shift
                ;;
            -s|--systems)
                IFS=',' read -r -a SYSTEMS <<< "$2"
                shift
                shift
                ;;
            -d|--log-dirs)
                IFS=',' read -r -a LOG_DIRS <<< "$2"
                shift
                shift
                ;;
            -h|--help)
                echo "Usage: $0 -g <resource-group> -p <prefix> [-s <comma-separated-systems>] [-d <comma-separated-log-dirs>]"
                echo ""
                echo "Options:"
                echo "  -g, --resource-group   Resource group containing the Sentinel workspaces"
                echo "  -p, --prefix           Prefix used for resource naming"
                echo "  -s, --systems          Comma-separated list of systems to configure (default: ELN,LIMS,CTMS,MES,PV,INSTRUMENTS,COLDCHAIN)"
                echo "  -d, --log-dirs         Comma-separated list of log directories (must match systems count if provided)"
                echo "  -h, --help             Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Verify required parameters
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$PREFIX" ]; then
        echo -e "${RED}Error: resource group and prefix are required.${NC}"
        echo "Usage: $0 -g <resource-group> -p <prefix> [-s <comma-separated-systems>] [-d <comma-separated-log-dirs>]"
        exit 1
    fi
    
    # If log directories are provided, verify the count matches systems
    if [ ${#LOG_DIRS[@]} -gt 0 ] && [ ${#LOG_DIRS[@]} -ne ${#SYSTEMS[@]} ]; then
        echo -e "${RED}Error: The number of log directories must match the number of systems.${NC}"
        exit 1
    fi
    
    # If log directories are not provided, set defaults
    if [ ${#LOG_DIRS[@]} -eq 0 ]; then
        for system in "${SYSTEMS[@]}"; do
            case "$system" in
                "ELN")
                    LOG_DIRS+=("/var/log/eln,C:\\ProgramData\\ELN\\logs")
                    ;;
                "LIMS")
                    LOG_DIRS+=("/var/log/lims,C:\\ProgramData\\LIMS\\logs")
                    ;;
                "CTMS")
                    LOG_DIRS+=("/var/log/ctms,C:\\ProgramData\\CTMS\\logs")
                    ;;
                "MES")
                    LOG_DIRS+=("/var/log/mes,C:\\ProgramData\\MES\\logs")
                    ;;
                "PV")
                    LOG_DIRS+=("/var/log/pv,C:\\ProgramData\\PV\\logs")
                    ;;
                "INSTRUMENTS")
                    LOG_DIRS+=("/var/log/instruments,C:\\ProgramData\\Instruments\\logs")
                    ;;
                "COLDCHAIN")
                    LOG_DIRS+=("/var/log/coldchain,C:\\ProgramData\\ColdChain\\logs")
                    ;;
                *)
                    LOG_DIRS+=("/var/log/${system,,},C:\\ProgramData\\${system}\\logs")
                    ;;
            esac
        done
    fi
}

# Check dependencies
function check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        echo -e "${RED}Error: Azure CLI is not installed. Please install it and try again.${NC}"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed. Please install it and try again.${NC}"
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        echo -e "${RED}Error: Not logged in to Azure. Please run 'az login' first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All dependencies satisfied.${NC}"
}

# Validate workspaces
function validate_workspaces() {
    echo -e "${BLUE}Validating workspaces...${NC}"
    
    # Workspace names based on prefix
    local sentinel_ws="${PREFIX}-sentinel-ws"
    local research_ws="${PREFIX}-research-ws"
    local manufacturing_ws="${PREFIX}-manufacturing-ws"
    local clinical_ws="${PREFIX}-clinical-ws"
    
    # Check sentinel workspace
    if ! az monitor log-analytics workspace show --workspace-name "$sentinel_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${RED}Error: Sentinel workspace '$sentinel_ws' not found in resource group '$RESOURCE_GROUP'.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Sentinel workspace:${NC} $sentinel_ws"
    
    # Check specialized workspaces
    if ! az monitor log-analytics workspace show --workspace-name "$research_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}⚠ Warning: Research workspace '$research_ws' not found. Configuration will be limited.${NC}"
    else
        echo -e "${GREEN}✓ Research workspace:${NC} $research_ws"
    fi
    
    if ! az monitor log-analytics workspace show --workspace-name "$manufacturing_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}⚠ Warning: Manufacturing workspace '$manufacturing_ws' not found. Configuration will be limited.${NC}"
    else
        echo -e "${GREEN}✓ Manufacturing workspace:${NC} $manufacturing_ws"
    fi
    
    if ! az monitor log-analytics workspace show --workspace-name "$clinical_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}⚠ Warning: Clinical workspace '$clinical_ws' not found. Configuration will be limited.${NC}"
    else
        echo -e "${GREEN}✓ Clinical workspace:${NC} $clinical_ws"
    fi
}

# Deploy Data Collection Endpoint
function deploy_dce() {
    echo -e "${BLUE}Deploying Data Collection Endpoint...${NC}"
    
    local dce_name="${PREFIX}-biopharma-dce"
    local location=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    
    # Check if DCE already exists
    if az monitor data-collection endpoint show --name "$dce_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}Data Collection Endpoint '$dce_name' already exists. Skipping creation.${NC}"
        
        # Get DCE ID
        local dce_id=$(az monitor data-collection endpoint show --name "$dce_name" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
        echo -e "${GREEN}Using existing DCE:${NC} $dce_id"
    else
        # Create DCE
        echo -e "${BLUE}Creating new Data Collection Endpoint...${NC}"
        az monitor data-collection endpoint create --name "$dce_name" --resource-group "$RESOURCE_GROUP" --location "$location" --public-network-access "Enabled" --tags "purpose=biopharma"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create Data Collection Endpoint.${NC}"
            exit 1
        fi
        
        # Get DCE ID
        local dce_id=$(az monitor data-collection endpoint show --name "$dce_name" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
        echo -e "${GREEN}Created new DCE:${NC} $dce_id"
    fi
    
    # Return DCE ID
    echo "$dce_id"
}

# Configure system DCR - unified function for all systems
function configure_system_dcr() {
    local system_type="$1"
    local dce_id="$2"
    local log_dirs="$3"
    
    echo -e "${BLUE}Configuring $system_type system connector...${NC}"
    
    local dcr_name="${PREFIX}-dcr-${system_type,,}-system"
    local sentinel_ws="${PREFIX}-sentinel-ws"
    local location=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    
    # Determine which specialized workspace to use based on system type
    local specialized_ws=""
    local data_flow_kql=""
    local system_tags=""
    
    case "$system_type" in
        "ELN" | "LIMS")
            specialized_ws="${PREFIX}-research-ws"
            data_flow_kql="source | where RawData has_any (\"Authentication\", \"Authorization\", \"Permission\", \"Access\", \"Copy\", \"Download\", \"Print\") or RawData has_any (\"Failed\", \"Error\", \"Warning\", \"Critical\", \"Denied\")"
            system_tags='{\"dataType\":\"'$system_type'\",\"system\":\"Research-System\",\"regulatory\":\"IP-Protection,21CFR11\"}'
            ;;
        "CTMS" | "PV")
            specialized_ws="${PREFIX}-clinical-ws"
            data_flow_kql="source | where RawData has_any (\"Authentication\", \"Authorization\", \"Permission\", \"Access\", \"PHI\", \"PII\", \"Subject\", \"Patient\") or RawData has_any (\"Failed\", \"Error\", \"Warning\", \"Critical\", \"Denied\") | extend MaskedData = replace_regex(RawData, @\"\\\\b\\\\d{3}-\\\\d{2}-\\\\d{4}\\\\b\", \"***-**-****\") | extend MaskedData = replace_regex(MaskedData, @\"\\\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Za-z]{2,}\\\\b\", \"****@*****\") | project-away RawData | project-rename RawData = MaskedData"
            system_tags='{\"dataType\":\"'$system_type'\",\"system\":\"Clinical-System\",\"regulatory\":\"HIPAA,GDPR,21CFR11\"}'
            ;;
        "MES" | "INSTRUMENTS")
            specialized_ws="${PREFIX}-manufacturing-ws"
            data_flow_kql="source | where RawData has_any (\"Authentication\", \"Authorization\", \"Configuration\", \"Recipe\", \"Parameter\", \"Change\", \"Role\") or RawData has_any (\"Failed\", \"Error\", \"Warning\", \"Critical\", \"Denied\", \"Validation\") | extend CFRCompliance = \"21CFR11\" | extend RecordIntegrityHash = hash_sha256(RawData)"
            system_tags='{\"dataType\":\"'$system_type'\",\"system\":\"Manufacturing-System\",\"regulatory\":\"21CFR11,GxP\"}'
            ;;
        "COLDCHAIN")
            specialized_ws="${PREFIX}-manufacturing-ws"
            data_flow_kql="source | where RawData has_any (\"Temperature\", \"Threshold\", \"Alert\", \"Deviation\", \"Configuration\") or RawData has_any (\"Failed\", \"Error\", \"Warning\", \"Critical\")"
            system_tags='{\"dataType\":\"'$system_type'\",\"system\":\"Supply-Chain\",\"regulatory\":\"21CFR11,GxP\"}'
            ;;
        *)
            specialized_ws="${PREFIX}-sentinel-ws"
            data_flow_kql="source"
            system_tags='{\"dataType\":\"'$system_type'\",\"system\":\"Custom-System\"}'
            ;;
    esac
    
    # Check if specialized workspace exists
    if ! az monitor log-analytics workspace show --workspace-name "$specialized_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}Warning: Specialized workspace '$specialized_ws' not found. Using sentinel workspace only.${NC}"
        specialized_ws=""
    fi
    
    # Split log directories
    IFS=',' read -r -a log_dir_array <<< "$log_dirs"
    
    # Create file pattern JSON array
    local file_patterns="["
    for dir in "${log_dir_array[@]}"; do
        file_patterns+="\"$dir/*.log\","
    done
    file_patterns=${file_patterns%,}
    file_patterns+="]"
    
    # Check if DCR already exists
    if az monitor data-collection rule show --name "$dcr_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}Data Collection Rule '$dcr_name' already exists. Skipping creation.${NC}"
        return 0
    fi
    
    # Create DCR template based on system type
    local dcr_template=""
    
    # Base template with sentinel destination
    dcr_template=$(cat << EOF
{
  "location": "$location",
  "properties": {
    "dataCollectionEndpointId": "$dce_id",
    "description": "Collects data from $system_type system with data tiering for cost optimization",
    "dataSources": {
      "logFiles": [
        {
          "name": "${system_type,,}Logs",
          "streams": ["Custom-${system_type}_CL"],
          "filePatterns": $file_patterns,
          "format": "text",
          "settings": {
            "text": {
              "recordStartTimestampFormat": "ISO 8601"
            }
          }
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "workspaceResourceId": "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$sentinel_ws",
          "name": "sentinelDestination"
        },
        {
          "workspaceResourceId": "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$sentinel_ws",
          "name": "sentinelAuxDestination",
          "dataTypeTier": "Basic"
        }
EOF
    
    # Add specialized workspace if it exists
    if [ -n "$specialized_ws" ]; then
        dcr_template+=",
        {
          \"workspaceResourceId\": \"/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$specialized_ws\",
          \"name\": \"specializedDestination\"
        }"
    fi
    
    # Close destinations section
    dcr_template+="
      ]
    },"
    
    # Add data flows section
    dcr_template+="
    \"dataFlows\": [
      {
        \"streams\": [\"Custom-${system_type}_CL\"],
        \"destinations\": [\"sentinelDestination\"],
        \"transformKql\": \"$data_flow_kql | where not(RawData has_any (\\\"INFO\\\", \\\"Debug\\\", \\\"Verbose\\\", \\\"Trace\\\"))\"
      },
      {
        \"streams\": [\"Custom-${system_type}_CL\"],
        \"destinations\": [\"sentinelAuxDestination\"],
        \"transformKql\": \"source | where RawData has_any (\\\"INFO\\\", \\\"Debug\\\", \\\"Verbose\\\", \\\"Trace\\\") | where not(RawData has_any (\\\"Error\\\", \\\"Failed\\\", \\\"Critical\\\", \\\"Warning\\\")) | extend LogType = \\\"Verbose\\\" | extend Source = \\\"${system_type}\\\"\"
      }"
    
    # Add specialized destination if it exists
    if [ -n "$specialized_ws" ]; then
        dcr_template+=",
      {
        \"streams\": [\"Custom-${system_type}_CL\"],
        \"destinations\": [\"specializedDestination\"]
      }"
    fi
    
    # Close dataFlows and properties
    dcr_template+="
    ]
  },
  \"tags\": $system_tags
}"
    
    # Create DCR using JSON template
    echo "$dcr_template" > system_dcr.json
    az monitor data-collection rule create --name "$dcr_name" --resource-group "$RESOURCE_GROUP" --cli-input-json system_dcr.json
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create Data Collection Rule for $system_type.${NC}"
        return 1
    fi
    
    rm system_dcr.json
    echo -e "${GREEN}✓ Created Data Collection Rule for $system_type:${NC} $dcr_name"
    return 0
}

# Deploy onboarding guide workbook
function deploy_onboarding_guide() {
    echo -e "${BLUE}Deploying bio-pharma system onboarding guidance...${NC}"
    
    local workbook_name="${PREFIX}-biopharma-onboarding-guide"
    local location=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    local sentinel_ws="${PREFIX}-sentinel-ws"
    
    # Create workbook template
    local workbook_template=$(cat << EOF
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Bio-Pharmaceutical System Onboarding Guide\n\nThis guide helps system administrators connect bio-pharma specific systems to Azure Sentinel for security monitoring. Follow the steps below to connect each system type.\n\n## System Types\n\n- Electronic Lab Notebook (ELN)\n- Laboratory Information Management System (LIMS)\n- Clinical Trial Management System (CTMS)\n- Manufacturing Execution System (MES)\n- Pharmacovigilance System (PV)\n- Research Instruments\n- Cold Chain Monitoring\n\n## Prerequisites\n\n1. Azure Log Analytics Agent installed on servers\n2. Network connectivity to Azure\n3. Appropriate security permissions"
      },
      "name": "text - 0"
    },
    {
      "type": 1,
      "content": {
        "json": "## Electronic Lab Notebook (ELN) Connection\n\n### Step 1: Configure Log Collection\n\nELN systems store research data and intellectual property. Configure your ELN system to generate logs for the following events:\n\n- User authentication\n- Document access\n- Document downloads/exports\n- Permission changes\n- Configuration changes\n- Failed operations\n\n### Step 2: Log Formats\n\nEnsure logs contain:\n\n- Timestamp in ISO 8601 format\n- Username\n- Action performed\n- Resource accessed\n- IP address\n- Data classification\n\n### Sample Log Format\n\n```\n2025-04-10T14:32:45Z User:john.doe@acme.com Action:Download Resource:CompoundAnalysis-2025-04.docx Classification:Confidential IP:192.168.1.45 Status:Success Size:2.5MB Count:1\n```"
      },
      "name": "text - 1"
    },
    {
      "type": 1,
      "content": {
        "json": "## Manufacturing Execution System (MES) Connection\n\n### Step 1: Configure Log Collection\n\nMES systems control manufacturing processes. Configure your MES to generate logs for the following events:\n\n- User authentication\n- Recipe/parameter changes\n- Production execution\n- Quality checks\n- System validation\n- Configuration changes\n- Batch processing\n\n### Step 2: Log Formats\n\nEnsure logs contain:\n\n- Timestamp in ISO 8601 format\n- Username\n- Action performed\n- System affected\n- Validation status\n- Change control ID (if applicable)\n\n### Sample Log Format\n\n```\n2025-04-10T10:15:22Z User:operator.smith@acme.com Action:RecipeChange System:Bioreactor-3 ValidationStatus:Validated ChangeControlID:CC-2025-0422 Parameter:Agitation Value:250rpm PreviousValue:220rpm\n```"
      },
      "name": "text - 2"
    },
    {
      "type": 1,
      "content": {
        "json": "## Clinical Trial Management System (CTMS) Connection\n\n### Step 1: Configure Log Collection\n\nCTMS systems manage patient/subject data. Configure your CTMS to generate logs for the following events:\n\n- User authentication\n- PHI/PII access\n- Report generation\n- Protocol amendments\n- Subject enrollment/withdrawal\n- Data exports\n\n### Step 2: Log Formats\n\nEnsure logs contain:\n\n- Timestamp in ISO 8601 format\n- Username\n- Action performed\n- Subject identifier (masked if possible)\n- Study identifier\n- Access type\n\n### Sample Log Format\n\n```\n2025-04-10T09:45:15Z User:clinical.admin@acme.com Action:Access Subject:S-12345 Study:ACME-2025-01 AccessType:SubjectData Location:US-Boston Status:Authorized\n```"
      },
      "name": "text - 3"
    },
    {
      "type": 1,
      "content": {
        "json": "## Connection Verification\n\nAfter configuring each system, verify data is flowing correctly:\n\n1. Run the following command to check if logs are being ingested:\n\n```bash\n./validate-biopharma-compliance.sh -g \"${RESOURCE_GROUP}\" -p \"${PREFIX}\" -r \"21CFR11,GDPR,GxP\"\n```\n\n2. Check the following tables in Log Analytics:\n   - Custom_ELN_CL\n   - Custom_LIMS_CL\n   - Custom_CTMS_CL\n   - Custom_MES_CL\n   - Custom_PV_CL\n   - Custom_Instruments_CL\n   - Custom_ColdChain_CL\n\n3. Verify alerts are being generated for security events\n\n## Compliance Documentation\n\nMaintain the following documentation:\n\n1. System connection configurations\n2. Data flow diagrams\n3. Log retention policies\n4. Data masking procedures for PHI/PII\n5. Access control lists for monitoring data"
      },
      "name": "text - 4"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
EOF
)

    # Create workbook
    local workbook_id=$(uuidgen | tr -d '-')
    echo "$workbook_template" > onboarding_guide.json
    
    az monitor workbook create --resource-group "$RESOURCE_GROUP" --name "$workbook_id" --display-name "$workbook_name" --location "$location" --category "sentinel" --serialized-data @onboarding_guide.json --source-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$sentinel_ws"
    
    rm onboarding_guide.json
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create onboarding guide workbook.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Onboarding Guide deployed:${NC} $workbook_name"
    return 0
}

# Main function
function main() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Bio-Pharma System Connectors Configuration${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    parse_args "$@"
    check_dependencies
    validate_workspaces
    
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Prefix:${NC} $PREFIX"
    echo -e "${BLUE}Systems:${NC} ${SYSTEMS[*]}"
    echo -e "${BLUE}=================================================${NC}"
    
    # Deploy shared Data Collection Endpoint
    local dce_id=$(deploy_dce)
    
    # Configure each system connector
    local success_count=0
    local index=0
    
    for system in "${SYSTEMS[@]}"; do
        echo -e "${BLUE}------------------------------------------------${NC}"
        
        # Get log directories for this system
        local log_dirs="${LOG_DIRS[$index]}"
        
        # Configure system using unified function
        configure_system_dcr "$system" "$dce_id" "$log_dirs"
        if [ $? -eq 0 ]; then
            ((success_count++))
        fi
        
        ((index++))
    done
    
    # Deploy onboarding guidance workbook
    deploy_onboarding_guide
    
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Bio-Pharma Connector Configuration Complete${NC}"
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "Successfully configured ${success_count} out of ${#SYSTEMS[@]} systems"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Install monitoring agents on bio-pharma system servers"
    echo -e "2. Configure system logging to match the required formats"
    echo -e "3. Verify data ingestion in Log Analytics workspaces"
    echo -e "4. Review and customize analytics rules"
    echo -e "${BLUE}=================================================${NC}"
}

# Execute main function with all arguments
main "$@"
