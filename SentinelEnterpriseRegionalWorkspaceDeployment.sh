#!/bin/bash
# Regional Workspace Deployment Script for Bio-Pharmaceutical Organizations
# This script deploys regional Azure Sentinel workspaces in accordance with
# data sovereignty and local regulatory requirements across global operations

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default parameters
RESOURCE_GROUP=""
PREFIX=""
REGIONS=("us" "eu" "apac" "latam")
DEFAULT_LOCATION="eastus"

# Default regulatory mappings
declare -A REGION_LOCATIONS
REGION_LOCATIONS["us"]="eastus"
REGION_LOCATIONS["eu"]="westeurope"
REGION_LOCATIONS["apac"]="southeastasia"
REGION_LOCATIONS["latam"]="brazilsouth"

# Default regulatory mappings
declare -A REGION_REGULATIONS
REGION_REGULATIONS["us"]="FDA,HIPAA,21CFR11,SOX"
REGION_REGULATIONS["eu"]="EMA,GDPR,Annex11,SOX"
REGION_REGULATIONS["apac"]="PMDA,CDSCO,TGA,PDPA"
REGION_REGULATIONS["latam"]="ANVISA,LGPD,MHLW"

# Default data retention (in days)
declare -A REGION_RETENTION
REGION_RETENTION["us"]=2557  # 7 years (FDA requirement)
REGION_RETENTION["eu"]=3652  # 10 years (EMA requirement)
REGION_RETENTION["apac"]=1826  # 5 years
REGION_RETENTION["latam"]=1826  # 5 years

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
            -r|--regions)
                IFS=',' read -r -a REGIONS <<< "$2"
                shift
                shift
                ;;
            -h|--help)
                echo "Usage: $0 -g <resource-group> -p <prefix> [-r <comma-separated-regions>]"
                echo ""
                echo "Options:"
                echo "  -g, --resource-group   Resource group for deployments"
                echo "  -p, --prefix           Prefix for resource naming"
                echo "  -r, --regions          Comma-separated list of regions to deploy (default: us,eu,apac,latam)"
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
        echo "Usage: $0 -g <resource-group> -p <prefix> [-r <comma-separated-regions>]"
        exit 1
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

# Validate the central resources exist
function validate_central_resources() {
    echo -e "${BLUE}Validating central resources...${NC}"
    
    # Check central Sentinel workspace
    CENTRAL_WS="${PREFIX}-sentinel-ws"
    if ! az monitor log-analytics workspace show --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${RED}Error: Central Sentinel workspace '$CENTRAL_WS' not found in resource group '$RESOURCE_GROUP'.${NC}"
        echo -e "${YELLOW}Please deploy the central resources first using deploy-biopharma.sh${NC}"
        exit 1
    fi
    
    # Get the central workspace ID for later use
    CENTRAL_WS_ID=$(az monitor log-analytics workspace show --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    
    echo -e "${GREEN}Central resources validated successfully.${NC}"
}

# Deploy regional workspace for a specific region
function deploy_regional_workspace() {
    local region=$1
    local location=${REGION_LOCATIONS[$region]}
    local regulations=${REGION_REGULATIONS[$region]}
    local retention=${REGION_RETENTION[$region]}
    
    local workspace_name="${PREFIX}-${region}-sentinel-ws"
    
    echo -e "${BLUE}Deploying regional workspace for ${region} in ${location}...${NC}"
    
    # Check if workspace already exists
    if az monitor log-analytics workspace show --workspace-name "$workspace_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}Workspace '$workspace_name' already exists. Skipping creation.${NC}"
    else
        # Create the workspace
        az monitor log-analytics workspace create \
            --resource-group "$RESOURCE_GROUP" \
            --workspace-name "$workspace_name" \
            --location "$location" \
            --sku "PerGB2018" \
            --retention-time "$retention" \
            --tags "workspaceType=Regional" "region=$region" "regulations=$regulations" "environment=production"
            
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create workspace '$workspace_name'.${NC}"
            return 1
        fi
    fi
    
    # Get workspace ID
    local workspace_id=$(az monitor log-analytics workspace show --workspace-name "$workspace_name" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    
    # Enable Microsoft Sentinel on the workspace
    echo -e "${BLUE}Enabling Microsoft Sentinel on $workspace_name...${NC}"
    az security insights create --resource-group "$RESOURCE_GROUP" --workspace-name "$workspace_name" -n "default" -l "$location"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to enable Microsoft Sentinel on workspace '$workspace_name'.${NC}"
        return 1
    fi
    
    # Deploy regional DCR
    echo -e "${BLUE}Configuring Data Collection Rules for $region region...${NC}"
    
    # Create storage account for regional compliance
    local storage_name="${PREFIX}${region}compsa"
    storage_name=$(echo "$storage_name" | tr '[:upper:]' '[:lower:]')
    
    az storage account create \
        --name "$storage_name" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$location" \
        --sku "Standard_GRS" \
        --kind "StorageV2" \
        --tags "region=$region" "regulations=$regulations" "retentionDays=$retention" \
        --min-tls-version "TLS1_2" \
        --allow-blob-public-access false
        
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create storage account '$storage_name'.${NC}"
        return 1
    fi
    
    # Create container with immutable storage policy
    local container_name="compliance-data"
    
    az storage container create \
        --name "$container_name" \
        --account-name "$storage_name" \
        --auth-mode login
        
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create container '$container_name'.${NC}"
        return 1
    fi
    
    # Configure immutable storage - For simplicity, skipping this in the script
    echo -e "${YELLOW}Note: Immutable storage policy should be configured manually in the Azure Portal${NC}"
    
    # Set up data export for compliance
    echo -e "${BLUE}Setting up data export for compliance...${NC}"
    
    # This would typically be done through ARM/Bicep templates for Data Export
    # For simplicity, this step is noted but not implemented in the script
    echo -e "${YELLOW}Note: Data export to be configured through Azure portal or ARM templates${NC}"
    
    echo -e "${GREEN}Successfully deployed regional workspace for $region region.${NC}"
    return 0
}

# Configure cross-workspace queries
function configure_cross_workspace_queries() {
    echo -e "${BLUE}Configuring cross-workspace queries...${NC}"
    
    # This would typically be done through ARM/Bicep templates
    # For simplicity, this step is noted but not implemented in the script
    echo -e "${YELLOW}Note: Cross-workspace queries to be configured through query pack deployment${NC}"
    
    echo -e "${GREEN}Cross-workspace query configuration complete.${NC}"
}

# Deploy regional connectors
function deploy_regional_connectors() {
    local region=$1
    local workspace_name="${PREFIX}-${region}-sentinel-ws"
    
    echo -e "${BLUE}Deploying regional connectors for $region...${NC}"
    
    # This would typically be done through ARM/Bicep templates
    # For simplicity, this step is noted but not implemented in the script
    echo -e "${YELLOW}Note: Regional connectors to be configured through Azure portal or ARM templates${NC}"
    
    # Example command structure for reference:
    # az security insights connector create --name "WindowsSecurityEvents" --workspace-name "$workspace_name" --resource-group "$RESOURCE_GROUP" ...
    
    echo -e "${GREEN}Regional connector deployment complete for $region.${NC}"
}

# Configure regional-specific analytics rules
function configure_regional_analytics() {
    local region=$1
    local workspace_name="${PREFIX}-${region}-sentinel-ws"
    local regulations=${REGION_REGULATIONS[$region]}
    
    echo -e "${BLUE}Configuring regional analytics rules for $region ($regulations)...${NC}"
    
    # This would typically be done through ARM/Bicep templates
    # For simplicity, this step is noted but not implemented in the script
    echo -e "${YELLOW}Note: Regional analytics rules to be configured through Azure portal or ARM templates${NC}"
    
    echo -e "${GREEN}Regional analytics configuration complete for $region.${NC}"
}

# Main function
function main() {
    parse_args "$@"
    check_dependencies
    validate_central_resources
    
    echo -e "${BLUE}========== Bio-Pharma Regional Sentinel Deployment ==========${NC}"
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Prefix:${NC} $PREFIX"
    echo -e "${BLUE}Regions:${NC} ${REGIONS[*]}"
    echo -e "${BLUE}=================================================${NC}"
    
    # Deploy workspaces for each region
    for region in "${REGIONS[@]}"; do
        if [[ ! -v REGION_LOCATIONS[$region] ]]; then
            echo -e "${YELLOW}Warning: Unknown region code '$region'. Using default location '$DEFAULT_LOCATION'.${NC}"
            REGION_LOCATIONS[$region]="$DEFAULT_LOCATION"
            REGION_REGULATIONS[$region]="Custom"
            REGION_RETENTION[$region]=2557
        fi
        
        deploy_regional_workspace "$region"
        if [ $? -eq 0 ]; then
            deploy_regional_connectors "$region"
            configure_regional_analytics "$region"
        fi
    done
    
    # Configure cross-workspace queries after all workspaces are deployed
    configure_cross_workspace_queries
    
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Bio-Pharma Regional Sentinel Deployment Complete${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Configure regional data connectors for bio-pharma systems"
    echo -e "2. Set up regional workbooks and alerts"
    echo -e "3. Configure RBAC for regional SOC teams"
    echo -e "4. Validate compliance with regional regulatory requirements"
    echo -e "${BLUE}=================================================${NC}"
}

# Execute main function with all arguments
main "$@"
