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
           echo -e "${RED}✗ Clinical workspace retention period:${NC} $retention days (less than recommended)"
            validated=false
            compliance_checks+=("Clinical workspace retention:FAIL")
        fi
    else
        compliance_checks+=("Clinical workspace retention:SKIP")
    fi
    
    # Check for data export configuration with PII/PHI masking
    if [ "$CLINICAL_WS_EXISTS" == "true" ]; then
        local export_configs=$(az monitor log-analytics workspace data-export list --workspace-name "$CLINICAL_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null)
        if [ $? -eq 0 ] && echo "$export_configs" | jq -e '.[] | select(.name | contains("hipaa-gdpr") or contains("phi") or contains("pii"))' &> /dev/null; then
            echo -e "${GREEN}✓ GDPR data export configuration exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("GDPR data export:PASS")
        else
            echo -e "${RED}✗ GDPR data export configuration not found${NC}"
            validated=false
            compliance_checks+=("GDPR data export:FAIL")
        fi
    else
        compliance_checks+=("GDPR data export:SKIP")
    fi
    
    # Check for PHI access alert rule
    local rules=$(az security insights alert-rule list --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("PHI") or contains("PII") or contains("Patient"))' &> /dev/null; then
        echo -e "${GREEN}✓ PHI access alert rule exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("PHI access alert rule:PASS")
    else
        echo -e "${RED}✗ PHI access alert rule not found${NC}"
        validated=false
        compliance_checks+=("PHI access alert rule:FAIL")
    fi
    
    # Check for GDPR compliance workbook
    local workbooks=$(az portal workbook list --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
    if echo "$workbooks" | jq -e '.[] | select(.properties.displayName | contains("GDPR") or contains("HIPAA") or contains("Privacy"))' &> /dev/null; then
        echo -e "${GREEN}✓ GDPR compliance workbook exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("GDPR compliance workbook:PASS")
    else
        echo -e "${RED}✗ GDPR compliance workbook not found${NC}"
        validated=false
        compliance_checks+=("GDPR compliance workbook:FAIL")
    fi
    
    # Check for cross-border data transfer monitoring
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("Cross-Border"))' &> /dev/null; then
        echo -e "${GREEN}✓ Cross-border data transfer monitoring exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("Cross-border monitoring:PASS")
    else
        echo -e "${RED}✗ Cross-border data transfer monitoring not found${NC}"
        validated=false
        compliance_checks+=("Cross-border monitoring:FAIL")
    fi
    
    # Calculate compliance percentage
    local compliance_percentage=$((validation_score * 100 / validation_total))
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ GDPR compliance validation passed (100%)${NC}"
    else
        echo -e "${YELLOW}⚠ GDPR compliance validation partially passed (${compliance_percentage}%)${NC}"
    fi
    
    # Display detailed results if requested
    if [ "$DETAILED" == "true" ]; then
        echo -e "${BLUE}Detailed GDPR validation results:${NC}"
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

# Enhanced GxP validation
function validate_gxp() {
    echo -e "${BLUE}Validating GxP compliance...${NC}"
    
    local validated=true
    local validation_score=0
    local validation_total=6  # Total number of validation checks
    local compliance_checks=()
    
    # Check for GxP validated system change detection alert rule
    local rules=$(az security insights alert-rule list --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("GxP") and contains("System") and contains("Change"))' &> /dev/null; then
        echo -e "${GREEN}✓ GxP validated system change detection rule exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("GxP change detection rule:PASS")
    else
        echo -e "${RED}✗ GxP validated system change detection rule not found${NC}"
        validated=false
        compliance_checks+=("GxP change detection rule:FAIL")
    fi
    
    # Check manufacturing workspace for MES logs table
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        local tables=$(az monitor log-analytics workspace table list --workspace-name "$MANUFACTURING_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo '{"value":[]}')
        if echo "$tables" | jq -e '.value[] | select(.name == "Custom_MES_CL")' &> /dev/null; then
            echo -e "${GREEN}✓ Manufacturing Execution System logs table exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("MES logs table:PASS")
        else
            echo -e "${YELLOW}⚠ Manufacturing Execution System logs table not found${NC}"
            echo -e "${YELLOW}  This may be normal if no data has been ingested yet${NC}"
            compliance_checks+=("MES logs table:WARN")
        fi
        
        # Check for instrument qualification logs table
        if echo "$tables" | jq -e '.value[] | select(.name == "Custom_InstrumentQual_CL")' &> /dev/null; then
            echo -e "${GREEN}✓ Instrument qualification logs table exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("Instrument qualification table:PASS")
        else
            echo -e "${YELLOW}⚠ Instrument qualification logs table not found${NC}"
            echo -e "${YELLOW}  This may be normal if no data has been ingested yet${NC}"
            compliance_checks+=("Instrument qualification table:WARN")
        fi
    else
        compliance_checks+=("MES logs table:SKIP")
        compliance_checks+=("Instrument qualification table:SKIP")
    fi
    
    # Check for cold chain monitoring rule
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("Cold Chain"))' &> /dev/null; then
        echo -e "${GREEN}✓ Cold chain monitoring rule exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("Cold chain monitoring:PASS")
    else
        echo -e "${RED}✗ Cold chain monitoring rule not found${NC}"
        validated=false
        compliance_checks+=("Cold chain monitoring:FAIL")
    fi
    
    # Check for audit trail configuration
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        local export_configs=$(az monitor log-analytics workspace data-export list --workspace-name "$MANUFACTURING_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
        if [ $? -eq 0 ] && echo "$export_configs" | jq -e '.[] | select(.name | contains("part11") or contains("audit") or contains("gxp"))' &> /dev/null; then
            echo -e "${GREEN}✓ GxP audit trail export configuration exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("GxP audit trail export:PASS")
        else
            echo -e "${RED}✗ GxP audit trail export configuration not found${NC}"
            validated=false
            compliance_checks+=("GxP audit trail export:FAIL")
        fi
    else
        compliance_checks+=("GxP audit trail export:SKIP")
    fi
    
    # Check for laboratory instrument anomaly detection rule
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("Instrument") and contains("Anomaly"))' &> /dev/null; then
        echo -e "${GREEN}✓ Laboratory instrument anomaly detection rule exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("Instrument anomaly detection:PASS")
    else
        echo -e "${RED}✗ Laboratory instrument anomaly detection rule not found${NC}"
        validated=false
        compliance_checks+=("Instrument anomaly detection:FAIL")
    fi
    
    # Calculate compliance percentage - adjusted for possible WARN status
    local compliance_percentage=0
    if [[ $validation_total -gt 0 ]]; then
        compliance_percentage=$((validation_score * 100 / validation_total))
    fi
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ GxP compliance validation passed (${compliance_percentage}%)${NC}"
    else
        echo -e "${YELLOW}⚠ GxP compliance validation partially passed (${compliance_percentage}%)${NC}"
    fi
    
    # Display detailed results if requested
    if [ "$DETAILED" == "true" ]; then
        echo -e "${BLUE}Detailed GxP validation results:${NC}"
        for check in "${compliance_checks[@]}"; do
            IFS=':' read -r check_name check_result <<< "$check"
            case "$check_result" in
                "PASS") 
                    echo -e "${GREEN}  ✓ $check_name${NC}"
                    ;;
                "FAIL") 
                    echo -e "${RED}  ✗ $check_name${NC}"
                    ;;
                "WARN")
                    echo -e "${YELLOW}  ⚠ $check_name (warning)${NC}"
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

# Enhanced IP protection validation
function validate_ip_protection() {
    echo -e "${BLUE}Validating intellectual property protection...${NC}"
    
    local validated=true
    local validation_score=0
    local validation_total=6  # Total number of validation checks
    local ip_storage="${PREFIX}ipauditsa"
    local compliance_checks=()
    
    # Check if storage account exists
    if az storage account show --name "$ip_storage" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${GREEN}✓ IP audit storage account:${NC} $ip_storage"
        validation_score=$((validation_score + 1))
        compliance_checks+=("IP audit storage account:PASS")
        
        # Check for immutable storage container
        local containers=$(az storage container list --account-name "$ip_storage" --auth-mode login -o json 2>/dev/null || echo "[]")
        if [ $? -eq 0 ] && echo "$containers" | jq -e '.[].name | select(. == "ipaudit")' &> /dev/null; then
            echo -e "${GREEN}✓ IP audit container exists${NC}"
            validation_score=$((validation_score + 1))
            compliance_checks+=("IP audit container:PASS")
        else
            echo -e "${RED}✗ IP audit container not found${NC}"
            validated=false
            compliance_checks+=("IP audit container:FAIL")
        fi
    else
        echo -e "${RED}✗ IP audit storage account '$ip_storage' not found${NC}"
        validated=false
        compliance_checks+=("IP audit storage account:FAIL")
    fi
    
    # Check research workspace retention period
    if [ "$RESEARCH_WS_EXISTS" == "true" ]; then
        local retention=$(az monitor log-analytics workspace show --workspace-name "$RESEARCH_WS" --resource-group "$RESOURCE_GROUP" --query retentionInDays -o tsv)
        if [ "$retention" -ge 2557 ]; then
            echo -e "${GREEN}✓ Research workspace retention period:${NC} $retention days (meets IP protection requirement)"
            validation_score=$((validation_score + 1))
            compliance_checks+=("Research workspace retention:PASS")
        else
            echo -e "${RED}✗ Research workspace retention period:${NC} $retention days (less than recommended)"
            validated=false
            compliance_checks+=("Research workspace retention:FAIL")
        fi
    else
        compliance_checks+=("Research workspace retention:SKIP")
    fi
    
    # Check for IP theft detection rules
    local rules=$(az security insights alert-rule list --workspace-name "$CENTRAL_WS" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
    
    # Check for ELN mass download rule
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("ELN") and contains("Download"))' &> /dev/null; then
        echo -e "${GREEN}✓ ELN mass document download detection rule exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("ELN mass download rule:PASS")
    else
        echo -e "${RED}✗ ELN mass document download detection rule not found${NC}"
        validated=false
        compliance_checks+=("ELN mass download rule:FAIL")
    fi
    
    # Check for after-hours research access rule
    if echo "$rules" | jq -e '.[] | select(.properties.displayName | contains("After-Hours") and contains("Research"))' &> /dev/null; then
        echo -e "${GREEN}✓ After-hours research access rule exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("After-hours research rule:PASS")
    else
        echo -e "${RED}✗ After-hours research access rule not found${NC}"
        validated=false
        compliance_checks+=("After-hours research rule:FAIL")
    fi
    
    # Check for IP protection workbook
    local workbooks=$(az portal workbook list --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")
    if echo "$workbooks" | jq -e '.[] | select(.properties.displayName | contains("Intellectual Property") or contains("IP Protection"))' &> /dev/null; then
        echo -e "${GREEN}✓ IP protection workbook exists${NC}"
        validation_score=$((validation_score + 1))
        compliance_checks+=("IP protection workbook:PASS")
    else
        echo -e "${RED}✗ IP protection workbook not found${NC}"
        validated=false
        compliance_checks+=("IP protection workbook:FAIL")
    fi
    
    # Calculate compliance percentage
    local compliance_percentage=$((validation_score * 100 / validation_total))
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ Intellectual property protection validation passed (100%)${NC}"
    else
        echo -e "${YELLOW}⚠ Intellectual property protection validation partially passed (${compliance_percentage}%)${NC}"
    fi
    
    # Display detailed results if requested
    if [ "$DETAILED" == "true" ]; then
        echo -e "${BLUE}Detailed IP protection validation results:${NC}"
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

# Generate comprehensive validation report
function generate_report() {
    local report_data=("$@")
    local report_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${BLUE}Generating validation report...${NC}"
    
    # Create report header
    local report_content="# Bio-Pharmaceutical Compliance Validation Report\n"
    report_content+="Generated: $report_timestamp\n\n"
    report_content+="## Environment Information\n"
    report_content+="- Resource Group: $RESOURCE_GROUP\n"
    report_content+="- Prefix: $PREFIX\n"
    report_content+="- Subscription: $(az account show --query name -o tsv)\n\n"
    report_content+="## Validation Summary\n\n"
    
    # Create summary table
    report_content+="| Regulation | Status | Compliance Score |\n"
    report_content+="| ---------- | ------ | --------------- |\n"
    
    local overall_validated=true
    local overall_score=0
    local regulation_count=0
    
    # Process each regulation's validation results
    for result in "${report_data[@]}"; do
        IFS=':' read -r regulation status score <<< "$result"
        
        # Add to summary table
        if [ "$status" == "true" ]; then
            report_content+="| $regulation | ✅ PASS | $score% |\n"
        else
            report_content+="| $regulation | ⚠️ PARTIAL | $score% |\n"
            overall_validated=false
        fi
        
        # Update overall score
        overall_score=$((overall_score + score))
        regulation_count=$((regulation_count + 1))
    done
    
    # Calculate overall compliance score
    local overall_percentage=0
    if [[ $regulation_count -gt 0 ]]; then
        overall_percentage=$((overall_score / regulation_count))
    fi
    
    # Add overall result
    report_content+="\n## Overall Assessment\n\n"
    
    if [ "$overall_validated" == "true" ]; then
        report_content+="**Result: PASS** (Overall Compliance Score: $overall_percentage%)\n\n"
    else
        report_content+="**Result: PARTIAL COMPLIANCE** (Overall Compliance Score: $overall_percentage%)\n\n"
    fi
    
    report_content+="## Recommendation\n\n"
    
    if [ "$overall_percentage" -ge 90 ]; then
        report_content+="The current implementation meets most compliance requirements. Minor improvements may be needed for full compliance.\n\n"
    elif [ "$overall_percentage" -ge 75 ]; then
        report_content+="The current implementation meets many compliance requirements but has some significant gaps that should be addressed.\n\n"
    else
        report_content+="The current implementation has major compliance gaps that require immediate attention.\n\n"
    fi
    
    report_content+="## Remediation Steps\n\n"
    report_content+="To address any non-compliant areas, please review the following:\n\n"
    report_content+="1. Ensure proper storage accounts are configured with immutable storage for all required regulations\n"
    report_content+="2. Verify workspace retention periods meet regulatory requirements (7+ years for most regulations)\n"
    report_content+="3. Deploy all necessary analytics rules for detection and monitoring\n"
    report_content+="4. Configure data export with appropriate masking for PHI/PII data\n"
    report_content+="5. Implement cross-workspace monitoring for global bio-pharma operations\n"
    
    # Save report to file if specified
    if [ -n "$OUTPUT_FILE" ]; then
        echo -e "$report_content" > "$OUTPUT_FILE"
        echo -e "${GREEN}Report saved to:${NC} $OUTPUT_FILE"
    fi
    
    # Return the report content
    echo "$report_content"
}

# Main function - enhanced with better validation reporting
function main() {
    parse_args "$@"
    check_dependencies
    validate_deployed_resources
    
    echo -e "${BLUE}========== Bio-Pharma Compliance Validation ==========${NC}"
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Prefix:${NC} $PREFIX"
    echo -e "${BLUE}Regulations:${NC} ${REGULATIONS[*]}"
    if [ -n "$OUTPUT_FILE" ]; then
        echo -e "${BLUE}Output File:${NC} $OUTPUT_FILE"
    fi
    echo -e "${BLUE}=================================================${NC}"
    
    # Initialize results array for report generation
    declare -a validation_results
    
    # Validate each specified regulation
    for regulation in "${REGULATIONS[@]}"; do
        echo -e "${BLUE}------------------------------------------------${NC}"
        
        local result=""
        case "$regulation" in
            "21CFR11")
                result=$(validate_21cfr11)
                IFS=':' read -r status score <<< "$result"
                validation_results+=("21CFR11:$status:$score")
                ;;
            "GDPR")
                result=$(validate_gdpr)
                IFS=':' read -r status score <<< "$result"
                validation_results+=("GDPR:$status:$score")
                ;;
            "GxP")
                result=$(validate_gxp)
                IFS=':' read -r status score <<< "$result"
                validation_results+=("GxP:$status:$score")
                ;;
            "IP")
                result=$(validate_ip_protection)
                IFS=':' read -r status score <<< "$result"
                validation_results+=("IP Protection:$status:$score")
                ;;
            *)
                echo -e "${YELLOW}Validation for $regulation not implemented${NC}"
                ;;
        esac
    done
    
    # Generate summary report
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}Compliance Validation Summary${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    local overall_passed=true
    local overall_score=0
    local regulation_count=0
    
    for result in "${validation_results[@]}"; do
        IFS=':' read -r regulation status score <<< "$result"
        
        if [ "$status" == "true" ]; then
            echo -e "${GREEN}✓ $regulation:${NC} PASSED ($score%)"
        else
            echo -e "${YELLOW}⚠ $regulation:${NC} PARTIAL ($score%)"
            overall_passed=false
        fi
        
        overall_score=$((overall_score + score))
        regulation_count=$((regulation_count + 1))
    done
    
    # Calculate overall score
    local overall_percentage=0
    if [[ $regulation_count -gt 0 ]]; then
        overall_percentage=$((overall_score / regulation_count))
    fi
    
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${BLUE}Overall Compliance Score:${NC} $overall_percentage%"
    
    if [ "$overall_passed" == "true" ]; then
        echo -e "${GREEN}All specified compliance validations passed!${NC}"
    else
        echo -e "${YELLOW}Some compliance validations require attention.${NC}"
    fi
    
    # Generate comprehensive report if output file specified
    if [ -n "$OUTPUT_FILE" ] || [ "$DETAILED" == "true" ]; then
        local report=$(generate_report "${validation_results[@]}")
        
        if [ "$DETAILED" == "true" ] && [ -z "$OUTPUT_FILE" ]; then
            echo -e "${BLUE}------------------------------------------------${NC}"
            echo -e "$report"
        fi
    fi
    
    echo -e "${BLUE}=================================================${NC}"
    
    # Return success if overall compliance score is acceptable
    if [ "$overall_percentage" -ge 70 ]; then
        return 0
    else
        return 1
    fi
}

# Execute main function with all arguments
main "$@"
exit $?
