#!/bin/bash
# Master Deployment Script for Bio-Pharmaceutical Azure Sentinel Solution
# This script orchestrates the deployment of the entire bio-pharma sentinel solution

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
LOCATION=""
PREFIX="bp"
ENVIRONMENT="prod"
REGIONS=("us" "eu" "apac" "latam")
SUBSCRIPTION_ID=""
VALIDATE_ONLY=false
SKIP_VALIDATION=false
DEPLOY_ENHANCEMENTS=false
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
            -l|--location)
                LOCATION="$2"
                shift
                shift
                ;;
            -p|--prefix)
                PREFIX="$2"
                shift
                shift
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift
                shift
                ;;
            -r|--regions)
                IFS=',' read -r -a REGIONS <<< "$2"
                shift
                shift
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --deploy-enhancements)
                DEPLOY_ENHANCEMENTS=true
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
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$LOCATION" ]; then
        echo -e "${RED}Error: Resource group and location are required parameters${NC}"
        echo -e "Use -h or --help for usage information"
        exit 1
    fi
}

# Display help information
function display_help() {
    echo "Bio-Pharmaceutical Azure Sentinel Deployment Script"
    echo "Version: $VERSION ($DATE)"
    echo ""
    echo "This script orchestrates the deployment of the entire bio-pharma sentinel solution"
    echo ""
    echo "Usage: $0 -g <resource-group> -l <location> [options]"
    echo ""
    echo "Required Parameters:"
    echo "  -g, --resource-group   Resource group for deployments"
    echo "  -l, --location         Primary Azure region for deployment"
    echo ""
    echo "Optional Parameters:"
    echo "  -p, --prefix           Prefix for resource naming (default: bp)"
    echo "  -e, --environment      Environment (dev, test, prod) (default: prod)"
    echo "  -r, --regions          Comma-separated list of regions to deploy (default: us,eu,apac,latam)"
    echo "  -s, --subscription     Azure subscription ID (defaults to current)"
    echo "  --validate-only        Validate deployment without creating resources"
    echo "  --skip-validation      Skip validation after deployment"
    echo "  --deploy-enhancements  Deploy additional enhancement features"
    echo "  -h, --help             Show this help message"
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
    
    # Check if bicep is installed
    if ! az bicep version &> /dev/null; then
        echo -e "${YELLOW}Bicep not found. Installing Bicep...${NC}"
        az bicep install
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to install Bicep${NC}"
            exit 1
        fi
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
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to create resource group '$RESOURCE_GROUP'${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}All dependencies satisfied.${NC}"
}

# Make bash scripts executable
function make_scripts_executable() {
    echo -e "${BLUE}Making scripts executable...${NC}"
    chmod +x SentinelEnterpriseRegionalWorkspaceDeployment.sh
    chmod +x SentinelEnterpriseSpecializedDataConnectors.sh
    chmod +x SentinelEnterpriseValidateRegionalCompliance.sh
    chmod +x simulate-attack.sh
    echo -e "${GREEN}Scripts are now executable.${NC}"
}

# Deploy core infrastructure
function deploy_core_infrastructure() {
    echo -e "${BLUE}Deploying core infrastructure...${NC}"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would deploy core infrastructure${NC}"
        return 0
    fi
    
    # Deploy main Sentinel architecture
    echo -e "${BLUE}Deploying Sentinel workspaces...${NC}"
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file SentinelEnterpriseArchitecture.bicep \
        --parameters location="$LOCATION" prefix="$PREFIX" environment="$ENVIRONMENT" \
        --name "sentinel-architecture-$PREFIX"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deploy Sentinel architecture${NC}"
        exit 1
    fi
    
    # Get workspace details from deployment outputs
    SENTINEL_WS=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "sentinel-architecture-$PREFIX" --query "properties.outputs.sentinelWorkspaceName.value" -o tsv)
    RESEARCH_WS=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "sentinel-architecture-$PREFIX" --query "properties.outputs.researchWorkspaceName.value" -o tsv)
    MANUFACTURING_WS=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "sentinel-architecture-$PREFIX" --query "properties.outputs.manufacturingWorkspaceName.value" -o tsv)
    CLINICAL_WS=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "sentinel-architecture-$PREFIX" --query "properties.outputs.clinicalWorkspaceName.value" -o tsv)
    
    echo -e "${GREEN}Core workspaces deployed successfully:${NC}"
    echo -e "${GREEN}  - Sentinel Workspace:${NC} $SENTINEL_WS"
    echo -e "${GREEN}  - Research Workspace:${NC} $RESEARCH_WS"
    echo -e "${GREEN}  - Manufacturing Workspace:${NC} $MANUFACTURING_WS"
    echo -e "${GREEN}  - Clinical Workspace:${NC} $CLINICAL_WS"
    
    # Deploy analytics rules
    echo -e "${BLUE}Deploying analytics rules...${NC}"
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file SentinelEnterpriseAnalyticRules.bicep \
        --parameters prefix="$PREFIX" environment="$ENVIRONMENT" \
                     sentinelWorkspaceName="$SENTINEL_WS" \
                     researchWorkspaceName="$RESEARCH_WS" \
                     manufacturingWorkspaceName="$MANUFACTURING_WS" \
                     clinicalWorkspaceName="$CLINICAL_WS" \
        --name "sentinel-rules-$PREFIX"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deploy analytics rules${NC}"
        exit 1
    fi
    
    # Deploy compliance configuration
    echo -e "${BLUE}Deploying compliance configuration...${NC}"
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file SentinelEnterpriseCompliance.bicep \
        --parameters location="$LOCATION" prefix="$PREFIX" \
                     tags="{\"environment\":\"$ENVIRONMENT\",\"application\":\"Microsoft Sentinel\",\"business-unit\":\"Security\"}" \
                     sentinelWorkspaceName="$SENTINEL_WS" \
                     researchWorkspaceName="$RESEARCH_WS" \
                     manufacturingWorkspaceName="$MANUFACTURING_WS" \
                     clinicalWorkspaceName="$CLINICAL_WS" \
        --name "sentinel-compliance-$PREFIX"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deploy compliance configuration${NC}"
        exit 1
    fi
    
    # Deploy Data Collection Rules
    echo -e "${BLUE}Deploying data collection rules...${NC}"
    
    # Get workspace IDs
    SENTINEL_WS_ID=$(az monitor log-analytics workspace show --workspace-name "$SENTINEL_WS" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    RESEARCH_WS_ID=$(az monitor log-analytics workspace show --workspace-name "$RESEARCH_WS" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    MANUFACTURING_WS_ID=$(az monitor log-analytics workspace show --workspace-name "$MANUFACTURING_WS" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    CLINICAL_WS_ID=$(az monitor log-analytics workspace show --workspace-name "$CLINICAL_WS" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file SentinelEnterpriseDCR.bicep \
        --parameters location="$LOCATION" prefix="$PREFIX" environment="$ENVIRONMENT" \
                     sentinelWorkspaceId="$SENTINEL_WS_ID" \
                     researchWorkspaceId="$RESEARCH_WS_ID" \
                     manufacturingWorkspaceId="$MANUFACTURING_WS_ID" \
                     clinicalWorkspaceId="$CLINICAL_WS_ID" \
        --name "sentinel-dcr-$PREFIX"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deploy data collection rules${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Core infrastructure deployed successfully.${NC}"
}

# Deploy regional workspaces
function deploy_regional_workspaces() {
    echo -e "${BLUE}Deploying regional workspaces...${NC}"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would deploy regional workspaces${NC}"
        return 0
    fi
    
    # Call the regional workspace deployment script
    ./SentinelEnterpriseRegionalWorkspaceDeployment.sh \
        -g "$RESOURCE_GROUP" \
        -p "$PREFIX" \
        -r "$(IFS=,; echo "${REGIONS[*]}")" \
        ${SUBSCRIPTION_ID:+-s "$SUBSCRIPTION_ID"}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deploy regional workspaces${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Regional workspaces deployed successfully.${NC}"
}

# Configure data connectors
function configure_data_connectors() {
    echo -e "${BLUE}Configuring specialized data connectors...${NC}"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would configure data connectors${NC}"
        return 0
    fi
    
    # Call the data connectors script
    ./SentinelEnterpriseSpecializedDataConnectors.sh \
        -g "$RESOURCE_GROUP" \
        -p "$PREFIX" \
        -s "ELN,LIMS,CTMS,MES,PV,INSTRUMENTS,COLDCHAIN"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to configure data connectors${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Data connectors configured successfully.${NC}"
}

# Deploy enhancement features
function deploy_enhancements() {
    echo -e "${BLUE}Deploying enhancement features...${NC}"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would deploy enhancement features${NC}"
        return 0
    fi
    
    # Deploy the enhanced features bicep template
    echo -e "${BLUE}Deploying enhanced features...${NC}"
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file SentinelEnterpriseEnhancements.bicep \
        --parameters location="$LOCATION" prefix="$PREFIX" environment="$ENVIRONMENT" \
                     sentinelWorkspaceName="$SENTINEL_WS" \
        --name "sentinel-enhancements-$PREFIX"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deploy enhancement features${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Enhancement features deployed successfully.${NC}"
}

# Run validation
function run_validation() {
    echo -e "${BLUE}Running compliance validation...${NC}"
    
    if [ "$VALIDATE_ONLY" = true ]; then
        echo -e "${YELLOW}Validation mode: Would run compliance validation${NC}"
        return 0
    fi
    
    # Call the validation script
    ./SentinelEnterpriseValidateRegionalCompliance.sh \
        -g "$RESOURCE_GROUP" \
        -p "$PREFIX" \
        -r "21CFR11,EMA,GDPR,HIPAA,GxP,SOX" \
        -o "validation-report-$PREFIX.md" \
        -d
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Warning: Validation found compliance issues. Please review the validation report.${NC}"
    else
        echo -e "${GREEN}Validation completed successfully.${NC}"
    fi
}

# Print deployment summary
function print_summary() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Bio-Pharma Sentinel Deployment Summary${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Location:${NC} $LOCATION"
    echo -e "${BLUE}Prefix:${NC} $PREFIX"
    echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"
    echo -e "${BLUE}Regions:${NC} ${REGIONS[*]}"
    
    if [ "$DEPLOY_ENHANCEMENTS" = true ]; then
        echo -e "${BLUE}Enhancements:${NC} Deployed"
    fi
    
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${GREEN}Sentinel Resources:${NC}"
    echo -e "  - Central Sentinel Workspace: $SENTINEL_WS"
    echo -e "  - Research Workspace: $RESEARCH_WS"
    echo -e "  - Manufacturing Workspace: $MANUFACTURING_WS"
    echo -e "  - Clinical Workspace: $CLINICAL_WS"
    echo -e "${BLUE}------------------------------------------------${NC}"
    
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Configure on-premises data sources to send logs to data collection endpoints"
    echo -e "2. Set up role-based access control for SOC teams"
    echo -e "3. Review analytics rules and customize for your environment"
    echo -e "4. Schedule periodic compliance validation checks"
    echo -e "5. Review the validation report at: validation-report-$PREFIX.md"
    echo -e "${BLUE}=================================================${NC}"
}

# Main execution flow
parse_args "$@"
check_dependencies
make_scripts_executable

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}Bio-Pharma Sentinel Deployment${NC}"
echo -e "${BLUE}Version:${NC} $VERSION ($DATE)"
echo -e "${BLUE}=================================================${NC}"

# Confirm deployment if not in validation mode
if [ "$VALIDATE_ONLY" != true ]; then
    read -p "Ready to begin deployment. Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deployment cancelled.${NC}"
        exit 0
    fi
fi

# Deploy core infrastructure
deploy_core_infrastructure

# Deploy regional workspaces
deploy_regional_workspaces

# Configure data connectors
configure_data_connectors

# Deploy enhancements if requested
if [ "$DEPLOY_ENHANCEMENTS" = true ]; then
    deploy_enhancements
fi

# Run validation unless skipped
if [ "$SKIP_VALIDATION" != true ]; then
    run_validation
fi

# Print deployment summary
print_summary

echo -e "${GREEN}Deployment completed successfully!${NC}"
exit 0
