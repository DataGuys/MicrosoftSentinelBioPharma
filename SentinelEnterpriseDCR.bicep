// Bio-Pharma Specific Data Collection Rules Module - Enhanced with Data Tiering
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

// 1. DCR for Electronic Lab Notebook (ELN) System - Dual-tier approach
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
    description: 'Collects data from Electronic Lab Notebook systems with enhanced IP protection filters and data tiering'
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
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelAuxDestination'
          dataTypeTier: 'Basic'  // Auxiliary tier destination
        },
        {
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        // Critical security logs to Analytics tier
        streams: ['Custom-ELN_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "Copy", "Download", "Print", "Export", "Share", "Email", "Delete") 
          or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Rejected", "Unauthorized")
          | where not(RawData has_any ("INFO", "Debug", "Verbose", "Trace"))
          | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
          | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend IPAddress = extract("IP[:\\s]+([\\d\\.]+)", 1, RawData)
          | where isnotempty(UserName)
        '''
      },
      {
        // Verbose logs to Auxiliary tier
        streams: ['Custom-ELN_CL']
        destinations: ['sentinelAuxDestination']
        transformKql: '''
          source
          | where RawData has_any ("INFO", "Debug", "Verbose", "Trace")
          | where not(RawData has_any ("Error", "Failed", "Critical", "Warning"))
          | extend LogType = "Verbose"
          | extend Source = "ELN"
        '''
      },
      {
        // All logs for research workspace (for IP protection)
        streams: ['Custom-ELN_CL']
        destinations: ['researchDestination']
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

// 2. DCR for Lab Information Management System (LIMS) - Data tiering implementation
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
    description: 'Collects data from Laboratory Information Management System with tiered data ingestion'
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
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelAuxDestination'
          dataTypeTier: 'Basic'  // Auxiliary tier destination
        },
        {
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        // Critical security logs to Analytics tier
        streams: ['Custom-LIMS_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "Sample", "Result", "Test", "Method", "Analysis") 
          and (RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Rejected", "Unauthorized"))
          | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
          | extend SampleID = extract("Sample[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend TestID = extract("Test[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend IPAddress = extract("IP[:\\s]+([\\d\\.]+)", 1, RawData)
          | where isnotempty(UserName)
        '''
      },
      {
        // Verbose logs to Auxiliary tier (high-volume instrument data)
        streams: ['Custom-LIMS_CL']
        destinations: ['sentinelAuxDestination']
        transformKql: '''
          source
          | where RawData has_any ("INFO", "Debug", "Verbose", "Trace", "Sample", "Result", "Analysis", "Instrument", "Reading")
          | where not(RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied"))
          | extend LogType = "Verbose"
          | extend Source = "LIMS"
        '''
      },
      {
        // All logs for research workspace (for GxP requirements)
        streams: ['Custom-LIMS_CL']
        destinations: ['researchDestination']
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

// 3. DCR for Manufacturing Execution System (MES) - Data tiering implementation
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
    description: 'Collects data from Manufacturing Execution System with data tiering for cost optimization'
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
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelAuxDestination'
          dataTypeTier: 'Basic'  // Auxiliary tier destination
        },
        {
          workspaceResourceId: manufacturingWorkspaceId
          name: 'manufacturingDestination'
        }
      ]
    }
    dataFlows: [
      {
        // Critical security and GxP logs to Analytics tier
        streams: ['Custom-MES_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where (RawData has_any ("Authentication", "Authorization", "Configuration", "Recipe", "Parameter", "Change", "Role", "Formula", "Batch")) 
          and (RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Validation", "Rejected"))
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
        // High-volume manufacturing production logs to Auxiliary tier
        streams: ['Custom-MES_CL']
        destinations: ['sentinelAuxDestination']
        transformKql: '''
          source
          | where RawData has_any ("Production", "Status", "Reading", "Sensor", "Measurement", "Info", "Debug", "Trace")
          | where not(RawData has_any ("Failed", "Error", "Warning", "Critical", "Validation", "Change", "Unauthorized"))
          | extend LogType = "Verbose"
          | extend Source = "MES"
          | extend DataTier = "Auxiliary"
        '''
      },
      {
        // All logs for manufacturing workspace (for regulatory compliance)
        streams: ['Custom-MES_CL']
        destinations: ['manufacturingDestination']
        transformKql: '''
          source 
          | extend CFRCompliance = "21CFR11" 
          | extend RecordIntegrityHash = hash_sha256(RawData) 
          | extend RecordType = "Electronic Record"
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

// 4. DCR for Clinical Trial Management System (CTMS) - Data tiering implementation
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
    description: 'Collects data from Clinical Trial Management System with tiered data collection'
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
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelAuxDestination'
          dataTypeTier: 'Basic'  // Auxiliary tier destination
        },
        {
          workspaceResourceId: clinicalWorkspaceId
          name: 'clinicalDestination'
        }
      ]
    }
    dataFlows: [
      {
        // Security and PHI access logs to Analytics tier
        streams: ['Custom-CTMS_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where (RawData has_any ("Authentication", "Authorization", "Permission", "Access", "PHI", "PII", "Subject", "Patient")) 
          and (RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Unauthorized"))
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
        // High-volume clinical logs to Auxiliary tier
        streams: ['Custom-CTMS_CL']
        destinations: ['sentinelAuxDestination']
        transformKql: '''
          source
          | where RawData has_any ("INFO", "Debug", "Verbose", "Trace", "Status", "Report")
          | where not(RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied"))
          | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
          | extend StudyID = extract("Study[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend LogType = "Verbose"
          | extend Source = "CTMS"
          | extend DataTier = "Auxiliary"
          // Apply PHI masking on verbose logs too
          | extend MaskedData = replace_regex(RawData, @"\\b\\d{3}-\\d{2}-\\d{4}\\b", "XXX-XX-XXXX")
          | extend MaskedData = replace_regex(MaskedData, @"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b", "XXX@XXX.XXX")
          | project-away RawData
          | project-rename RawData = MaskedData
        '''
      },
      {
        // All logs for clinical workspace
        streams: ['Custom-CTMS_CL']
        destinations: ['clinicalDestination']
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

// 5. DCR for Laboratory Instrument Logs - High volume to Auxiliary tier
resource dcrInstruments 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: resourceNames.dcrInstruments
  location: location
  tags: union(resourceTags, {
    'dataType': 'Instruments'
    'system': 'Laboratory-Instruments'
    'regulatory': 'GxP'
    'tier': 'Auxiliary'  // Default to Auxiliary for high-volume instrument data
  })
  properties: {
    dataCollectionEndpointId: !empty(dataCollectionEndpointId) ? dataCollectionEndpointId : null
    description: 'Collects high-volume instrument data using Auxiliary tier for cost optimization'
    dataSources: {
      logFiles: [
        {
          name: 'instrumentLogs'
          streams: ['Custom-Instruments_CL']
          filePatterns: [
            '/var/log/instruments/*.log', 
            'C:\\ProgramData\\Instruments\\logs\\*.log',
            '/opt/instruments/logs/*.log',
            '/usr/local/instruments/logs/*.log'
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
          workspaceResourceId: sentinelWorkspaceId
          name: 'sentinelAuxDestination'
          dataTypeTier: 'Basic'  // Auxiliary tier destination
        },
        {
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        // Only critical security events to Analytics tier
        streams: ['Custom-Instruments_CL']
        destinations: ['sentinelDestination']
        transformKql: '''
          source 
          | where RawData has_any ("Error", "Failed", "Critical", "Security", "Unauthorized", "Alert")
          | where not(RawData has_any ("INFO", "Debug", "Trace"))
          | extend InstrumentID = extract("Instrument[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ReadingType = extract("Reading[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend OperatorID = extract("Operator[:\\s]+([\\w\\-\\.]+)", 1, RawData)
        '''
      },
      {
        // Most instrument data to Auxiliary tier (high-volume)
        streams: ['Custom-Instruments_CL']
        destinations: ['sentinelAuxDestination']
        transformKql: '''
          source
          | where RawData has_any ("Reading", "Measurement", "Result", "Value", "Info", "Status", "Calibration", "Sample")
          | where not(RawData has_any ("Error", "Failed", "Critical", "Alert"))
          | extend InstrumentID = extract("Instrument[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ReadingType = extract("Reading[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend ReadingValue = extract("Value[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend SampleID = extract("Sample[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend LogType = "Instrument"
          | extend DataTier = "Auxiliary"
        '''
      },
      {
        // All logs to research workspace for GxP compliance
        streams: ['Custom-Instruments_CL']
        destinations: ['researchDestination']
        transformKql: '''
          source
          | extend GxPRelevant = "true" 
          | extend SourceSystem = "Instrument" 
          | extend RecordHash = hash_sha256(RawData)
          | extend InstrumentID = extract("Instrument[:\\s]+([\\w\\-\\.]+)", 1, RawData)
          | extend Timestamp = now()
        '''
      }
    ]
  }
}

// Output DCR IDs for reference
output elnSystemDcrId string = dcrElectronicLabNotebook.id
output limsSystemDcrId string = dcrLims.id
output ctmsSystemDcrId string = dcrClinicalTrialSystem.id
output mesSystemDcrId string = dcrManufacturingSystem.id
output instrumentsDcrId string = dcrInstruments.id
