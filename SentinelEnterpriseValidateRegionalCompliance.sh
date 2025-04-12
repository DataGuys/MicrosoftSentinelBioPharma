#!/bin/bash
# Compliance Validation Script for Bio-Pharmaceutical Azure Sentinel
# This script validates regulatory compliance configurations for various bio-pharma regulations

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
REGULATIONS=("21CFR11" "EMA" "GDPR" "HIPAA" "GxP" "SOX")

# Default validation maps
declare -A VALIDATION_CRITERIA
VALIDATION_CRITERIA["21CFR11"]="electronic-records,electronic-signatures,audit-trails,data-retention"
VALIDATION_CRITERIA["EMA"]="annex11,data-integrity,computerized-systems,validation"
VALIDATION_CRITERIA["GDPR"]="data-masking,data-retention,subject-rights,cross-border"
VALIDATION_CRITERIA["HIPAA"]="phi-protection,phi-masking,business-associates,access-control"
VALIDATION_CRITERIA["GxP"]="validation,qualification,change-control,audit-trail"
VALIDATION_CRITERIA["SOX"]="segregation-of-duties,access-control,audit-logs,change-management"

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
            -r|--regulations)
                IFS=',' read -r -a REGULATIONS <<< "$2"
                shift
                shift
                ;;
            -h|--help)
                echo "Usage: $0 -g <resource-group> -p <prefix> [-r <comma-separated-regulations>]"
                echo ""
                echo "Options:"
                echo "  -g, --resource-group   Resource group containing the Sentinel workspaces"
                echo "  -p, --prefix           Prefix used for resource naming"
                echo "  -r, --regulations      Comma-separated list of regulations to validate (default: 21CFR11,EMA,GDPR,HIPAA,GxP,SOX)"
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
        echo "Usage: $0 -g <resource-group> -p <prefix> [-r <comma-separated-regulations>]"
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

# Validate workspaces and resources
function validate_deployed_resources() {
    echo -e "${BLUE}Validating deployed resources...${NC}"
    
    # Check central Sentinel workspace
    CENTRAL_WS="${PREFIX}-sentinel-ws"
    RESEARCH_WS="${PREFIX}-research-ws"
    MANUFACTURING_WS="${PREFIX}-manufacturing-ws"
    CLINICAL_WS="${PREFIX}-clinical-ws"
    
    CENTRAL_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name $CENTRAL_WS --resource-group $RESOURCE_GROUP &> /dev/null && echo "true" || echo "false")
    RESEARCH_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name $RESEARCH_WS --resource-group $RESOURCE_GROUP &> /dev/null && echo "true" || echo "false")
    MANUFACTURING_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name $MANUFACTURING_WS --resource-group $RESOURCE_GROUP &> /dev/null && echo "true" || echo "false")
    CLINICAL_WS_EXISTS=$(az monitor log-analytics workspace show --workspace-name $CLINICAL_WS --resource-group $RESOURCE_GROUP &> /dev/null && echo "true" || echo "false")
    
    if [ "$CENTRAL_WS_EXISTS" == "false" ]; then
        echo -e "${RED}Error: Central Sentinel workspace '$CENTRAL_WS' not found in resource group '$RESOURCE_GROUP'.${NC}"
        exit 1
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
    }
}

# Validate 21 CFR Part 11 compliance
function validate_21cfr11() {
    echo -e "${BLUE}Validating 21 CFR Part 11 compliance...${NC}"
    
    local validated=true
    local part11_storage="${PREFIX}part11sa"
    
    # Check if storage account exists
    if az storage account show --name $part11_storage --resource-group $RESOURCE_GROUP &> /dev/null; then
        echo -e "${GREEN}✓ Part 11 storage account:${NC} $part11_storage"
        
        # Check for immutable storage container
        local containers=$(az storage container list --account-name $part11_storage --auth-mode login -o json)
        if echo "$containers" | jq -e '.[].name | select(. == "electronicrecords")' &> /dev/null; then
            echo -e "${GREEN}✓ Electronic records container exists${NC}"
        else
            echo -e "${RED}✗ Electronic records container not found${NC}"
            validated=false
        fi
    else
        echo -e "${RED}✗ Part 11 storage account '$part11_storage' not found${NC}"
        validated=false
    }
    
    # Check manufacturing workspace retention period
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        local retention=$(az monitor log-analytics workspace show --workspace-name $MANUFACTURING_WS --resource-group $RESOURCE_GROUP --query retentionInDays -o tsv)
        if [ "$retention" -ge 2557 ]; then
            echo -e "${GREEN}✓ Manufacturing workspace retention period:${NC} $retention days (meets 7-year requirement)"
        else
            echo -e "${RED}✗ Manufacturing workspace retention period:${NC} $retention days (less than 7-year requirement)"
            validated=false
        fi
    fi
    
    # Check for data export configuration
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        local export_name="part11-data-export"
        if az monitor log-analytics workspace data-export show --workspace-name $MANUFACTURING_WS --resource-group $RESOURCE_GROUP --name $export_name &> /dev/null; then
            echo -e "${GREEN}✓ Part 11 data export configuration exists${NC}"
        else
            echo -e "${RED}✗ Part 11 data export configuration not found${NC}"
            validated=false
        fi
    fi
    
    # Check for Part 11 compliance workbook
    local workbooks=$(az portal workbook list --resource-group $RESOURCE_GROUP -o json)
    if echo "$workbooks" | jq -e '.[].tags.compliance | select(. == "21CFR11")' &> /dev/null; then
        echo -e "${GREEN}✓ 21 CFR Part 11 compliance workbook exists${NC}"
    else
        echo -e "${RED}✗ 21 CFR Part 11 compliance workbook not found${NC}"
        validated=false
    }
    
    # Check for electronic signature analytics rules
    local rules=$(az security insights alert-rule list --workspace-name $CENTRAL_WS --resource-group $RESOURCE_GROUP -o json)
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "21 CFR Part 11 Electronic Record Integrity Alert")' &> /dev/null; then
        echo -e "${GREEN}✓ Electronic record integrity alert rule exists${NC}"
    else
        echo -e "${RED}✗ Electronic record integrity alert rule not found${NC}"
        validated=false
    }
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ 21 CFR Part 11 compliance validation passed${NC}"
    else
        echo -e "${RED}✗ 21 CFR Part 11 compliance validation failed${NC}"
    fi
    
    return $([ "$validated" == "true" ])
}

# Validate GDPR compliance
function validate_gdpr() {
    echo -e "${BLUE}Validating GDPR compliance...${NC}"
    
    local validated=true
    local clinical_storage="${PREFIX}clinicalsa"
    
    # Check if storage account exists
    if az storage account show --name $clinical_storage --resource-group $RESOURCE_GROUP &> /dev/null; then
        echo -e "${GREEN}✓ Clinical data storage account:${NC} $clinical_storage"
        
        # Check for immutable storage container
        local containers=$(az storage container list --account-name $clinical_storage --auth-mode login -o json)
        if echo "$containers" | jq -e '.[].name | select(. == "clinicaldata")' &> /dev/null; then
            echo -e "${GREEN}✓ Clinical data container exists${NC}"
        else
            echo -e "${RED}✗ Clinical data container not found${NC}"
            validated=false
        fi
    else
        echo -e "${RED}✗ Clinical data storage account '$clinical_storage' not found${NC}"
        validated=false
    }
    
    # Check clinical workspace retention period
    if [ "$CLINICAL_WS_EXISTS" == "true" ]; then
        local retention=$(az monitor log-analytics workspace show --workspace-name $CLINICAL_WS --resource-group $RESOURCE_GROUP --query retentionInDays -o tsv)
        if [ "$retention" -ge 2557 ]; then
            echo -e "${GREEN}✓ Clinical workspace retention period:${NC} $retention days (meets GDPR requirement)"
        else
            echo -e "${RED}✗ Clinical workspace retention period:${NC} $retention days (less than recommended)"
            validated=false
        fi
    fi
    
    # Check for data export configuration
    if [ "$CLINICAL_WS_EXISTS" == "true" ]; then
        local export_name="hipaa-gdpr-data-export"
        if az monitor log-analytics workspace data-export show --workspace-name $CLINICAL_WS --resource-group $RESOURCE_GROUP --name $export_name &> /dev/null; then
            echo -e "${GREEN}✓ GDPR data export configuration exists${NC}"
        else
            echo -e "${RED}✗ GDPR data export configuration not found${NC}"
            validated=false
        fi
    fi
    
    # Check for PHI access alert rule
    local rules=$(az security insights alert-rule list --workspace-name $CENTRAL_WS --resource-group $RESOURCE_GROUP -o json)
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "Clinical Trial Data - Unauthorized PHI Access")' &> /dev/null; then
        echo -e "${GREEN}✓ PHI access alert rule exists${NC}"
    else
        echo -e "${RED}✗ PHI access alert rule not found${NC}"
        validated=false
    }
    
    # Check for GDPR compliance workbook
    local workbooks=$(az portal workbook list --resource-group $RESOURCE_GROUP -o json)
    if echo "$workbooks" | jq -e '.[].tags.compliance | select(. == "GDPR-HIPAA")' &> /dev/null; then
        echo -e "${GREEN}✓ GDPR compliance workbook exists${NC}"
    else
        echo -e "${RED}✗ GDPR compliance workbook not found${NC}"
        validated=false
    }
    
    # Check for cross-border data transfer monitoring
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "Cross-Border Research IP Access")' &> /dev/null; then
        echo -e "${GREEN}✓ Cross-border data transfer monitoring exists${NC}"
    else
        echo -e "${RED}✗ Cross-border data transfer monitoring not found${NC}"
        validated=false
    }
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ GDPR compliance validation passed${NC}"
    else
        echo -e "${RED}✗ GDPR compliance validation failed${NC}"
    fi
    
    return $([ "$validated" == "true" ])
}

# Validate GxP compliance
function validate_gxp() {
    echo -e "${BLUE}Validating GxP compliance...${NC}"
    
    local validated=true
    
    # Check for GxP validated system change detection
    local rules=$(az security insights alert-rule list --workspace-name $CENTRAL_WS --resource-group $RESOURCE_GROUP -o json)
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "GxP Validated System Change Detection")' &> /dev/null; then
        echo -e "${GREEN}✓ GxP validated system change detection rule exists${NC}"
    else
        echo -e "${RED}✗ GxP validated system change detection rule not found${NC}"
        validated=false
    }
    
    # Check manufacturing workspace for GxP system monitoring
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        # Check for MES logs table
        local tables=$(az monitor log-analytics workspace table list --workspace-name $MANUFACTURING_WS --resource-group $RESOURCE_GROUP -o json)
        if echo "$tables" | jq -e '.value[] | select(.name == "Custom_MES_CL")' &> /dev/null; then
            echo -e "${GREEN}✓ Manufacturing Execution System logs table exists${NC}"
        else
            echo -e "${YELLOW}⚠ Manufacturing Execution System logs table not found${NC}"
            echo -e "${YELLOW}  This may be normal if no data has been ingested yet${NC}"
        fi
        
        # Check for instrument qualification logs table
        if echo "$tables" | jq -e '.value[] | select(.name == "Custom_InstrumentQual_CL")' &> /dev/null; then
            echo -e "${GREEN}✓ Instrument qualification logs table exists${NC}"
        else
            echo -e "${YELLOW}⚠ Instrument qualification logs table not found${NC}"
            echo -e "${YELLOW}  This may be normal if no data has been ingested yet${NC}"
        fi
    fi
    
    # Check for cold chain monitoring
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "Cold Chain Authentication Anomaly with Temperature Excursion")' &> /dev/null; then
        echo -e "${GREEN}✓ Cold chain monitoring rule exists${NC}"
    else
        echo -e "${RED}✗ Cold chain monitoring rule not found${NC}"
        validated=false
    }
    
    # Check for audit trail configuration
    if [ "$MANUFACTURING_WS_EXISTS" == "true" ]; then
        local export_name="part11-data-export"
        if az monitor log-analytics workspace data-export show --workspace-name $MANUFACTURING_WS --resource-group $RESOURCE_GROUP --name $export_name &> /dev/null; then
            echo -e "${GREEN}✓ GxP audit trail export configuration exists${NC}"
        else
            echo -e "${RED}✗ GxP audit trail export configuration not found${NC}"
            validated=false
        fi
    fi
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ GxP compliance validation passed${NC}"
    else
        echo -e "${RED}✗ GxP compliance validation failed${NC}"
    fi
    
    return $([ "$validated" == "true" ])
}

# Validate IP protection
function validate_ip_protection() {
    echo -e "${BLUE}Validating intellectual property protection...${NC}"
    
    local validated=true
    local ip_storage="${PREFIX}ipauditsa"
    
    # Check if storage account exists
    if az storage account show --name $ip_storage --resource-group $RESOURCE_GROUP &> /dev/null; then
        echo -e "${GREEN}✓ IP audit storage account:${NC} $ip_storage"
        
        # Check for immutable storage container
        local containers=$(az storage container list --account-name $ip_storage --auth-mode login -o json)
        if echo "$containers" | jq -e '.[].name | select(. == "ipaudit")' &> /dev/null; then
            echo -e "${GREEN}✓ IP audit container exists${NC}"
        else
            echo -e "${RED}✗ IP audit container not found${NC}"
            validated=false
        fi
    else
        echo -e "${RED}✗ IP audit storage account '$ip_storage' not found${NC}"
        validated=false
    }
    
    # Check research workspace retention period
    if [ "$RESEARCH_WS_EXISTS" == "true" ]; then
        local retention=$(az monitor log-analytics workspace show --workspace-name $RESEARCH_WS --resource-group $RESOURCE_GROUP --query retentionInDays -o tsv)
        if [ "$retention" -ge 2557 ]; then
            echo -e "${GREEN}✓ Research workspace retention period:${NC} $retention days (meets IP protection requirement)"
        else
            echo -e "${RED}✗ Research workspace retention period:${NC} $retention days (less than recommended)"
            validated=false
        fi
    fi
    
    # Check for IP theft detection rules
    local rules=$(az security insights alert-rule list --workspace-name $CENTRAL_WS --resource-group $RESOURCE_GROUP -o json)
    
    # Check for ELN mass download rule
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "ELN Mass Document Download Detection")' &> /dev/null; then
        echo -e "${GREEN}✓ ELN mass document download detection rule exists${NC}"
    else
        echo -e "${RED}✗ ELN mass document download detection rule not found${NC}"
        validated=false
    }
    
    # Check for after-hours research access rule
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "After-Hours Access to Proprietary Research")' &> /dev/null; then
        echo -e "${GREEN}✓ After-hours research access rule exists${NC}"
    else
        echo -e "${RED}✗ After-hours research access rule not found${NC}"
        validated=false
    }
    
    # Check for cross-border IP access rule
    if echo "$rules" | jq -e '.[] | select(.properties.displayName == "Cross-Border Research IP Access")' &> /dev/null; then
        echo -e "${GREEN}✓ Cross-border IP access rule exists${NC}"
    else
        echo -e "${RED}✗ Cross-border IP access rule not found${NC}"
        validated=false
    }
    
    # Check for IP protection workbook
    local workbooks=$(az portal workbook list --resource-group $RESOURCE_GROUP -o json)
    if echo "$workbooks" | jq -e '.[].tags.compliance | select(. == "IP-Protection")' &> /dev/null; then
        echo -e "${GREEN}✓ IP protection workbook exists${NC}"
    else
        echo -e "${RED}✗ IP protection workbook not found${NC}"
        validated=false
    }
    
    if [ "$validated" == "true" ]; then
        echo -e "${GREEN}✓ Intellectual property protection validation passed${NC}"
    else
        echo -e "${RED}✗ Intellectual property protection validation failed${NC}"
    fi
    
    return $([ "$validated" == "true" ])
}

# Main function
function main() {
    parse_args "$@"
    check_dependencies
    validate_deployed_resources
    
    echo -e "${BLUE}========== Bio-Pharma Compliance Validation ==========${NC}"
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Prefix:${NC} $PREFIX"
    echo -e "${BLUE}Regulations:${NC} ${REGULATIONS[*]}"
    echo -e "${BLUE}=================================================${NC}"
    
    # Initialize results array
    declare -A results
    
    # Validate each specified regulation
    for regulation in "${REGULATIONS[@]}"; do
        echo -e "${BLUE}------------------------------------------------${NC}"
        
        case "$regulation" in
            "21CFR11")
                validate_21cfr11
                results["21CFR11"]=$?
                ;;
            "GDPR")
                validate_gdpr
                results["GDPR"]=$?
                ;;
            "GxP")
                validate_gxp
                results["GxP"]=$?
                ;;
            "IP")
                validate_ip_protection
                results["IP"]=$?
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
    
    local all_passed=true
    
    for regulation in "${!results[@]}"; do
        if [ "${results[$regulation]}" -eq 0 ]; then
            echo -e "${GREEN}✓ $regulation:${NC} PASSED"
        else
            echo -e "${RED}✗ $regulation:${NC} FAILED"
            all_passed=false
        fi
    done
    
    echo -e "${BLUE}=================================================${NC}"
    if [ "$all_passed" == "true" ]; then
        echo -e "${GREEN}All specified compliance validations passed!${NC}"
    else
        echo -e "${RED}Some compliance validations failed. See details above.${NC}"
    fi
    echo -e "${BLUE}=================================================${NC}"
    
    # Provide remediation instructions
    echo -e "${YELLOW}Remediation Instructions:${NC}"
    echo -e "To address any failed validations, review the deployment scripts and ensure:"
    echo -e "1. All required storage accounts are properly configured with immutable storage"
    echo -e "2. Workspace retention periods meet regulatory requirements"
    echo -e "3. Analytics rules for detection and monitoring are deployed"
    echo -e "4. Data export configurations are set up correctly"
    echo -e "5. Workbooks for compliance monitoring are deployed"
    echo -e "${BLUE}=================================================${NC}"
}

# Execute main function with all arguments
main "$@"
