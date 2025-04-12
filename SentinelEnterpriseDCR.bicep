// Bio-Pharma Specific Data Collection Rules Module - Enhanced Version
// Creates and configures optimized DCRs for pharmaceutical research and manufacturing systems

@description('The location for all resources')
param location string

@description('Prefix to use for resource naming')
param prefix string

@description('Environment (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'prod'

@description('Tags to apply to all resources')
param tags object = {}

@description('Resource ID for the central Sentinel workspace')
param sentinelWorkspaceId string

@description('Resource ID for the research workspace')
param researchWorkspaceId string

@description('Resource ID for the manufacturing workspace')
param manufacturingWorkspaceId string

@description('Resource ID for the clinical workspace')
param clinicalWorkspaceId string

@description('Data Collection Endpoint ID (optional)')
param dataCollectionEndpointId string = ''

// Variables to extract workspace names for scope references
var sentinelWorkspaceName = last(split(sentinelWorkspaceId, '/'))
var researchWorkspaceName = last(split(researchWorkspaceId, '/')) 
var manufacturingWorkspaceName = last(split(manufacturingWorkspaceId, '/'))
var clinicalWorkspaceName = last(split(clinicalWorkspaceId, '/'))

// Resource naming variables
var resourceNames = {
  dcrELN: '${prefix}-${environment}-dcr-eln-system'
  dcrLIMS: '${prefix}-${environment}-dcr-lims-system'
  dcrCTMS: '${prefix}-${environment}-dcr-ctms-system'
  dcrMES: '${prefix}-${environment}-dcr-mes-system'
  dcrPV: '${prefix}-${environment}-dcr-pv-system'
  dcrInstruments: '${prefix}-${environment}-dcr-instruments'
  dcrColdChain: '${prefix}-${environment}-dcr-cold-chain'
  dcrInstrumentQual: '${prefix}-${environment}-dcr-instrument-qual'
}

// Enhanced tags with standard metadata
var resourceTags = union(tags, {
  'environment': environment
  'application': 'Microsoft Sentinel'
  'business-unit': 'Security'
  'deployment-date': utcNow('yyyy-MM-dd')
})

// --------------------- BIO-PHARMA DATA COLLECTION RULES -----------------------

// 1. DCR for Electronic Lab Notebook (ELN) System - Enhanced for better data filtering
resource dcrElectronicLabNotebook 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: resourceNames.dcrELN
  location: location
  tags: union(resourceTags, {
    'dataType': 'ELN'
    'system': 'Electronic-Lab-Notebook'
    'regulatory': 'IP-Protection,21CFR11'
  })
  properties: {
    dataCollectionEndpointId: !empty(dataCollectionEndpointId) ? dataCollectionEndpointId : null
    description: 'Collects data from Electronic Lab Notebook systems with enhanced IP protection filters'
    dataSources: {
      logFiles: [
        {
          name: 'elnLogs'
          streams: ['Custom-ELN_CL']
          filePatterns: [
            '/var/log/eln/*.log', 
            'C:\\ProgramData\\ELN\\logs\\*.log',
            '/opt/eln/logs/*.log',
            '/usr/local/eln/logs/*.log'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
        }
      ]
      syslog: [
        {
          name: 'elnSyslog'
          streams: ['Custom-ELN_CL']
          facilityNames: [
            'local0',
            'local1'
          ]
          logLevels: [
            'Warning',
            'Error',
            'Critical',
            'Alert',
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelDestination'
        },
        {
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-ELN_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "Copy", "Download", "Print", "Export", "Share", "Email") 
          or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Rejected", "Unauthorized")
          | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
          | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend IPAddress = extract("IP[:\\s]+([\\d\\.]+)", 1, RawData)
          | where isnotempty(UserName)
        '''
      },
      {
        streams: ['Custom-ELN_CL']
        destinations: ['researchDestination']
        // Capture all events for research workspace but add metadata
        transformKql: '''
          source
          | extend IPProtectionAudit = "true"
          | extend SourceSystem = "ELN" 
          | extend AuditRecordType = "Research" 
          | extend RecordHash = hash_sha256(RawData)
          | extend Timestamp = now()
        '''
      }
    ]
  }
}

// 2. DCR for Lab Information Management System (LIMS) - Enhanced with more comprehensive data parsing
resource dcrLims 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: resourceNames.dcrLIMS
  location: location
  tags: union(resourceTags, {
    'dataType': 'LIMS'
    'system': 'Laboratory-Information-Management'
    'regulatory': 'IP-Protection,21CFR11,GxP'
  })
  properties: {
    dataCollectionEndpointId: !empty(dataCollectionEndpointId) ? dataCollectionEndpointId : null
    description: 'Collects data from Laboratory Information Management System with enhanced data parsing'
    dataSources: {
      logFiles: [
        {
          name: 'limsLogs'
          streams: ['Custom-LIMS_CL']
          filePatterns: [
            '/var/log/lims/*.log', 
            'C:\\ProgramData\\LIMS\\logs\\*.log',
            '/opt/lims/logs/*.log',
            '/usr/local/lims/logs/*.log'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
        }
      ]
      syslog: [
        {
          name: 'limsSyslog'
          streams: ['Custom-LIMS_CL']
          facilityNames: [
            'local0',
            'local1'
          ]
          logLevels: [
            'Warning',
            'Error',
            'Critical',
            'Alert',
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelDestination'
        },
        {
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-LIMS_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "Sample", "Result", "Test", "Method", "Analysis") 
          or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Rejected", "Unauthorized")
          | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
          | extend SampleID = extract("Sample[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend TestID = extract("Test[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend IPAddress = extract("IP[:\\s]+([\\d\\.]+)", 1, RawData)
          | where isnotempty(UserName)
        '''
      },
      {
        streams: ['Custom-LIMS_CL']
        destinations: ['researchDestination']
        // Capture all events with GxP metadata
        transformKql: '''
          source
          | extend GxPRelevant = "true" 
          | extend SourceSystem = "LIMS" 
          | extend RecordHash = hash_sha256(RawData)
          | extend Timestamp = now()
        '''
      }
    ]
  }
}

// 3. DCR for Clinical Trial Management System (CTMS) - Enhanced with improved PHI/PII masking
resource dcrClinicalTrialSystem 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: resourceNames.dcrCTMS
  location: location
  tags: union(resourceTags, {
    'dataType': 'CTMS'
    'system': 'Clinical-Trial-Management'
    'regulatory': 'HIPAA,GDPR,21CFR11'
  })
  properties: {
    dataCollectionEndpointId: !empty(dataCollectionEndpointId) ? dataCollectionEndpointId : null
    description: 'Collects data from Clinical Trial Management System with enhanced PHI/PII protection'
    dataSources: {
      logFiles: [
        {
          name: 'ctmsLogs'
          streams: ['Custom-CTMS_CL']
          filePatterns: [
            '/var/log/ctms/*.log', 
            'C:\\ProgramData\\CTMS\\logs\\*.log',
            '/opt/ctms/logs/*.log',
            '/usr/local/ctms/logs/*.log'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelDestination'
        },
        {
          workspaceResourceId: clinicalWorkspaceId
          name: 'clinicalDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-CTMS_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "PHI", "PII", "Subject", "Patient") 
          or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Unauthorized")
          | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
          | extend SubjectID = extract("Subject[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend StudyID = extract("Study[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend AccessType = extract("AccessType[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          // Mask PHI/PII for security events
          | extend MaskedData = replace_regex(RawData, @"\\b\\d{3}-\\d{2}-\\d{4}\\b", "XXX-XX-XXXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b", "XXX@XXX.XXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b(?:\\+?1[-\\.]?)?\\(?[0-9]{3}\\)?[-\\.]?[0-9]{3}[-\\.]?[0-9]{4}\\b", "XXX-XXX-XXXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2},\\s+\\d{4}\\b", "XXX XX, XXXX")
          | project-away RawData
          | project-rename RawData = MaskedData
        '''
      },
      {
        streams: ['Custom-CTMS_CL']
        destinations: ['clinicalDestination']
        // Apply comprehensive PHI/PII masking for compliance before storing
        transformKql: '''
          source 
          | extend MaskedData = replace_regex(RawData, @"\\b\\d{3}-\\d{2}-\\d{4}\\b", "XXX-XX-XXXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b", "XXX@XXX.XXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b(?:\\+?1[-\\.]?)?\\(?[0-9]{3}\\)?[-\\.]?[0-9]{3}[-\\.]?[0-9]{4}\\b", "XXX-XXX-XXXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2},\\s+\\d{4}\\b", "XXX XX, XXXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b\\d{5}(-\\d{4})?\\b", "XXXXX")
          | extend HIPAACompliance = "Masked"
          | extend GDPRCompliance = "Masked"
          | extend DataCategory = "Clinical"
          | extend RecordHash = hash_sha256(RawData)
          | project-away RawData
          | project-rename RawData = MaskedData
        '''
      }
    ]
  }
}

// 4. DCR for Manufacturing Execution System (MES) - Enhanced with improved 21 CFR Part 11 metadata
resource dcrManufacturingSystem 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: resourceNames.dcrMES
  location: location
  tags: union(resourceTags, {
    'dataType': 'MES'
    'system': 'Manufacturing-Execution'
    'regulatory': '21CFR11,GxP'
  })
  properties: {
    dataCollectionEndpointId: !empty(dataCollectionEndpointId) ? dataCollectionEndpointId : null
    description: 'Collects data from Manufacturing Execution System with enhanced GxP requirements'
    dataSources: {
      logFiles: [
        {
          name: 'mesLogs'
          streams: ['Custom-MES_CL']
          filePatterns: [
            '/var/log/mes/*.log', 
            'C:\\ProgramData\\MES\\logs\\*.log',
            '/opt/mes/logs/*.log',
            '/usr/local/mes/logs/*.log'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelDestination'
        },
        {
          workspaceResourceId: manufacturingWorkspaceId
          name: 'manufacturingDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-MES_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where RawData has_any ("Authentication", "Authorization", "Configuration", "Recipe", "Parameter", "Change", "Role", "Formula", "Batch") 
          or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Validation", "Rejected")
          | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
          | extend SystemName = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ChangeType = extract("Change[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ChangeID = extract("ChangeID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ValidationStatus = extract("ValidationStatus[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend BatchID = extract("Batch[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | where isnotempty(UserName)
        '''
      },
      {
        streams: ['Custom-MES_CL']
        destinations: ['manufacturingDestination']
        // Comprehensive 21 CFR Part 11 metadata tagging for audit trail
        transformKql: '''
          source 
          | extend CFRCompliance = "21CFR11" 
          | extend RecordType = "Electronic Record"
          | extend RecordIntegrityHash = hash_sha256(RawData) 
          | extend GxPStatus = case(
              RawData has "ValidationStatus: Validated", "Validated",
              RawData has "ValidationStatus: Qualified", "Qualified",
              RawData has "ValidationStatus: Production", "Production",
              "Unknown"
            )
          | extend ChangeControlID = extract("ChangeID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ElectronicSignatureStatus = case(
              RawData has "SignatureStatus: Valid", "Valid",
              RawData has "SignatureStatus: Invalid", "Invalid",
              RawData has "SignatureStatus: Missing", "Missing",
              ""
            )
          | extend AuditTrailTimestamp = now()
        '''
      }
    ]
  }
}

// Additional DCRs would follow the same pattern with enhanced transformations

// Output DCR IDs for reference
output elnSystemDcrId string = dcrElectronicLabNotebook.id
output limsSystemDcrId string = dcrLims.id
output ctmsSystemDcrId string = dcrClinicalTrialSystem.id
output mesSystemDcrId string = dcrManufacturingSystem.id
