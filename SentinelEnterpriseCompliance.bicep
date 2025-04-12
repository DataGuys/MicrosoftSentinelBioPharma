// Bio-Pharma Regulatory Compliance Module
// Implements compliance-specific resources for FDA, EMA, and global regulations

@description('The location for all resources')
param location string

@description('Prefix to use for resource naming')
param prefix string

@description('Tags to apply to all resources')
param tags object

@description('Name of the central Sentinel workspace')
param sentinelWorkspaceName string

@description('Name of the research workspace')
param researchWorkspaceName string = '${prefix}-research-ws'

@description('Name of the manufacturing workspace')
param manufacturingWorkspaceName string = '${prefix}-manufacturing-ws'

@description('Name of the clinical workspace')
param clinicalWorkspaceName string = '${prefix}-clinical-ws'

// --------------------- BIO-PHARMA REGULATORY COMPLIANCE RESOURCES -----------------------

// Storage account for 21 CFR Part 11 electronic records long-term storage
resource part11StorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${prefix}part11sa'
  location: location
  tags: union(tags, {
    'regulatoryPurpose': '21CFR-Part-11'
    'retentionRequirement': '7-years'
    'dataClassification': 'Electronic-Records'
  })
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS' // Geo-redundant storage for regulatory compliance
  }
  properties: {
    accessTier: 'Cool'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Electronic records container with immutable storage for CFR compliance
resource part11Container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: '${part11StorageAccount.name}/default/electronicrecords'
  properties: {
    immutableStorageWithVersioning: {
      enabled: true
      immutabilityPolicy: {
        immutabilityPeriodSinceCreationInDays: 2557 // 7 years retention
        allowProtectedAppendWrites: true // For audit trail continuity
      }
    }
  }
}

// Storage account for GDPR/HIPAA anonymized data
resource clinicalDataStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${prefix}clinicalsa'
  location: location
  tags: union(tags, {
    'regulatoryPurpose': 'GDPR-HIPAA'
    'retentionRequirement': '7-years'
    'dataClassification': 'PHI-PII-Masked'
  })
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS' // Geo-redundant storage for regulatory compliance
  }
  properties: {
    accessTier: 'Cool'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Clinical data container with immutable storage
resource clinicalContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: '${clinicalDataStorageAccount.name}/default/clinicaldata'
  properties: {
    immutableStorageWithVersioning: {
      enabled: true
      immutabilityPolicy: {
        immutabilityPeriodSinceCreationInDays: 2557 // 7 years retention
        allowProtectedAppendWrites: true // For audit trail continuity
      }
    }
  }
}

// Data Export for 21 CFR Part 11 compliant storage of electronic records
resource manufacturingDataExport 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  name: '${manufacturingWorkspaceName}/part11-data-export'
  properties: {
    destination: {
      resourceId: part11StorageAccount.id
      metaData: {
        container: part11Container.name
      }
    }
    tableNames: [
      'Custom-MES_CL',
      'Custom-InstrumentQual_CL'
    ]
    enabled: true
  }
}

// Data Export for GDPR/HIPAA compliant storage of clinical data
resource clinicalDataExport 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  name: '${clinicalWorkspaceName}/hipaa-gdpr-data-export'
  properties: {
    destination: {
      resourceId: clinicalDataStorageAccount.id
      metaData: {
        container: clinicalContainer.name
      }
    }
    tableNames: [
      'Custom-CTMS_CL',
      'Custom-PV_CL'
    ]
    enabled: true
  }
}

// Storage account for research IP audit trails
resource ipAuditStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${prefix}ipauditsa'
  location: location
  tags: union(tags, {
    'regulatoryPurpose': 'IP-Protection'
    'retentionRequirement': '7-years'
    'dataClassification': 'Intellectual-Property-Audit'
  })
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS' // Geo-redundant storage for regulatory compliance
  }
  properties: {
    accessTier: 'Cool'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// IP audit container with immutable storage
resource ipAuditContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: '${ipAuditStorageAccount.name}/default/ipaudit'
  properties: {
    immutableStorageWithVersioning: {
      enabled: true
      immutabilityPolicy: {
        immutabilityPeriodSinceCreationInDays: 2557 // 7 years retention
        allowProtectedAppendWrites: true // For audit trail continuity
      }
    }
  }
}

// Data Export for research IP audit data
resource ipAuditDataExport 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  name: '${researchWorkspaceName}/ip-audit-export'
  properties: {
    destination: {
      resourceId: ipAuditStorageAccount.id
      metaData: {
        container: ipAuditContainer.name
      }
    }
    tableNames: [
      'Custom-ELN_CL',
      'Custom-LIMS_CL',
      'Custom-Instruments_CL'
    ]
    enabled: true
  }
}

// Add 21 CFR Part 11 compliance lock to prevent accidental deletion
resource part11DeleteLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${prefix}-part11-delete-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'This lock prevents deletion of resources required for 21 CFR Part 11 compliance'
  }
  scope: part11StorageAccount
}

// Add GDPR/HIPAA compliance lock to prevent accidental deletion
resource hipaaGdprDeleteLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${prefix}-hipaa-gdpr-delete-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'This lock prevents deletion of resources required for HIPAA/GDPR compliance'
  }
  scope: clinicalDataStorageAccount
}

// Add IP protection lock to prevent accidental deletion
resource ipProtectionDeleteLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${prefix}-ip-protection-delete-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'This lock prevents deletion of resources required for intellectual property protection'
  }
  scope: ipAuditStorageAccount
}

// --------------------- REGULATORY MONITORING FRAMEWORK -----------------------

// Cross-workspace 21 CFR Part 11 compliance monitoring workbook
resource part11ComplianceWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${prefix}-part11-workbook')
  location: location
  kind: 'shared'
  properties: {
    displayName: '21 CFR Part 11 Compliance Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# 21 CFR Part 11 Compliance Monitoring\n---\n\nThis workbook monitors electronic records and signatures across bio-pharmaceutical systems to ensure 21 CFR Part 11 compliance."
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
              "durationMs": 2592000000
            },
            "typeSettings": {
              "selectableValues": [
                {
                  "durationMs": 3600000
                },
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
          },
          {
            "id": "c4790499-2a0b-4ba4-a53f-d46c5b33684f",
            "version": "KqlParameterItem/1.0",
            "name": "Systems",
            "type": 2,
            "multiSelect": true,
            "quote": "'",
            "delimiter": ",",
            "typeSettings": {
              "additionalResourceOptions": [
                "value::all"
              ],
              "showDefault": false
            },
            "jsonData": "[{\"value\":\"MES\",\"label\":\"Manufacturing Execution System\"},{\"value\":\"LIMS\",\"label\":\"Laboratory Information Management System\"},{\"value\":\"ELN\",\"label\":\"Electronic Lab Notebook\"},{\"value\":\"CTMS\",\"label\":\"Clinical Trial Management System\"}]",
            "defaultValue": "value::all",
            "label": "Systems"
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
        "query": "// Electronic Signature Validation Status\nCustom-MES_CL\n| where RawData has \"SignatureStatus\" and RawData has_any ({Systems})\n| extend SignatureStatus = extract(\"SignatureStatus[:\\\\s]+([\\\\w\\\\-\\\\.]+)\", 1, RawData)\n| extend UserName = extract(\"User[:\\\\s]+([\\\\w\\\\-\\\\.@]+)\", 1, RawData)\n| extend RecordID = extract(\"RecordID[:\\\\s]+([\\\\w\\\\-\\\\.]+)\", 1, RawData)\n| summarize Count=count() by SignatureStatus, bin(TimeGenerated, 1d)\n| render timechart",
        "size": 0,
        "title": "Electronic Signature Status Trend",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ]
      },
      "name": "signature-status-chart"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: ''
    category: 'sentinel'
    tags: [
      {
        'key': 'compliance'
        'value': '21CFR11'
      }
      {
        'key': 'industry'
        'value': 'bio-pharma'
      }
    ]
  }
}

// GDPR/HIPAA compliance monitoring workbook
resource gdprHipaaComplianceWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${prefix}-gdpr-hipaa-workbook')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'GDPR/HIPAA Compliance Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# GDPR/HIPAA Compliance Monitoring\n---\n\nThis workbook monitors patient data protection controls for GDPR and HIPAA compliance."
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
              "durationMs": 2592000000
            },
            "typeSettings": {
              "selectableValues": [
                {
                  "durationMs": 3600000
                },
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
        "query": "// PHI/PII Access Monitoring\nCustom-CTMS_CL\n| where RawData has_any (\"PHI\", \"PII\", \"Patient\", \"Subject\") and RawData has \"Access\"\n| extend UserName = extract(\"User[:\\\\s]+([\\\\w\\\\-\\\\.@]+)\", 1, RawData)\n| extend AccessType = extract(\"AccessType[:\\\\s]+([\\\\w\\\\-\\\\.]+)\", 1, RawData)\n| extend AuthStatus = extract(\"Status[:\\\\s]+([\\\\w\\\\-\\\\.]+)\", 1, RawData)\n| summarize Count=count() by AccessType, bin(TimeGenerated, 1d)\n| render timechart",
        "size": 0,
        "title": "PHI/PII Access by Type",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ]
      },
      "name": "phi-access-chart"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: ''
    category: 'sentinel'
    tags: [
      {
        'key': 'compliance'
        'value': 'GDPR-HIPAA'
      }
      {
        'key': 'industry'
        'value': 'bio-pharma'
      }
    ]
  }
}

// IP protection monitoring workbook
resource ipProtectionWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${prefix}-ip-protection-workbook')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Intellectual Property Protection Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Intellectual Property Protection Monitoring\n---\n\nThis workbook tracks access to and protection of intellectual property in research systems."
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
              "durationMs": 2592000000
            },
            "typeSettings": {
              "selectableValues": [
                {
                  "durationMs": 3600000
                },
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
        "query": "// IP Access Monitoring\nCustom-ELN_CL\n| where RawData has_any (\"Download\", \"Export\", \"Print\") \n| extend UserName = extract(\"User[:\\\\s]+([\\\\w\\\\-\\\\.@]+)\", 1, RawData)\n| extend DataClassification = extract(\"Classification[:\\\\s]+([\\\\w\\\\-\\\\.]+)\", 1, RawData)\n| extend Operation = extract(\"Operation[:\\\\s]+([\\\\w\\\\-\\\\.]+)\", 1, RawData)\n| where DataClassification has_any (\"IP\", \"Research\", \"Formula\", \"Confidential\", \"Restricted\")\n| summarize Count=count() by DataClassification, bin(TimeGenerated, 1d)\n| render timechart",
        "size": 0,
        "title": "IP Access by Classification",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ]
      },
      "name": "ip-access-chart"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: ''
    category: 'sentinel'
    tags: [
      {
        'key': 'compliance'
        'value': 'IP-Protection'
      }
      {
        'key': 'industry'
        'value': 'bio-pharma'
      }
    ]
  }
}

// Output compliance resource IDs for reference
output part11StorageAccountId string = part11StorageAccount.id
output clinicalDataStorageAccountId string = clinicalDataStorageAccount.id
output ipAuditStorageAccountId string = ipAuditStorageAccount.id
output part11ComplianceWorkbookId string = part11ComplianceWorkbook.id
output gdprHipaaComplianceWorkbookId string = gdprHipaaComplianceWorkbook.id
output ipProtectionWorkbookId string = ipProtectionWorkbook.id
