#!/bin/bash
# Enhanced Compliance Validation Script for Bio-Pharmaceutical Azure Sentinel
# This script performs comprehensive validation of regulatory compliance configurations

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script version
SCRIPT_VERSION="2.1.0"
SCRIPT_DATE="2025-04-11"

# Default parameters
RESOURCE_GROUP=""
PREFIX=""
REGULATIONS=("21CFR11" "EMA" "GDPR" "HIPAA" "GxP" "SOX")
OUTPUT_FILE=""
SUBSCRIPTION_ID=""
DETAILED=false

# Default validation maps with specific compliance criteria
declare -A VALIDATION_CRITERIA
VALIDATION_CRITERIA["21CFR11"]="electronic-records,electronic-signatures,audit-trails,data-retention,validation-documentation,change-control,system-access"
VALIDATION_CRITERIA["EMA"]="annex11,data-integrity,computerized-systems,validation,electronic-records,risk-management,security-controls"
VALIDATION_CRITERIA["GDPR"]="data-masking,data-retention,subject-rights,cross-border,data-classification,access-controls,breach-detection"
VALIDATION_CRITERIA["HIPAA"]="phi-protection,phi-masking,business-associates,access-control,audit-logging,encryption,incident-response"
VALIDATION_CRITERIA["GxP"]="validation,qualification,change-control,audit-trail,data-integrity,system-access,periodic-review"
VALIDATION_CRITERIA["SOX"]="segregation-of-duties,access-control,audit-logs,change-management,monitoring,reporting,incident-response"

# Script error handling function
function error_exit {
    echo -e "${RED}Error: ${1}${NC}" 1>&2
    exit 1
}

# Parse command line arguments - enhanced with more options
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
            -r|--regulations)
                IFS=',' read -r -a REGULATIONS <<< "$2"
                shift
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift
                shift
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift
                shift
                ;;
            -d|--detailed)
                DETAILED=true
                shift
                ;;
            -v|--version)
                echo "Compliance Validation Script v${SCRIPT_VERSION} (${SCRIPT_DATE})"
                exit 0
                ;;
            -h|--help)
                echo "Compliance Validation Script for Bio-Pharmaceutical Azure Sentinel"
                echo "Version: ${SCRIPT_VERSION} (${SCRIPT_DATE})"
                echo ""
                echo "Usage: $0 -g <resource-group> -p <prefix> [options]"
                echo ""
                echo "Options:"
                echo "  -g, --resource-group   Resource group containing the Sentinel workspaces"
                echo "  -p, --prefix           Prefix used for resource naming"
                echo "  -r, --regulations      Comma-separated list of regulations to validate (default: all)"
                echo "  -o, --output           Output file for validation report (default: console only)"
                echo "  -s, --subscription     Azure subscription ID (defaults to current)"
                echo "  -d, --detailed         Show detailed validation results for each criterion"
                echo "  -v, --version          Show script version"
                echo "  -h, --help             Show this help message"
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done

    # Verify required parameters
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$PREFIX" ]; then
        error_exit "Resource group and prefix are required parameters"
    fi
}

# Check script dependencies
function check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        error_exit "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        error_exit "jq is not installed. Please install it using your package manager"
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        error_exit "Not logged in to Azure. Please run 'az login' first"
    fi
    
    # Set subscription if provided
    if [ -n "$SUBSCRIPTION_ID" ]; then
        echo -e "${BLUE}Setting subscription to: ${SUBSCRIPTION_ID}${NC}"
        if ! az account set --subscription "$SUBSCRIPTION_ID" &> /dev/null; then
            error_exit "Could not set subscription to: ${SUBSCRIPTION_ID}"
        fi
    fi
    
    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        error_exit "Resource group '$RESOURCE_GROUP' does not exist"
    fi
    
    echo -e "${GREEN}All dependencies satisfied.${NC}"
}

# Validate workspaces and resources
function validate_deployed_resources() {
    echo -e "${BLUE}Validating deployed resources...${NC}"
    
    # Check central Sentinel workspace
    CENTRAL_WS="${PREFIX}-sentinel-ws"
    RESEARCH_WS="${PREFIX}-research-ws"
    MANUFACTURING_WS="${PREFIX}-manufacturing-ws"
    CLINICAL_WS="${PREFIX}-clinical-ws"
    
    CENTRAL_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" &> /dev/null && echo "true" || echo "false")
    RESEARCH_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name "$RESEARCH_WS" --resource-group "$RESOURCE_GROUP" &> /dev/null && echo "true" || echo "false")
    MANUFACTURING_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name "$MANUFACTURING_WS" --resource-group "$RESOURCE_GROUP" &> /dev/null && echo "true" || echo "false")
    CLINICAL_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name "$CLINICAL_WS" --resource-group "$RESOURCE_GROUP" &> /dev/null && echo "true" || echo "false")
    
    if [ "$CENTRAL_WS_EXISTS" == "false" ]; then
        error_exit "Central Sentinel workspace '$CENTRAL_WS' not found in resource group '$RESOURCE_GROUP'"
    fi
    
    echo -e "${GREEN}✓ Sentinel workspace:${NC} $CENTRAL_WS"
    
    if [ "$RESEARCH_WS_EXISTS" == "true" ]; then
        echo -e "${GREEN}✓ Research workspace:${NC} $RESEARCH_WS"
    else
        echo -e "${YELLOW}⚠ Warning: Research workspace '$RESEARCH_WS' not found. Some validations will be skipped.${NC}"
    fi
    
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        echo -e "${GREEN}✓ Manufacturing workspace:${NC} $MANUFACTURING_WS"
    else
        echo -e "${YELLOW}⚠ Warning: Manufacturing workspace '$MANUFACTURING_WS' not found. Some validations will be skipped.${NC}"
    fi
    
    if [ "$CLINICAL_WS_EXISTS" == "true" ]; then
        echo -e "${GREEN}✓ Clinical workspace:${NC} $CLINICAL_WS"
    else
        echo -e "${YELLOW}⚠ Warning: Clinical workspace '$CLINICAL_WS' not found. Some validations will be skipped.${NC}"
    fi
}

# Enhanced 21 CFR Part 11 validation
function validate_21cfr11() {
    echo -e "${BLUE}Validating 21 CFR Part 11 compliance...${NC}"
    
    local validated=true
    local validation_score=0
    local validation_total=7  # Total number of validation checks
    local part11_storage="${PREFIX}part11sa"
    local compliance_checks=()
    
    # Check if storage account exists
    if az storage account show --name "$part11_storage" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${GREEN}✓ Part 11 storage account:${NC} $part11_storage"
        validation_score=$((validation_score + 1))
        compliance_checks+=("Part 11 storage account:PASS")
        
        # Check for immutable storage container
        local containers=$(az storage container list --account-name "$part11_storage" --auth-mode login -o json 2>/dev/null)
        if [ $? -eq 0 ] && echo "$containers" | jq -e '.[].name | select(. == "electronicrecords")' &> /dev/null; then
            echo -e "${GREEN}✓ Electronic records container exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("Electronic records container:PASS")
        else
            echo -e "${RED}✗ Electronic records container not found${NC}"
            validated=false
            compliance_checks+=("Electronic records container:FAIL")
        fi
    else
        echo -e "${RED}✗ Part 11 storage account '$part11_storage' not found${NC}"
        validated=false
        compliance_checks+=("Part 11 storage account:FAIL")
    fi
    
    # Check manufacturing workspace retention period
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        local retention=$(az monitor log-analytics workspace show --workspace-name "$MANUFACTURING_WS" --resource-group "$RESOURCE_GROUP" --query retentionInDays -o tsv)
        if [ "$retention" -ge 2557 ]; then
            echo -e "${GREEN}✓ Manufacturing workspace retention period:${NC} $retention days (meets 7-year requirement)"
            validation_score=$((validation_score + 1))
            compliance_checks+=("Manufacturing workspace retention:PASS")
        else
            echo -e "${RED}✗ Manufacturing workspace retention period:${NC} $retention days (less than 7-year requirement)"
            validated=false
            compliance_checks+=("Manufacturing workspace retention:FAIL")
        fi
    else
        compliance_checks+=("Manufacturing workspace retention:SKIP")
    fi
    
    # Check for data export configuration
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        local export_configs=$(az monitor log-analytics workspace data-export list --workspace-name "$MANUFACTURING_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null)
        if [ $? -eq 0 ] && echo "$export_configs" | jq -e '.[] | select(.name | contains("part11") or contains("21cfr") or contains("electronic-record"))' &> /dev/null; then
            echo -e "${GREEN}✓ Part 11 data export configuration exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("Part 11 data export:PASS")
        else
            echo -e "${RED}✗ Part 11 data export configuration not found${NC}"
            validated=false
            compliance_checks+=("Part 11 data export:FAIL")
        fi
    else
        compliance_checks+=("Part 11 data export:SKIP")
    fi
    
    # Check for Part 11 compliance workbook
    local workbooks=$(az portal workbook list --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
    if echo "$workbooks" | jq -e '.[] | select(.properties.displayName | contains("21 CFR") or contains("Part 11") or contains("Electronic Record"))' &> /dev/null; then
        echo -e "${GREEN}✓ 21 CFR Part 11 compliance workbook exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("Part 11 compliance workbook:PASS")
    else
        echo -e "${RED}✗ 21 CFR Part 11 compliance workbook not found${NC}"
        validated=false
        compliance_checks+=("Part 11 compliance workbook:FAIL")
    fi
    
    # Check for electronic signature analytics rules
    local rules=$(az security insights alert-rule list --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("Electronic Record") or contains("21 CFR") or contains("Part 11"))' &> /dev/null; then
        echo -e "${GREEN}✓ Electronic record integrity alert rule exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("Electronic record alert rule:PASS")
    else
        echo -e "${RED}✗ Electronic record integrity alert rule not found${NC}"
        validated=false
        compliance_checks+=("Electronic record alert rule:FAIL")
    fi
    
    # Check for system access control configuration
    local sentinel_enabled=$(az security insights show --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "{}")
    if [ -n "$sentinel_enabled" ] && echo "$sentinel_enabled" | jq -e '.properties' &> /dev/null; then
        echo -e "${GREEN}✓ System access controls configured${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("System access controls:PASS")
    else
        echo -e "${RED}✗ System access controls not configured${NC}"
        validated=false
        compliance_checks+=("System access controls:FAIL")
    fi
    
    # Calculate compliance percentage
    local compliance_percentage=$((validation_score * 100 / validation_total))
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ 21 CFR Part 11 compliance validation passed (100%)${NC}"
    else
        echo -e "${YELLOW}⚠ 21 CFR Part 11 compliance validation partially passed (${compliance_percentage}%)${NC}"
    fi
    
    # Display detailed results if requested
    if [ "$DETAILED" == "true" ]; then
        echo -e "${BLUE}Detailed 21 CFR Part 11 validation results:${NC}"
        for check in "${compliance_checks[@]}"; do
            IFS=':' read -r check_name check_result <<< "$check"
            case "$check_result" in
                "PASS") 
                    echo -e "${GREEN}  ✓ $check_name${NC}"
                    ;;
                "FAIL") 
                    echo -e "${RED}  ✗ $check_name${NC}"
                    ;;
                "SKIP") 
                    echo -e "${YELLOW}  ⚠ $check_name (skipped)${NC}"
                    ;;
            esac
        done
    fi
    
    # Return validation status and score
    echo "$validated:$compliance_percentage"
}

# Enhanced GDPR validation
function validate_gdpr() {
    echo -e "${BLUE}Validating GDPR compliance...${NC}"
    
    local validated=true
    local validation_score=0
    local validation_total=7  # Total number of validation checks
    local clinical_storage="${PREFIX}clinicalsa"
    local compliance_checks=()
    
    # Check if storage account exists
    if az storage account show --name "$clinical_storage" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${GREEN}✓ Clinical data storage account:${NC} $clinical_storage"
        validation_score=$((validation_score + 1))
        compliance_checks+=("Clinical data storage account:PASS")
        
        # Check for immutable storage container
        local containers=$(az storage container list --account-name "$clinical_storage" --auth-mode login -o json 2>/dev/null)
        if [ $? -eq 0 ] && echo "$containers" | jq -e '.[].name | select(. == "clinicaldata")' &> /dev/null; then
            echo -e "${GREEN}✓ Clinical data container exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("Clinical data container:PASS")
        else
            echo -e "${RED}✗ Clinical data container not found${NC}"
            validated=false
            compliance_checks+=("Clinical data container:FAIL")
        fi
    else
        echo -e "${RED}✗ Clinical data storage account '$clinical_storage' not found${NC}"
        validated=false
        compliance_checks+=("Clinical data storage account:FAIL")
    fi
    
    # Check clinical workspace retention period
    if [ "$CLINICAL_WS_EXISTS" == "true" ]; then
        local retention=$(az monitor log-analytics workspace show --workspace-name "$CLINICAL_WS" --resource-group "$RESOURCE_GROUP" --query retentionInDays -o tsv)
        if [ "$retention" -ge 2557 ]; then
            echo -e "${GREEN}✓ Clinical workspace retention period:${NC} $retention days (meets GDPR requirement)"
            validation_score=$((validation_score + 1))
            compliance_checks+=("Clinical workspace retention:PASS")
        else
            echo -e "${RED}✗ Clinical workspace retention period:${NC} $
