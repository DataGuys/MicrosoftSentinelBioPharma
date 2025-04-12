// Bio-Pharma Specific Data Collection Rules Module
// Creates and configures DCRs for pharmaceutical research and manufacturing systems

@description('The location for all resources')
param location string

@description('Prefix to use for resource naming')
param prefix string

@description('Tags to apply to all resources')
param tags object

@description('Resource ID for the central Sentinel workspace')
param sentinelWorkspaceId string

@description('Resource ID for the research workspace')
param researchWorkspaceId string

@description('Resource ID for the manufacturing workspace')
param manufacturingWorkspaceId string

@description('Resource ID for the clinical workspace')
param clinicalWorkspaceId string

// Variables to extract workspace names for scope references
var sentinelWorkspaceName = last(split(sentinelWorkspaceId, '/'))
var researchWorkspaceName = last(split(researchWorkspaceId, '/')) 
var manufacturingWorkspaceName = last(split(manufacturingWorkspaceId, '/'))
var clinicalWorkspaceName = last(split(clinicalWorkspaceId, '/'))

// --------------------- BIO-PHARMA DATA COLLECTION RULES -----------------------

// 1. DCR for Electronic Lab Notebook (ELN) System
resource dcrElectronicLabNotebook 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-eln-system'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from Electronic Lab Notebook systems'
    dataSources: {
      logFiles: [
        {
          name: 'elnLogs'
          streams: ['Custom-ELN_CL']
          filePatterns: ['/var/log/eln/*.log', 'C:\\ProgramData\\ELN\\logs\\*.log']
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
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-ELN_CL']
        destinations: ['sentinelDestination']
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "Copy", "Download", "Print") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      },
      {
        streams: ['Custom-ELN_CL']
        destinations: ['researchDestination']
        // No transform - send all ELN logs to research workspace
      }
    ]
  }
}

// 2. DCR for Lab Information Management System (LIMS)
resource dcrLims 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-lims-system'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from Laboratory Information Management System'
    dataSources: {
      logFiles: [
        {
          name: 'limsLogs'
          streams: ['Custom-LIMS_CL']
          filePatterns: ['/var/log/lims/*.log', 'C:\\ProgramData\\LIMS\\logs\\*.log']
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
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-LIMS_CL']
        destinations: ['sentinelDestination']
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "Sample", "Result", "Test") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      },
      {
        streams: ['Custom-LIMS_CL']
        destinations: ['researchDestination']
        // No transform - send all LIMS logs to research workspace
      }
    ]
  }
}

// 3. DCR for Clinical Trial Management System (CTMS)
resource dcrClinicalTrialSystem 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-ctms-system'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from Clinical Trial Management System'
    dataSources: {
      logFiles: [
        {
          name: 'ctmsLogs'
          streams: ['Custom-CTMS_CL']
          filePatterns: ['/var/log/ctms/*.log', 'C:\\ProgramData\\CTMS\\logs\\*.log']
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
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "PHI", "PII", "Subject", "Patient") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      },
      {
        streams: ['Custom-CTMS_CL']
        destinations: ['clinicalDestination']
        // Apply PHI/PII masking for compliance before storing
        transformKql: 'source | extend MaskedData = replace_regex(RawData, @"\\b\\d{3}-\\d{2}-\\d{4}\\b", "***-**-****") | extend MaskedData = replace_regex(MaskedData, @"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b", "****@*****") | project-away RawData | project-rename RawData = MaskedData'
      }
    ]
  }
}

// 4. DCR for Manufacturing Execution System (MES)
resource dcrManufacturingSystem 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-mes-system'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from Manufacturing Execution System with GxP requirements'
    dataSources: {
      logFiles: [
        {
          name: 'mesLogs'
          streams: ['Custom-MES_CL']
          filePatterns: ['/var/log/mes/*.log', 'C:\\ProgramData\\MES\\logs\\*.log']
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
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Configuration", "Recipe", "Parameter", "Change", "Role") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied", "Validation")'
      },
      {
        streams: ['Custom-MES_CL']
        destinations: ['manufacturingDestination']
        // Capture all events for GxP audit trail requirements
        // Apply 21 CFR Part 11 metadata tagging
        transformKql: 'source | extend CFRCompliance = "21CFR11" | extend RecordIntegrityHash = hash_sha256(RawData) | extend RecordType = "Electronic Record"'
      }
    ]
  }
}

// 5. DCR for Pharmacovigilance System
resource dcrPharmacovigilanceSystem 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-pv-system'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from Pharmacovigilance System'
    dataSources: {
      logFiles: [
        {
          name: 'pvLogs'
          streams: ['Custom-PV_CL']
          filePatterns: ['/var/log/pv/*.log', 'C:\\ProgramData\\PV\\logs\\*.log']
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
        streams: ['Custom-PV_CL']
        destinations: ['sentinelDestination']
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Permission", "Access", "Report", "Case") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      },
      {
        streams: ['Custom-PV_CL']
        destinations: ['clinicalDestination']
        // Apply PHI/PII masking for compliance before storing
        transformKql: 'source | extend MaskedData = replace_regex(RawData, @"\\b\\d{3}-\\d{2}-\\d{4}\\b", "***-**-****") | extend MaskedData = replace_regex(MaskedData, @"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b", "****@*****") | project-away RawData | project-rename RawData = MaskedData'
      }
    ]
  }
}

// 6. DCR for Research Instrument IoT Devices
resource dcrResearchInstruments 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-instruments'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from research instruments and IoT devices'
    dataSources: {
      logFiles: [
        {
          name: 'instrumentLogs'
          streams: ['Custom-Instruments_CL']
          filePatterns: ['/var/log/instruments/*.log', 'C:\\ProgramData\\Instruments\\logs\\*.log']
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
          workspaceResourceId: researchWorkspaceId
          name: 'researchDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-Instruments_CL']
        destinations: ['sentinelDestination']
        // Only security-relevant events to Sentinel
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Connection", "Remote", "Update", "Configuration") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      },
      {
        streams: ['Custom-Instruments_CL']
        destinations: ['researchDestination']
        // Filter out high-volume instrument measurement data
        transformKql: 'source | where not(RawData has_any("Measurement", "Reading", "Value", "Result", "Data")) or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      }
    ]
  }
}

// 7. DCR for Cold Chain Monitoring Systems
resource dcrColdChain 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-cold-chain'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from cold chain monitoring systems'
    dataSources: {
      logFiles: [
        {
          name: 'coldChainLogs'
          streams: ['Custom-ColdChain_CL']
          filePatterns: ['/var/log/coldchain/*.log', 'C:\\ProgramData\\ColdChain\\logs\\*.log']
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
        streams: ['Custom-ColdChain_CL']
        destinations: ['sentinelDestination']
        // Only security and critical temperature violation events
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Connection", "Remote", "Update", "Configuration", "Violation", "Excursion") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      },
      {
        streams: ['Custom-ColdChain_CL']
        destinations: ['manufacturingDestination']
        // Send all logs for regulatory compliance
        // Add GxP compliance metadata
        transformKql: 'source | extend GxPRelevant = "true" | extend DataCategory = "ColdChain" | extend RetentionRequired = "true"'
      }
    ]
  }
}

// 8. DCR for Instrument Qualification System
resource dcrInstrumentQualification 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr-instrument-qual'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: null // Use default endpoint
    description: 'Collects data from instrument qualification and validation system'
    dataSources: {
      logFiles: [
        {
          name: 'qualificationLogs'
          streams: ['Custom-InstrumentQual_CL']
          filePatterns: ['/var/log/qualification/*.log', 'C:\\ProgramData\\Qualification\\logs\\*.log']
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
        streams: ['Custom-InstrumentQual_CL']
        destinations: ['sentinelDestination']
        // Security and validation status changes
        transformKql: 'source | where RawData has_any ("Authentication", "Authorization", "Qualification", "Validation", "IQ", "OQ", "PQ", "Status Change") or RawData has_any ("Failed", "Error", "Warning", "Critical", "Denied")'
      },
      {
        streams: ['Custom-InstrumentQual_CL']
        destinations: ['manufacturingDestination']
        // All qualification data for GxP compliance
        transformKql: 'source | extend ValidationStatus = extract(@"Status: (\\w+)", 1, RawData) | extend QualificationType = extract(@"Type: (\\w+)", 1, RawData) | extend InstrumentID = extract(@"InstrumentID: (\\w+)", 1, RawData)'
      }
    ]
  }
}

// Output DCR IDs for reference
output elnSystemDcrId string = dcrElectronicLabNotebook.id
output limsSystemDcrId string = dcrLims.id
output ctmsSystemDcrId string = dcrClinicalTrialSystem.id
output mesSystemDcrId string = dcrManufacturingSystem.id
output pharmacovigilanceSystemDcrId string = dcrPharmacovigilanceSystem.id
output researchInstrumentsDcrId string = dcrResearchInstruments.id
output coldChainDcrId string = dcrColdChain.id
output instrumentQualificationDcrId string = dcrInstrumentQualification.id
