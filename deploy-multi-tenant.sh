#!/bin/bash
# Multi-Tenant Deployment Script for Bio-Pharmaceutical Azure Sentinel Solution
# This script configures multi-tenant support for organizations with multiple subsidiaries

# Script version
VERSION="1.0.0"
DATE="2025-04-11"

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default parameters
RESOURCE_GROUP=""
PREFIX="bp"
PARENT_PREFIX=""
TENANT_NAME=""
TENANT_TYPE=""
TENANT_REGION=""
SUBSCRIPTION_ID=""
PARENT_SUBSCRIPTION_ID=""
VALIDATE_ONLY=false
FORCE=false
HELP=false

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
            --parent-prefix)
                PARENT_PREFIX="$2"
                shift
                shift
                ;;
            -n|--tenant-name)
                TENANT_NAME="$2"
                shift
                shift
                ;;
            -t|--tenant-type)
                TENANT_TYPE="$2"
                shift
                shift
                ;;
            -r|--tenant-region)
                TENANT_REGION="$2"
                shift
                shift
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift
                shift
                ;;
            --parent-subscription)
                PARENT_SUBSCRIPTION_ID="$2"
                shift
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                HELP=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    # Display help if requested
    if [ "$HELP" = true ]; then
        display_help
        exit 0
    fi

    # Verify required parameters
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$TENANT_NAME" ] || [ -z "$TENANT_TYPE" ] || [ -z "$TENANT_REGION" ]; then
        echo -e "${RED}Error: Required parameters missing${NC}"
        echo -e "Use -h or --help for usage information"
        exit 1
    fi
    
    # Validate tenant type
    if [[ ! "$TENANT_TYPE" =~ ^(Research|Clinical|Manufacturing|Distribution|Corporate)$ ]]; then
        echo -e "${RED}Error: Invalid tenant type. Valid options are: Research, Clinical, Manufacturing, Distribution, Corporate${NC}"
        exit 1
    fi
    
    # Validate tenant region
    if [[ ! "$TENANT_REGION" =~ ^(US|EU|APAC|LATAM)$ ]]; then
        echo -e "${RED}Error: Invalid tenant region. Valid options are: US, EU, APAC, LATAM${NC}"
        exit 1
    fi
    
    # Set default parent prefix if not provided
    if [ -z "$PARENT_PREFIX" ]; then
        PARENT_PREFIX="$PREFIX"
    fi
}

# Display help information
function display_help() {
    echo "Bio-Pharmaceutical Multi-Tenant Configuration Script"
    echo "Version: $VERSION ($DATE)"
    echo ""
    echo "This script configures multi-tenant support for organizations with multiple subsidiaries"
    echo ""
    echo "Usage: $0 -g <resource-group> -n <tenant-name> -t <tenant-type> -r <tenant-region> [options]"
    echo ""
    echo "Required Parameters:"
    echo "  -g, --resource-group    Resource group for tenant resources"
    echo "  -n, --tenant-name       Name of the tenant (no spaces, alphanumeric with hyphens)"
    echo "  -t, --tenant-type       Type of tenant (Research, Clinical, Manufacturing, Distribution, Corporate)"
    echo "  -r, --tenant-region     Primary region for tenant (US, EU, APAC, LATAM)"
    echo ""
    echo "Optional Parameters:"
    echo "  -p, --prefix            Prefix for tenant resource naming (default: bp)"
    echo "  --parent-prefix         Prefix for parent organization resources (default: same as prefix)"
    echo "  -s, --subscription      Azure subscription ID for tenant (defaults to current)"
    echo "  --parent-subscription   Azure subscription ID for parent organization (defaults to current)"
    echo "  --validate-only         Validate configuration without creating resources"
    echo "  -f, --force             Force operations without confirmation prompts"
    echo "  -h, --help              Show this help message"
}

# Check script dependencies
function check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        echo -e "${RED}Error: Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli${NC}"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed. Please install it using your package manager${NC}"
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        echo -e "${YELLOW}Not logged in to Azure. Running az login...${NC}"
        az login
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to log in to Azure${NC}"
            exit 1
        fi
    fi
    
    # Set subscription if provided
    if [ -n "$SUBSCRIPTION_ID" ]; then
        echo -e "${BLUE}Setting subscription to: ${SUBSCRIPTION_ID}${NC}"
        if ! az account set --subscription "$SUBSCRIPTION_ID" &> /dev/null; then
            echo -e "${RED}Error: Could not set subscription to: ${SUBSCRIPTION_ID}${NC}"
            exit 1
        fi
    fi
    
    # Check if resource group exists, create if not
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}Resource group '$RESOURCE_GROUP' does not exist. Creating...${NC}"
        
        # Get location from parent resource group if possible
        local parent_rg="${PARENT_PREFIX}-rg"
        local location=""
        
        if [ -n "$PARENT_SUBSCRIPTION_ID" ]; then
            # Temporarily switch to parent subscription
            local current_sub=$(az account show --query id -o tsv)
            az account set --subscription "$PARENT_SUBSCRIPTION_ID"
            
            if az group show --name "$parent_rg" &> /dev/null; then
                location=$(az group show --name "$parent_rg" --query location -o tsv)
            fi
            
            # Switch back to tenant subscription
            az account set --subscription "$current_sub"
        else
            if az group show --name "$parent_rg" &> /dev/null; then
                location=$(az group show --name "$parent_rg" --query location -o tsv)
            fi
        fi
        
        # If parent location not found, use region-specific location
        if [ -z "$location" ]; then
            case "$TENANT_REGION" in
                "US")
                    location="eastus"
                    ;;
                "EU")
                    location="westeurope"
                    ;;
                "APAC")
                    location="southeastasia"
                    ;;
                "LATAM")
                    location="brazilsouth"
                    ;;
            esac
        fi
        
        az group create --name "$RESOURCE_GROUP" --location "$location"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to create resource group '$RESOURCE_GROUP'${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}All dependencies satisfied.${NC}"
}

# Validate parent organization resources
function validate_parent_resources() {
    echo -e "${BLUE}Validating parent organization resources...${NC}"
    
    local parent_rg="${PARENT_PREFIX}-rg"
    local parent_ws="${PARENT_PREFIX}-sentinel-ws"
    local parent_exists=true
    
    # Check if we need to switch to parent subscription
    if [ -n "$PARENT_SUBSCRIPTION_ID" ] && [ "$PARENT_SUBSCRIPTION_ID" != "$SUBSCRIPTION_ID" ]; then
        # Save current subscription
        local current_sub=$(az account show --query id -o tsv)
        
        # Switch to parent subscription
        az account set --subscription "$PARENT_SUBSCRIPTION_ID"
        
        # Check parent workspace
        if ! az monitor log-analytics workspace show --workspace-name "$parent_ws" --resource-group "$parent_rg" &> /dev/null; then
            echo -e "${RED}Error: Parent workspace '$parent_ws' not found in resource group '$parent_rg' in subscription '$PARENT_SUBSCRIPTION_ID'${NC}"
            parent_exists=false
        fi
        
        # Switch back to tenant subscription
        az account set --subscription "$current_sub"
    else
        # Check parent workspace in same subscription
        if ! az monitor log-analytics workspace show --workspace-name "$parent_ws" --resource-group "$parent_rg" &> /dev/null; then
            echo -e "${RED}Error: Parent workspace '$parent_ws' not found in resource group '$parent_rg'${NC}"
            parent_exists=false
        fi
    fi
    
    if [ "$parent_exists" = false ]; then
        echo -e "${RED}Error: Parent organization resources not found. Please deploy parent workspace first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Parent organization resources validated.${NC}"
}

# Create tenant workspace
function create_tenant_workspace() {
    echo -e "${BLUE}Creating tenant workspace...${NC}"
    
    local tenant_ws="${PREFIX}-${TENANT_NAME,,}-ws"
    local location=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    
    # Set retention days based on tenant type
    local retention_days=90
    case "$TENANT_TYPE" in
        "Research")
            retention_days=2557  # 7 years for IP protection
            ;;
        "Clinical")
            retention_days=2557  # 7 years for regulatory compliance
            ;;
        "Manufacturing")
            retention_days=2557  # 7 years for GxP compliance
            ;;
        "Distribution")
            retention_days=1095  # 3 years for general business records
            ;;
        "Corporate")
            retention_days=2557  # 7 years for corporate records
            ;;
    esac
    
    # Set workspace tags based on tenant type
    local tenant_tags=""
    case "$TENANT_TYPE" in
        "Research")
            tenant_tags='{\"workspaceType\":\"Research\",\"dataClassification\":\"Highly-Confidential\",\"complianceFrameworks\":\"IP-Protection,SOX\"}'
            ;;
        "Clinical")
            tenant_tags='{\"workspaceType\":\"Clinical\",\"dataClassification\":\"Protected-Health-Information\",\"complianceFrameworks\":\"HIPAA,GDPR,21CFR11\"}'
            ;;
        "Manufacturing")
            tenant_tags='{\"workspaceType\":\"Manufacturing\",\"dataClassification\":\"Confidential\",\"complianceFrameworks\":\"21CFR11,GxP,SOX\"}'
            ;;
        "Distribution")
            tenant_tags='{\"workspaceType\":\"Distribution\",\"dataClassification\":\"Business-Confidential\",\"complianceFrameworks\":\"SOX\"}'
            ;;
        "Corporate")
            tenant_tags='{\"workspaceType\":\"Corporate\",\"dataClassification\":\"Confidential\",\"complianceFrameworks\":\"SOX,GDPR\"}'
            ;;
    esac
    
    # Check if workspace already exists
    if az monitor log-analytics workspace show --workspace-name "$tenant_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}Workspace '$tenant_ws' already exists.${NC}"
        
        if [ "$FORCE" != "true" ]; then
            read -p "Do you want to update the existing workspace? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Skipping workspace update.${NC}"
                return 0
            fi
        fi
        
        # Update existing workspace
        if [ "$VALIDATE_ONLY" != "true" ]; then
            echo -e "${BLUE}Updating workspace '$tenant_ws'...${NC}"
            
            az monitor log-analytics workspace update \
                --workspace-name "$tenant_ws" \
                --resource-group "$RESOURCE_GROUP" \
                --retention-time "$retention_days" \
                --tags "tenant=$TENANT_NAME" "tenantType=$TENANT_TYPE" "tenantRegion=$TENANT_REGION" "updateDate=$(date +%Y-%m-%d)"
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to update workspace '$tenant_ws'${NC}"
                exit 1
            fi
            
            echo -e "${GREEN}Workspace '$tenant_ws' updated successfully.${NC}"
        else
            echo -e "${YELLOW}Validation mode: Would update workspace '$tenant_ws'${NC}"
        fi
    else
        # Create new workspace
        if [ "$VALIDATE_ONLY" != "true" ]; then
            echo -e "${BLUE}Creating workspace '$tenant_ws'...${NC}"
            
            az monitor log-analytics workspace create \
                --workspace-name "$tenant_ws" \
                --resource-group "$RESOURCE_GROUP" \
                --location "$location" \
                --sku "PerGB2018" \
                --retention-time "$retention_days" \
                --tags "tenant=$TENANT_NAME" "tenantType=$TENANT_TYPE" "tenantRegion=$TENANT_REGION" "deployDate=$(date +%Y-%m-%d)" $tenant_tags
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to create workspace '$tenant_ws'${NC}"
                exit 1
            fi
            
            echo -e "${GREEN}Workspace '$tenant_ws' created successfully.${NC}"
        else
            echo -e "${YELLOW}Validation mode: Would create workspace '$tenant_ws' in '$location'${NC}"
        fi
    fi
    
    # Enable Microsoft Sentinel on the workspace
    if [ "$VALIDATE_ONLY" != "true" ]; then
        echo -e "${BLUE}Enabling Microsoft Sentinel on workspace '$tenant_ws'...${NC}"
        
        if ! az security insights show --workspace-name "$tenant_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
            az security insights create --resource-group "$RESOURCE_GROUP" --workspace-name "$tenant_ws" -n "default" -l "$location"
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to enable Microsoft Sentinel on workspace '$tenant_ws'${NC}"
                exit 1
            fi
            
            echo -e "${GREEN}Microsoft Sentinel enabled on workspace '$tenant_ws' successfully.${NC}"
        else
            echo -e "${GREEN}Microsoft Sentinel already enabled on workspace '$tenant_ws'.${NC}"
        fi
    else
        echo -e "${YELLOW}Validation mode: Would enable Microsoft Sentinel on workspace '$tenant_ws'${NC}"
    fi
}

# Configure tenant data sources
function configure_tenant_data_sources() {
    echo -e "${BLUE}Configuring tenant data sources...${NC}"
    
    local tenant_ws="${PREFIX}-${TENANT_NAME,,}-ws"
    
    # Define data sources based on tenant type
    local data_sources=()
    case "$TENANT_TYPE" in
        "Research")
            data_sources=("ELN" "LIMS" "INSTRUMENTS")
            ;;
        "Clinical")
            data_sources=("CTMS" "PV" "EDC")
            ;;
        "Manufacturing")
            data_sources=("MES" "QMS" "INSTRUMENTS")
            ;;
        "Distribution")
            data_sources=("ERP" "WMS" "COLDCHAIN")
            ;;
        "Corporate")
            data_sources=("AAD" "M365" "AUDIT")
            ;;
    esac
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would configure data sources for tenant '$TENANT_NAME': ${data_sources[*]}${NC}"
        return 0
    fi
    
    # Call data connector script for each data source
    echo -e "${BLUE}Configuring data sources: ${data_sources[*]}${NC}"
    
    # Convert array to comma-separated string
    local data_sources_str=$(IFS=,; echo "${data_sources[*]}")
    
    # Call the specialized connectors script
    ./SentinelEnterpriseSpecializedDataConnectors.sh \
        -g "$RESOURCE_GROUP" \
        -p "${PREFIX}-${TENANT_NAME,,}" \
        -s "$data_sources_str"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to configure data sources for tenant '$TENANT_NAME'${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Data sources configured successfully for tenant '$TENANT_NAME'.${NC}"
}

# Configure cross-tenant access
function configure_cross_tenant_access() {
    echo -e "${BLUE}Configuring cross-tenant access...${NC}"
    
    local tenant_ws="${PREFIX}-${TENANT_NAME,,}-ws"
    local parent_ws="${PARENT_PREFIX}-sentinel-ws"
    local parent_rg="${PARENT_PREFIX}-rg"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would configure cross-tenant access between '$parent_ws' and '$tenant_ws'${NC}"
        return 0
    fi
    
    # Get workspace IDs
    local tenant_ws_id=""
    local parent_ws_id=""
    
    tenant_ws_id=$(az monitor log-analytics workspace show --workspace-name "$tenant_ws" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    
    # Check if we need to switch to parent subscription
    if [ -n "$PARENT_SUBSCRIPTION_ID" ] && [ "$PARENT_SUBSCRIPTION_ID" != "$SUBSCRIPTION_ID" ]; then
        # Save current subscription
        local current_sub=$(az account show --query id -o tsv)
        
        # Switch to parent subscription
        az account set --subscription "$PARENT_SUBSCRIPTION_ID"
        
        # Get parent workspace ID
        parent_ws_id=$(az monitor log-analytics workspace show --workspace-name "$parent_ws" --resource-group "$parent_rg" --query id -o tsv)
        
        # Switch back to tenant subscription
        az account set --subscription "$current_sub"
    else
        # Get parent workspace ID in same subscription
        parent_ws_id=$(az monitor log-analytics workspace show --workspace-name "$parent_ws" --resource-group "$parent_rg" --query id -o tsv)
    fi
    
    if [ -z "$tenant_ws_id" ] || [ -z "$parent_ws_id" ]; then
        echo -e "${RED}Error: Failed to get workspace IDs${NC}"
        exit 1
    fi
    
    # Create parent-to-tenant access
    echo -e "${BLUE}Configuring parent-to-tenant access...${NC}"
    
    # This would require Azure RBAC management which is beyond the scope of a simple script
    # In a real implementation, this would use Azure AD groups and RBAC assignments
    
    echo -e "${YELLOW}Note: Cross-tenant access configuration requires Azure AD and RBAC setup${NC}"
    echo -e "${YELLOW}This step requires manual configuration through the Azure portal:${NC}"
    echo -e "1. Navigate to tenant workspace: $tenant_ws_id"
    echo -e "2. Go to 'Access control (IAM)'"
    echo -e "3. Add role assignment for 'Microsoft Sentinel Reader' to parent SOC group"
    echo -e "4. For SOC workflow actions, add 'Microsoft Sentinel Responder' role"
    
    # Create cross-workspace queries
    echo -e "${BLUE}Creating cross-workspace query pack...${NC}"
    
    local query_pack_name="${PREFIX}-${TENANT_NAME,,}-queries"
    
    # Check if query pack exists
    if ! az monitor log-analytics query-pack show --name "$query_pack_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        # Create query pack
        az monitor log-analytics query-pack create \
            --name "$query_pack_name" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to create query pack '$query_pack_name'${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}Cross-tenant access configuration guidance provided.${NC}"
}

# Implement tenant-specific security policies
function configure_tenant_policies() {
    echo -e "${BLUE}Configuring tenant-specific security policies...${NC}"
    
    local tenant_ws="${PREFIX}-${TENANT_NAME,,}-ws"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would configure security policies for tenant '$TENANT_NAME'${NC}"
        return 0
    fi
    
    # Create analytics rules based on tenant type
    local template_name=""
    case "$TENANT_TYPE" in
        "Research")
            template_name="ResearchAnalyticsRules.json"
            ;;
        "Clinical")
            template_name="ClinicalAnalyticsRules.json"
            ;;
        "Manufacturing")
            template_name="ManufacturingAnalyticsRules.json"
            ;;
        "Distribution")
            template_name="DistributionAnalyticsRules.json"
            ;;
        "Corporate")
            template_name="CorporateAnalyticsRules.json"
            ;;
    esac
    
    echo -e "${YELLOW}Note: Tenant-specific analytics rules deployment would use ARM templates${NC}"
    echo -e "${YELLOW}In a real implementation, this would deploy rules from template: $template_name${NC}"
    
    # Create workbook for tenant
    local workbook_name="${PREFIX}-${TENANT_NAME,,}-overview"
    local workbook_id=$(uuidgen | tr -d '-')
    local location=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    
    # Get workspace resource ID
    local ws_resource_id=$(az monitor log-analytics workspace show --workspace-name "$tenant_ws" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    
    # Create basic workbook with tenant info
    echo -e "${BLUE}Creating tenant overview workbook...${NC}"
    
    # Generate a simple workbook template
    local workbook_content=$(cat << EOF
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# ${TENANT_NAME} Security Overview\n---\n\nThis workbook provides security monitoring for ${TENANT_TYPE} operations in the ${TENANT_REGION} region."
      },
      "name": "title"
    },
    {
      "type": 9,
      "content": {
        "version": "KqlParameterItem/1.0",
        "parameters": [
          {
            "id": "f42aa9de-f1d2-4a72-a529-913a9d1fe1c7",
            "version": "KqlParameterItem/1.0",
            "name": "TimeRange",
            "type": 4,
            "value": {
              "durationMs": 604800000
            },
            "typeSettings": {
              "selectableValues": [
                {
                  "durationMs": 86400000
                },
                {
                  "durationMs": 604800000
                },
                {
                  "durationMs": 2592000000
                },
                {
                  "durationMs": 7776000000
                }
              ]
            },
            "label": "Time Range"
          }
        ],
        "style": "pills",
        "queryType": 0
      },
      "name": "parameters"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// Tenant security overview\nSecurityAlert\n| summarize Count=count() by AlertSeverity\n| extend SortOrder = case(\n    AlertSeverity == 'High', 1,\n    AlertSeverity == 'Medium', 2,\n    AlertSeverity == 'Low', 3,\n    AlertSeverity == 'Informational', 4,\n    5)\n| order by SortOrder asc",
        "size": 0,
        "title": "Alerts by Severity",
        "timeContext": {
          "durationMs": 604800000
        },
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "piechart"
      },
      "name": "alerts-by-severity"
    }
  ],
  "styleSettings": {},
  "\$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
EOF
)
    
    # Save workbook template to file
    echo "$workbook_content" > tenant-workbook.json
    
    # Create workbook
    az monitor workbooks create \
        --resource-group "$RESOURCE_GROUP" \
        --category "sentinel" \
        --display-name "$workbook_name" \
        --location "$location" \
        --name "$workbook_id" \
        --serialized-data @tenant-workbook.json \
        --source-id "$ws_resource_id" \
        --tags "tenant=$TENANT_NAME" "tenantType=$TENANT_TYPE" "tenantRegion=$TENANT_REGION"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create tenant overview workbook${NC}"
        exit 1
    fi
    
    # Clean up temporary file
    rm tenant-workbook.json
    
    echo -e "${GREEN}Tenant-specific security policies configured.${NC}"
}

# Validate tenant configuration
function validate_tenant_configuration() {
    echo -e "${BLUE}Validating tenant configuration...${NC}"
    
    local tenant_ws="${PREFIX}-${TENANT_NAME,,}-ws"
    
    # Check workspace
    if ! az monitor log-analytics workspace show --workspace-name "$tenant_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${RED}Error: Tenant workspace '$tenant_ws' not found${NC}"
        return 1
    fi
    
    # Check Sentinel enabled
    if ! az security insights show --workspace-name "$tenant_ws" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${RED}Error: Microsoft Sentinel not enabled on workspace '$tenant_ws'${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Tenant configuration validation passed.${NC}"
    return 0
}

# Print tenant information
function print_tenant_info() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Tenant Configuration Summary${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}Tenant Name:${NC} $TENANT_NAME"
    echo -e "${BLUE}Tenant Type:${NC} $TENANT_TYPE"
    echo -e "${BLUE}Tenant Region:${NC} $TENANT_REGION"
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Workspace Name:${NC} ${PREFIX}-${TENANT_NAME,,}-ws"
    echo -e "${BLUE}------------------------------------------------${NC}"
    
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Configure data sources for tenant-specific systems"
    echo -e "2. Set up RBAC for tenant security team"
    echo -e "3. Customize analytics rules and alerts for tenant requirements"
    echo -e "4. Integrate with parent organization SOC workflows"
    echo -e "${BLUE}=================================================${NC}"
}

# Main function
function main() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Bio-Pharma Multi-Tenant Configuration${NC}"
    echo -e "${BLUE}Version:${NC} $VERSION ($DATE)"
    echo -e "${BLUE}=================================================${NC}"
    
    parse_args "$@"
    check_dependencies
    validate_parent_resources
    
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${BLUE}Configuration Settings:${NC}"
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Tenant Name:${NC} $TENANT_NAME"
    echo -e "${BLUE}Tenant Type:${NC} $TENANT_TYPE"
    echo -e "${BLUE}Tenant Region:${NC} $TENANT_REGION"
    echo -e "${BLUE}Prefix:${NC} $PREFIX"
    echo -e "${BLUE}Parent Prefix:${NC} $PARENT_PREFIX"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Mode:${NC} VALIDATION ONLY (no resources will be created)"
    fi
    
    echo -e "${BLUE}------------------------------------------------${NC}"
    
    # Confirm configuration unless forced or validation only
    if [ "$FORCE" != true ] && [ "$VALIDATE_ONLY" != true ]; then
        read -p "Ready to configure tenant. Continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Tenant configuration cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Execute tenant configuration steps
    create_tenant_workspace
    configure_tenant_data_sources
    configure_cross_tenant_access
    configure_tenant_policies
    
    # Validate final configuration
    if [ "$VALIDATE_ONLY" != true ]; then
        validate_tenant_configuration
        if [ $? -ne 0 ]; then
            echo -e "${RED}Tenant configuration validation failed.${NC}"
            exit 1
        fi
    fi
    
    # Print tenant information
    print_tenant_info
    
    echo -e "${GREEN}Tenant configuration completed successfully!${NC}"
    exit 0
}

# Execute main function with all arguments
main "$@"
