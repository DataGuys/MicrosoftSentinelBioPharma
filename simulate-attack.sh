#!/bin/bash
# Bio-Pharmaceutical Attack Simulation Script
# This script simulates various attack scenarios in bio-pharmaceutical environments for testing Sentinel detection capabilities

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
PREFIX=""
SCENARIO="IP_Theft"  # Default scenario
INTENSITY="Medium"   # Default intensity
DURATION=30          # Default duration in minutes
TARGET=""            # Specific target for simulation (optional)
SUBSCRIPTION_ID=""
DRY_RUN=false
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
            -s|--scenario)
                SCENARIO="$2"
                shift
                shift
                ;;
            -i|--intensity)
                INTENSITY="$2"
                shift
                shift
                ;;
            -d|--duration)
                DURATION="$2"
                shift
                shift
                ;;
            -t|--target)
                TARGET="$2"
                shift
                shift
                ;;
            --subscription)
                SUBSCRIPTION_ID="$2"
                shift
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$PREFIX" ]; then
        echo -e "${RED}Error: Resource group and prefix are required parameters${NC}"
        echo -e "Use -h or --help for usage information"
        exit 1
    fi

    # Validate scenario
    if [[ ! "$SCENARIO" =~ ^(IP_Theft|Clinical_Data_Breach|Supply_Chain_Attack|Insider_Threat|Ransomware)$ ]]; then
        echo -e "${RED}Error: Invalid scenario. Valid options are: IP_Theft, Clinical_Data_Breach, Supply_Chain_Attack, Insider_Threat, Ransomware${NC}"
        exit 1
    fi

    # Validate intensity
    if [[ ! "$INTENSITY" =~ ^(Low|Medium|High)$ ]]; then
        echo -e "${RED}Error: Invalid intensity. Valid options are: Low, Medium, High${NC}"
        exit 1
    fi

    # Validate duration
    if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || [ "$DURATION" -lt 5 ] || [ "$DURATION" -gt 60 ]; then
        echo -e "${RED}Error: Duration must be a number between 5 and 60 minutes${NC}"
        exit 1
    fi
}

# Display help information
function display_help() {
    echo "Bio-Pharmaceutical Attack Simulation Script"
    echo "Version: $VERSION ($DATE)"
    echo ""
    echo "This script simulates various attack scenarios for testing Sentinel detection capabilities"
    echo ""
    echo "Usage: $0 -g <resource-group> -p <prefix> [options]"
    echo ""
    echo "Required Parameters:"
    echo "  -g, --resource-group   Resource group containing the Sentinel workspaces"
    echo "  -p, --prefix           Prefix used for resource naming"
    echo ""
    echo "Scenario Parameters:"
    echo "  -s, --scenario         Attack scenario to simulate (default: IP_Theft)"
    echo "                         Options: IP_Theft, Clinical_Data_Breach, Supply_Chain_Attack, Insider_Threat, Ransomware"
    echo "  -i, --intensity        Intensity of the simulation (default: Medium)"
    echo "                         Options: Low, Medium, High"
    echo "  -d, --duration         Duration of the simulation in minutes (default: 30, range: 5-60)"
    echo "  -t, --target           Specific target for the simulation (optional)"
    echo ""
    echo "Other Parameters:"
    echo "  --subscription         Azure subscription ID (defaults to current)"
    echo "  --dry-run              Show simulation steps without executing them"
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
    
    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${RED}Error: Resource group '$RESOURCE_GROUP' does not exist${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All dependencies satisfied.${NC}"
}

# Check if Sentinel workspace exists
function check_sentinel_workspace() {
    echo -e "${BLUE}Checking Sentinel workspace...${NC}"
    
    SENTINEL_WS="${PREFIX}-sentinel-ws"
    
    if ! az monitor log-analytics workspace show --workspace-name "$SENTINEL_WS" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${RED}Error: Sentinel workspace '$SENTINEL_WS' not found in resource group '$RESOURCE_GROUP'${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Sentinel workspace '$SENTINEL_WS' found.${NC}"
}

# Generate random data for simulation
function generate_random_data() {
    # Generate a random IP address
    function random_ip() {
        echo "$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 ))"
    }
    
    # Generate a random username
    function random_username() {
        local prefixes=("john" "jane" "bob" "alice" "dave" "sara" "mike" "lisa" "tom" "emma")
        local suffixes=("doe" "smith" "jones" "wang" "garcia" "rodriguez" "miller" "wilson" "patel" "lee")
        local domains=("company.com" "research.org" "pharm.net" "biotech.io" "medicine.co")
        
        local prefix=${prefixes[$(( RANDOM % ${#prefixes[@]} ))]}
        local suffix=${suffixes[$(( RANDOM % ${#suffixes[@]} ))]}
        local domain=${domains[$(( RANDOM % ${#domains[@]} ))]}
        
        echo "${prefix}.${suffix}@${domain}"
    }
    
    # Generate a random resource name
    function random_resource() {
        local prefixes=("Project" "Document" "File" "Database" "Server" "Application" "System")
        local suffixes=("Alpha" "Beta" "Gamma" "Delta" "Omega" "Prime" "Core" "Central" "Main")
        local numbers=$(( RANDOM % 1000 ))
        
        local prefix=${prefixes[$(( RANDOM % ${#prefixes[@]} ))]}
        local suffix=${suffixes[$(( RANDOM % ${#suffixes[@]} ))]}
        
        echo "${prefix}-${suffix}-${numbers}"
    }
    
    # Export the functions for use in simulation steps
    export -f random_ip
    export -f random_username
    export -f random_resource
}

# Simulate intellectual property theft
function simulate_ip_theft() {
    echo -e "${BLUE}Simulating intellectual property theft scenario...${NC}"
    
    local intensity_factor=1
    case "$INTENSITY" in
        "Low")
            intensity_factor=1
            ;;
        "Medium")
            intensity_factor=3
            ;;
        "High")
            intensity_factor=5
            ;;
    esac
    
    local steps=(
        "User authentication to research systems"
        "Unusual access patterns to sensitive documents"
        "Large volume data exports from Electronic Lab Notebook"
        "Access to multiple research projects in short timeframe"
        "After-hours access to formula database"
        "Multiple download events from research repository"
        "SSH connections to research servers from unusual locations"
        "USB storage device detection on research workstations"
        "VPN connections from unusual geographic locations"
        "Mass export of search results from internal research databases"
    )
    
    local system_targets=(
        "ELN System"
        "LIMS Database"
        "Research Document Repository"
        "Formula Management System"
        "Research Data Warehouse"
        "Patent Documentation System"
        "Clinical Data Repository (De-identified)"
        "Research Computation Grid"
        "Molecular Modeling System"
        "Research Collaboration Portal"
    )
    
    local target_system=""
    if [ -n "$TARGET" ]; then
        target_system="$TARGET"
    else
        target_system=${system_targets[$(( RANDOM % ${#system_targets[@]} ))]}
    fi
    
    echo -e "${YELLOW}Target System:${NC} $target_system"
    echo -e "${YELLOW}Intensity:${NC} $INTENSITY (factor: $intensity_factor)"
    echo -e "${YELLOW}Duration:${NC} $DURATION minutes"
    
    # Number of events to generate based on intensity
    local event_count=$((10 * intensity_factor))
    
    echo -e "${BLUE}Generating $event_count simulated events...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run mode - no events will be generated${NC}"
        echo -e "${YELLOW}Events that would be generated:${NC}"
        
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${BLUE}Event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            echo -e "  Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        done
    else
        # TODO: Replace this with actual event generation mechanism
        # For now, just simulate event generation
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${GREEN}Generating event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            
            # Simulate a delay between events
            sleep $((RANDOM % 5 + 1))
        done
    fi
    
    echo -e "${GREEN}IP theft simulation completed.${NC}"
}

# Simulate clinical data breach
function simulate_clinical_data_breach() {
    echo -e "${BLUE}Simulating clinical data breach scenario...${NC}"
    
    local intensity_factor=1
    case "$INTENSITY" in
        "Low")
            intensity_factor=1
            ;;
        "Medium")
            intensity_factor=3
            ;;
        "High")
            intensity_factor=5
            ;;
    esac
    
    local steps=(
        "Unusual CTMS authentication patterns"
        "Excessive PHI record access"
        "Mass export of patient records"
        "Unauthorized access to clinical trial database"
        "Modification of access permissions"
        "Unusual query patterns against patient database"
        "Cross-study data aggregation"
        "Unusual API calls to clinical data repositories"
        "Database export attempts"
        "Subject data export to unauthorized locations"
    )
    
    local system_targets=(
        "Clinical Trial Management System"
        "Electronic Data Capture System"
        "Patient Database"
        "Adverse Event Reporting System"
        "Clinical Data Repository"
        "Subject Enrollment Database"
        "Pharmacovigilance System"
        "Clinical Operations Dashboard"
        "eCOA/ePRO Systems"
        "Regulatory Document Management System"
    )
    
    local target_system=""
    if [ -n "$TARGET" ]; then
        target_system="$TARGET"
    else
        target_system=${system_targets[$(( RANDOM % ${#system_targets[@]} ))]}
    fi
    
    echo -e "${YELLOW}Target System:${NC} $target_system"
    echo -e "${YELLOW}Intensity:${NC} $INTENSITY (factor: $intensity_factor)"
    echo -e "${YELLOW}Duration:${NC} $DURATION minutes"
    
    # Number of events to generate based on intensity
    local event_count=$((8 * intensity_factor))
    
    echo -e "${BLUE}Generating $event_count simulated events...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run mode - no events will be generated${NC}"
        echo -e "${YELLOW}Events that would be generated:${NC}"
        
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${BLUE}Event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            echo -e "  Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        done
    else
        # TODO: Replace this with actual event generation mechanism
        # For now, just simulate event generation
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${GREEN}Generating event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            
            # Simulate a delay between events
            sleep $((RANDOM % 5 + 1))
        done
    fi
    
    echo -e "${GREEN}Clinical data breach simulation completed.${NC}"
}

# Simulate supply chain attack
function simulate_supply_chain_attack() {
    echo -e "${BLUE}Simulating supply chain attack scenario...${NC}"
    
    local intensity_factor=1
    case "$INTENSITY" in
        "Low")
            intensity_factor=1
            ;;
        "Medium")
            intensity_factor=3
            ;;
        "High")
            intensity_factor=5
            ;;
    esac
    
    local steps=(
        "Unusual authentication to supplier portal"
        "Modification of supplier record details"
        "Changes to shipping destinations"
        "Unusual order patterns in ERP system"
        "Cold chain monitoring system tampering"
        "Changes to logistics routing information"
        "Unusual API calls to inventory systems"
        "Modification of purchase order details"
        "Unexpected changes to shipping manifests"
        "Unusual access to manufacturing scheduling systems"
    )
    
    local system_targets=(
        "Supplier Portal"
        "Enterprise Resource Planning System"
        "Warehouse Management System"
        "Cold Chain Monitoring System"
        "Transportation Management System"
        "Manufacturing Execution System"
        "Inventory Management System"
        "Quality Management System"
        "Product Tracking System"
        "Logistics Planning System"
    )
    
    local target_system=""
    if [ -n "$TARGET" ]; then
        target_system="$TARGET"
    else
        target_system=${system_targets[$(( RANDOM % ${#system_targets[@]} ))]}
    fi
    
    echo -e "${YELLOW}Target System:${NC} $target_system"
    echo -e "${YELLOW}Intensity:${NC} $INTENSITY (factor: $intensity_factor)"
    echo -e "${YELLOW}Duration:${NC} $DURATION minutes"
    
    # Number of events to generate based on intensity
    local event_count=$((12 * intensity_factor))
    
    echo -e "${BLUE}Generating $event_count simulated events...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run mode - no events will be generated${NC}"
        echo -e "${YELLOW}Events that would be generated:${NC}"
        
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${BLUE}Event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            echo -e "  Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        done
    else
        # TODO: Replace this with actual event generation mechanism
        # For now, just simulate event generation
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${GREEN}Generating event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            
            # Simulate a delay between events
            sleep $((RANDOM % 5 + 1))
        done
    fi
    
    echo -e "${GREEN}Supply chain attack simulation completed.${NC}"
}

# Simulate insider threat
function simulate_insider_threat() {
    echo -e "${BLUE}Simulating insider threat scenario...${NC}"
    
    local intensity_factor=1
    case "$INTENSITY" in
        "Low")
            intensity_factor=1
            ;;
        "Medium")
            intensity_factor=3
            ;;
        "High")
            intensity_factor=5
            ;;
    esac
    
    local steps=(
        "Access to systems outside job role"
        "Escalation of privileges"
        "After-hours system access"
        "Access to terminated employee accounts"
        "Unusual data access patterns"
        "Bypassing normal approval workflows"
        "Changes to security configurations"
        "Mass copying of sensitive documents"
        "Unusual lateral movement between systems"
        "Creation of backdoor accounts"
    )
    
    local system_targets=(
        "Active Directory"
        "Human Resources System"
        "Financial System"
        "Document Management System"
        "Email System"
        "Virtual Private Network"
        "Research Database"
        "Clinical Trial Database"
        "Manufacturing System"
        "Quality Management System"
    )
    
    local target_system=""
    if [ -n "$TARGET" ]; then
        target_system="$TARGET"
    else
        target_system=${system_targets[$(( RANDOM % ${#system_targets[@]} ))]}
    fi
    
    echo -e "${YELLOW}Target System:${NC} $target_system"
    echo -e "${YELLOW}Intensity:${NC} $INTENSITY (factor: $intensity_factor)"
    echo -e "${YELLOW}Duration:${NC} $DURATION minutes"
    
    # Number of events to generate based on intensity
    local event_count=$((15 * intensity_factor))
    
    echo -e "${BLUE}Generating $event_count simulated events...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run mode - no events will be generated${NC}"
        echo -e "${YELLOW}Events that would be generated:${NC}"
        
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${BLUE}Event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            echo -e "  Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        done
    else
        # TODO: Replace this with actual event generation mechanism
        # For now, just simulate event generation
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${GREEN}Generating event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            
            # Simulate a delay between events
            sleep $((RANDOM % 5 + 1))
        done
    fi
    
    echo -e "${GREEN}Insider threat simulation completed.${NC}"
}

# Simulate ransomware attack
function simulate_ransomware() {
    echo -e "${BLUE}Simulating ransomware attack scenario...${NC}"
    
    local intensity_factor=1
    case "$INTENSITY" in
        "Low")
            intensity_factor=1
            ;;
        "Medium")
            intensity_factor=3
            ;;
        "High")
            intensity_factor=5
            ;;
    esac
    
    local steps=(
        "Unusual authentication patterns"
        "Changes to file permissions"
        "Mass file modifications"
        "Unusual process executions"
        "Unexpected network scanning"
        "Lateral movement between systems"
        "Unusual database operations"
        "Backup deletion attempts"
        "Domain controller access attempts"
        "Clearing of event logs"
    )
    
    local system_targets=(
        "File Servers"
        "Document Management System"
        "Research Database"
        "Clinical Data Repository"
        "ERP System"
        "Quality Management System"
        "Manufacturing Execution System"
        "Laboratory Information Management System"
        "Electronic Lab Notebook System"
        "Corporate Network"
    )
    
    local target_system=""
    if [ -n "$TARGET" ]; then
        target_system="$TARGET"
    else
        target_system=${system_targets[$(( RANDOM % ${#system_targets[@]} ))]}
    fi
    
    echo -e "${YELLOW}Target System:${NC} $target_system"
    echo -e "${YELLOW}Intensity:${NC} $INTENSITY (factor: $intensity_factor)"
    echo -e "${YELLOW}Duration:${NC} $DURATION minutes"
    
    # Number of events to generate based on intensity
    local event_count=$((20 * intensity_factor))
    
    echo -e "${BLUE}Generating $event_count simulated events...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run mode - no events will be generated${NC}"
        echo -e "${YELLOW}Events that would be generated:${NC}"
        
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${BLUE}Event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            echo -e "  Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        done
    else
        # TODO: Replace this with actual event generation mechanism
        # For now, just simulate event generation
        for ((i=1; i<=event_count; i++)); do
            local step=${steps[$(( RANDOM % ${#steps[@]} ))]}
            local username=$(random_username)
            local src_ip=$(random_ip)
            local resource=$(random_resource)
            
            echo -e "${GREEN}Generating event $i:${NC} $step"
            echo -e "  User: $username"
            echo -e "  Source IP: $src_ip"
            echo -e "  Resource: $resource"
            echo -e "  System: $target_system"
            
            # Simulate a delay between events
            sleep $((RANDOM % 5 + 1))
        done
    fi
    
    echo -e "${GREEN}Ransomware attack simulation completed.${NC}"
}

# Main function
function main() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Bio-Pharma Attack Simulation Tool${NC}"
    echo -e "${BLUE}Version:${NC} $VERSION ($DATE)"
    echo -e "${BLUE}=================================================${NC}"
    
    parse_args "$@"
    check_dependencies
    check_sentinel_workspace
    generate_random_data
    
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${BLUE}Simulation Configuration:${NC}"
    echo -e "${BLUE}Resource Group:${NC} $RESOURCE_GROUP"
    echo -e "${BLUE}Prefix:${NC} $PREFIX"
    echo -e "${BLUE}Scenario:${NC} $SCENARIO"
    echo -e "${BLUE}Intensity:${NC} $INTENSITY"
    echo -e "${BLUE}Duration:${NC} $DURATION minutes"
    if [ -n "$TARGET" ]; then
        echo -e "${BLUE}Target:${NC} $TARGET"
    fi
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Mode:${NC} DRY RUN (no events will be generated)"
    fi
    echo -e "${BLUE}------------------------------------------------${NC}"
    
    # Confirm simulation unless in dry run mode
    if [ "$DRY_RUN" != true ]; then
        read -p "Ready to begin attack simulation. This will generate security events in your environment. Continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Simulation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Run the appropriate simulation based on scenario
    case "$SCENARIO" in
        "IP_Theft")
            simulate_ip_theft
            ;;
        "Clinical_Data_Breach")
            simulate_clinical_data_breach
            ;;
        "Supply_Chain_Attack")
            simulate_supply_chain_attack
            ;;
        "Insider_Threat")
            simulate_insider_threat
            ;;
        "Ransomware")
            simulate_ransomware
            ;;
    esac
    
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Simulation completed successfully!${NC}"
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Check Sentinel for generated alerts"
    echo -e "2. Verify detection and response capabilities"
    echo -e "3. Review any gaps in detection coverage"
    echo -e "${BLUE}=================================================${NC}"
    
    exit 0
}

# Execute main function with all arguments
main "$@"
