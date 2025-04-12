// Bio-Pharma Sentinel Enhancements Module
// Implements advanced features for pharmaceutical security monitoring

@description('The location for all resources')
param location string

@description('Prefix to use for resource naming')
param prefix string = 'bp'

@description('Environment (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'prod'

@description('Tags to apply to all resources')
param tags object = {}

@description('Name of the central Sentinel workspace')
param sentinelWorkspaceName string

// Variables for resource naming
var resourceNames = {
  complianceDashboard: '${prefix}-${environment}-compliance-dashboard'
  mlSolution: '${prefix}-${environment}-ml-anomaly-detection'
  supplyChainWorkbook: '${prefix}-${environment}-supply-chain-security'
  containerSecurityWorkbook: '${prefix}-${environment}-container-security'
  attackSimulation: '${prefix}-${environment}-attack-simulation'
  multiTenantConfig: '${prefix}-${environment}-multi-tenant-config'
  logicAppPrefix: '${prefix}-${environment}-logic-app'
}

// Enhanced tags with standard metadata
var resourceTags = union(tags, {
  'environment': environment
  'application': 'Microsoft Sentinel Enhanced'
  'business-unit': 'Security'
  'deployment-date': utcNow('yyyy-MM-dd')
})

// Reference to Sentinel workspace
resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: sentinelWorkspaceName
}

// --------------------- ENHANCEMENT 1: COMPREHENSIVE COMPLIANCE DASHBOARD -----------------------

// Comprehensive compliance dashboard workbook
resource complianceDashboard 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${resourceNames.complianceDashboard}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Bio-Pharma Comprehensive Compliance Dashboard'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Bio-Pharmaceutical Comprehensive Compliance Dashboard\n---\n\nThis dashboard provides real-time compliance status across multiple regulatory frameworks relevant to the bio-pharmaceutical industry."
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
            "name": "Regulations",
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
            "jsonData": "[{\"value\":\"21CFR11\",\"label\":\"21 CFR Part 11\"},{\"value\":\"GDPR\",\"label\":\"GDPR\"},{\"value\":\"HIPAA\",\"label\":\"HIPAA\"},{\"value\":\"GxP\",\"label\":\"GxP\"},{\"value\":\"EMA\",\"label\":\"EMA Annex 11\"},{\"value\":\"SOX\",\"label\":\"SOX\"}]",
            "defaultValue": "value::all",
            "label": "Regulations"
          },
          {
            "id": "e87a87d5-1e9d-4689-886b-5d736efb06a5",
            "version": "KqlParameterItem/1.0",
            "name": "Regions",
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
            "jsonData": "[{\"value\":\"us\",\"label\":\"United States\"},{\"value\":\"eu\",\"label\":\"European Union\"},{\"value\":\"apac\",\"label\":\"Asia Pacific\"},{\"value\":\"latam\",\"label\":\"Latin America\"}]",
            "defaultValue": "value::all",
            "label": "Regions"
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
        "query": "// Compliance Status Overview\nlet ElectronicRecordsStatus = 100; // Placeholder for real query\nlet ElectronicSignaturesStatus = 95; // Placeholder for real query\nlet AuditTrailStatus = 98; // Placeholder for real query\nlet ValidationDocStatus = 92; // Placeholder for real query\nlet AccessControlStatus = 97; // Placeholder for real query\nlet DataIntegrityStatus = 90; // Placeholder for real query\nlet PHIProtectionStatus = 94; // Placeholder for real query\n\nlet complianceAreas = datatable(Area:string, Status:int, Regulation:string)\n[\n    'Electronic Records', ElectronicRecordsStatus, '21CFR11',\n    'Electronic Signatures', ElectronicSignaturesStatus, '21CFR11',\n    'Audit Trails', AuditTrailStatus, '21CFR11',\n    'Validation Documentation', ValidationDocStatus, '21CFR11',\n    'Data Integrity', DataIntegrityStatus, 'GxP',\n    'PHI Protection', PHIProtectionStatus, 'HIPAA',\n    'Access Control', AccessControlStatus, 'SOX',\n];\n\ncomplianceAreas\n| where Regulation in ({Regulations}) or '*' in ({Regulations})\n| project ['Compliance Area'] = Area, ['Compliance Score (%)'] = Status, Regulation\n| sort by ['Compliance Score (%)'] asc",
        "size": 0,
        "title": "Compliance Status Overview",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "table",
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "Compliance Score (%)",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "<",
                    "thresholdValue": "80",
                    "representation": "redBright",
                    "text": "{0}%"
                  },
                  {
                    "operator": "<",
                    "thresholdValue": "90",
                    "representation": "yellow",
                    "text": "{0}%"
                  },
                  {
                    "operator": ">=",
                    "thresholdValue": "90",
                    "representation": "green",
                    "text": "{0}%"
                  }
                ]
              }
            }
          ]
        }
      },
      "name": "compliance-status-query"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// Compliance Trend\nlet now = datetime(2025-04-01T00:00:00Z); // For demo purposes\nlet months = range(1, 6, 1);\nlet compliance = datatable(Month:string, Score:double, Regulation:string)\n[\n    'Oct 2024', 88, '21CFR11',\n    'Nov 2024', 90, '21CFR11',\n    'Dec 2024', 93, '21CFR11',\n    'Jan 2025', 95, '21CFR11',\n    'Feb 2025', 97, '21CFR11',\n    'Mar 2025', 98, '21CFR11',\n    'Oct 2024', 85, 'GDPR',\n    'Nov 2024', 87, 'GDPR',\n    'Dec 2024', 90, 'GDPR',\n    'Jan 2025', 92, 'GDPR',\n    'Feb 2025', 94, 'GDPR',\n    'Mar 2025', 95, 'GDPR',\n    'Oct 2024', 80, 'HIPAA',\n    'Nov 2024', 83, 'HIPAA',\n    'Dec 2024', 87, 'HIPAA',\n    'Jan 2025', 90, 'HIPAA',\n    'Feb 2025', 93, 'HIPAA',\n    'Mar 2025', 94, 'HIPAA',\n    'Oct 2024', 79, 'GxP',\n    'Nov 2024', 82, 'GxP',\n    'Dec 2024', 86, 'GxP',\n    'Jan 2025', 89, 'GxP',\n    'Feb 2025', 92, 'GxP',\n    'Mar 2025', 93, 'GxP'\n];\n\ncompliance\n| where Regulation in ({Regulations}) or '*' in ({Regulations})\n| project Month, Regulation, Score",
        "size": 0,
        "title": "Compliance Score Trend (6 Months)",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "linechart",
        "chartSettings": {
          "seriesLabelSettings": [
            {
              "seriesName": "21CFR11",
              "label": "21 CFR Part 11"
            },
            {
              "seriesName": "GDPR",
              "label": "GDPR"
            },
            {
              "seriesName": "HIPAA",
              "label": "HIPAA"
            },
            {
              "seriesName": "GxP",
              "label": "GxP"
            }
          ]
        }
      },
      "name": "compliance-trend-query"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: sentinelWorkspace.id
    category: 'sentinel'
    tags: [
      {
        'key': 'compliance'
        'value': 'multi-regulatory'
      }
      {
        'key': 'industry'
        'value': 'bio-pharma'
      }
    ]
  }
}

// --------------------- ENHANCEMENT 2: ML-BASED ANOMALY DETECTION -----------------------

// ML-based anomaly detection solution workbook
resource mlAnomalyDetection 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${resourceNames.mlSolution}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Bio-Pharma ML Anomaly Detection'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# ML-Based Anomaly Detection for Research Data Access\n---\n\nThis solution uses machine learning to detect anomalous access patterns to research data, helping protect valuable intellectual property."
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
              "durationMs": 604800000
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
            "name": "AnomalyThreshold",
            "type": 2,
            "typeSettings": {
              "additionalResourceOptions": [],
              "showDefault": false
            },
            "jsonData": "[{\"value\":\"2\",\"label\":\"Low (2 std dev)\"},{\"value\":\"3\",\"label\":\"Medium (3 std dev)\"},{\"value\":\"4\",\"label\":\"High (4 std dev)\"}]",
            "defaultValue": "3",
            "label": "Anomaly Threshold"
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
        "query": "// ML Anomaly Detection Example\n// In a real implementation, this would use ML algorithms such as:\n// - Time series decomposition\n// - Isolation forests\n// - DBSCAN clustering\n// - Neural networks\n\n// Simulated data for demonstration purposes\nlet userData = datatable(TimeGenerated:datetime, UserName:string, ResourceAccessed:string, AccessCount:int, DayOfWeek:string, HourOfDay:int)\n[\n    datetime(2025-03-25T09:15:00Z), 'researcher1@company.com', 'ELN-Project-A', 12, 'Tuesday', 9,\n    datetime(2025-03-25T14:22:00Z), 'researcher1@company.com', 'LIMS-Sample-Database', 8, 'Tuesday', 14,\n    datetime(2025-03-26T10:30:00Z), 'researcher1@company.com', 'ELN-Project-A', 15, 'Wednesday', 10,\n    datetime(2025-03-27T11:45:00Z), 'researcher1@company.com', 'ELN-Project-A', 10, 'Thursday', 11,\n    datetime(2025-03-28T16:15:00Z), 'researcher1@company.com', 'ELN-Project-A', 7, 'Friday', 16,\n    datetime(2025-03-29T12:20:00Z), 'researcher1@company.com', 'ELN-Project-A', 3, 'Saturday', 12, // Weekend access\n    datetime(2025-03-30T23:10:00Z), 'researcher1@company.com', 'ELN-Project-A', 25, 'Sunday', 23, // Night access + high volume\n    datetime(2025-03-25T09:15:00Z), 'researcher2@company.com', 'ELN-Project-B', 8, 'Tuesday', 9,\n    datetime(2025-03-26T10:30:00Z), 'researcher2@company.com', 'ELN-Project-B', 11, 'Wednesday', 10,\n    datetime(2025-03-27T11:45:00Z), 'researcher2@company.com', 'ELN-Project-B', 9, 'Thursday', 11,\n    datetime(2025-03-28T16:15:00Z), 'researcher2@company.com', 'ELN-Project-B', 7, 'Friday', 16,\n    datetime(2025-03-25T09:15:00Z), 'researcher3@company.com', 'LIMS-Sample-Database', 15, 'Tuesday', 9,\n    datetime(2025-03-26T10:30:00Z), 'researcher3@company.com', 'LIMS-Sample-Database', 12, 'Wednesday', 10,\n    datetime(2025-03-27T11:45:00Z), 'researcher3@company.com', 'LIMS-Sample-Database', 17, 'Thursday', 11,\n    datetime(2025-03-27T03:15:00Z), 'researcher3@company.com', 'ELN-Project-C', 45, 'Thursday', 3, // Night access + high volume\n    datetime(2025-03-28T16:15:00Z), 'researcher3@company.com', 'LIMS-Sample-Database', 11, 'Friday', 16\n];\n\n// Calculate baseline metrics\nlet userBaseline = userData\n| summarize \n    AvgAccessCount = avg(AccessCount),\n    StdDevAccessCount = sqrt(variance(AccessCount)),\n    AvgHour = avg(HourOfDay),\n    StdDevHour = sqrt(variance(HourOfDay)),\n    WeekendAccess = countif(DayOfWeek in ('Saturday', 'Sunday')),\n    NightAccess = countif(HourOfDay < 6 or HourOfDay > 20)\n    by UserName;\n\n// Join with actual data to detect anomalies\nuserData\n| join kind=inner userBaseline on UserName\n| extend \n    IsAccessCountAnomaly = iff(abs(AccessCount - AvgAccessCount) > StdDevAccessCount * {AnomalyThreshold}, true, false),\n    IsTimeAnomaly = iff(HourOfDay < 6 or HourOfDay > 20, true, false),\n    IsWeekendAnomaly = iff(DayOfWeek in ('Saturday', 'Sunday'), true, false)\n| extend \n    AnomalyScore = iff(IsAccessCountAnomaly, 1, 0) + iff(IsTimeAnomaly, 1, 0) + iff(IsWeekendAnomaly, 1, 0),\n    AnomalyDescription = case(\n        IsAccessCountAnomaly and IsTimeAnomaly and IsWeekendAnomaly, \"High-volume access outside business hours on weekend\",\n        IsAccessCountAnomaly and IsTimeAnomaly, \"High-volume access outside business hours\",\n        IsAccessCountAnomaly and IsWeekendAnomaly, \"High-volume access on weekend\",\n        IsTimeAnomaly and IsWeekendAnomaly, \"Access outside business hours on weekend\",\n        IsAccessCountAnomaly, \"High-volume access\",\n        IsTimeAnomaly, \"Access outside business hours\",\n        IsWeekendAnomaly, \"Weekend access\",\n        \"Normal access\"\n    )\n| where AnomalyScore > 0\n| project \n    TimeGenerated, \n    UserName, \n    ResourceAccessed, \n    AccessCount, \n    DayOfWeek, \n    ['Hour of Access'] = HourOfDay,\n    ['Anomaly Score'] = AnomalyScore,\n    ['Anomaly Description'] = AnomalyDescription\n| sort by ['Anomaly Score'] desc",
        "size": 0,
        "title": "Research Data Access Anomalies",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "table",
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "Anomaly Score",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "==",
                    "thresholdValue": "1",
                    "representation": "yellow",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "2",
                    "representation": "orange",
                    "text": "{0}"
                  },
                  {
                    "operator": ">=",
                    "thresholdValue": "3",
                    "representation": "redBright",
                    "text": "{0}"
                  }
                ]
              }
            }
          ]
        }
      },
      "name": "ml-anomaly-query"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: sentinelWorkspace.id
    category: 'sentinel'
    tags: [
      {
        'key': 'feature'
        'value': 'ml-anomaly-detection'
      }
      {
        'key': 'protection'
        'value': 'intellectual-property'
      }
    ]
  }
}

// --------------------- ENHANCEMENT 3: SUPPLY CHAIN SECURITY -----------------------

// Supply chain security monitoring workbook
resource supplyChainWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${resourceNames.supplyChainWorkbook}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Bio-Pharma Supply Chain Security Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Pharmaceutical Supply Chain Security Monitoring\n---\n\nThis workbook provides visibility into the security of the pharmaceutical supply chain, from raw materials to distribution."
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
            "name": "SupplyChainStage",
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
            "jsonData": "[{\"value\":\"RawMaterials\",\"label\":\"Raw Materials\"},{\"value\":\"Manufacturing\",\"label\":\"Manufacturing\"},{\"value\":\"QualityControl\",\"label\":\"Quality Control\"},{\"value\":\"Packaging\",\"label\":\"Packaging\"},{\"value\":\"Distribution\",\"label\":\"Distribution\"},{\"value\":\"ColdChain\",\"label\":\"Cold Chain\"}]",
            "defaultValue": "value::all",
            "label": "Supply Chain Stage"
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
        "query": "// Supply Chain Security Events\n// Simulated data for demonstration purposes\nlet supplyChainEvents = datatable(TimeGenerated:datetime, Stage:string, EventType:string, Severity:string, Description:string)\n[\n    datetime(2025-03-15T09:15:00Z), 'RawMaterials', 'Authentication', 'Low', 'Supplier portal login from unusual location',\n    datetime(2025-03-16T14:22:00Z), 'RawMaterials', 'Data Access', 'Medium', 'Unusual batch certificate download pattern',\n    datetime(2025-03-17T10:30:00Z), 'Manufacturing', 'Configuration', 'High', 'Unexpected MES recipe parameter change',\n    datetime(2025-03-18T11:45:00Z), 'Manufacturing', 'Authentication', 'Medium', 'Failed login attempts to manufacturing system',\n    datetime(2025-03-19T16:15:00Z), 'QualityControl', 'Data Access', 'Low', 'Quality test result modification',\n    datetime(2025-03-20T12:20:00Z), 'QualityControl', 'System Alert', 'High', 'QC database unauthorized access attempt',\n    datetime(2025-03-21T13:10:00Z), 'Packaging', 'Configuration', 'Medium', 'Packaging line configuration changed',\n    datetime(2025-03-22T09:15:00Z), 'Packaging', 'Data Access', 'Low', 'Serial number database query from unusual source',\n    datetime(2025-03-23T10:30:00Z), 'Distribution', 'System Alert', 'High', 'ERP system integration failure with shipping provider',\n    datetime(2025-03-24T11:45:00Z), 'Distribution', 'Authentication', 'Medium', 'Logistics portal unusual access pattern',\n    datetime(2025-03-25T16:15:00Z), 'ColdChain', 'System Alert', 'Critical', 'Temperature monitoring system communication failure',\n    datetime(2025-03-26T12:20:00Z), 'ColdChain', 'Configuration', 'High', 'Temperature threshold modified outside change control'\n];\n\nsupplyChainEvents\n| where Stage in ({SupplyChainStage}) or '*' in ({SupplyChainStage})\n| project TimeGenerated, ['Supply Chain Stage'] = Stage, ['Event Type'] = EventType, Severity, Description\n| sort by TimeGenerated desc",
        "size": 0,
        "title": "Supply Chain Security Events",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "table",
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "Severity",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "==",
                    "thresholdValue": "Low",
                    "representation": "green",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "Medium",
                    "representation": "yellow",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "High",
                    "representation": "orange",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "Critical",
                    "representation": "redBright",
                    "text": "{0}"
                  }
                ]
              }
            }
          ]
        }
      },
      "name": "supply-chain-events-query"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// Cold Chain Temperature Monitoring\n// Simulated data for demonstration purposes\nlet temperatureData = datatable(TimeGenerated:datetime, ShipmentID:string, Temperature:decimal, ThresholdMin:decimal, ThresholdMax:decimal, Location:string)\n[\n    datetime(2025-03-25T00:00:00Z), 'SHIP-123456', 2.5, 2.0, 8.0, 'Manufacturing Facility',\n    datetime(2025-03-25T02:00:00Z), 'SHIP-123456', 3.1, 2.0, 8.0, 'Manufacturing Facility',\n    datetime(2025-03-25T04:00:00Z), 'SHIP-123456', 3.0, 2.0, 8.0, 'Manufacturing Facility',\n    datetime(2025-03-25T06:00:00Z), 'SHIP-123456', 2.8, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T08:00:00Z), 'SHIP-123456', 3.2, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T10:00:00Z), 'SHIP-123456', 4.5, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T12:00:00Z), 'SHIP-123456', 8.5, 2.0, 8.0, 'In Transit', // Exceeds max threshold\n    datetime(2025-03-25T14:00:00Z), 'SHIP-123456', 7.8, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T16:00:00Z), 'SHIP-123456', 5.2, 2.0, 8.0, 'Distribution Center',\n    datetime(2025-03-25T18:00:00Z), 'SHIP-123456', 4.5, 2.0, 8.0, 'Distribution Center',\n    datetime(2025-03-25T20:00:00Z), 'SHIP-123456', 3.8, 2.0, 8.0, 'Distribution Center',\n    datetime(2025-03-25T22:00:00Z), 'SHIP-123456', 3.5, 2.0, 8.0, 'Distribution Center',\n    datetime(2025-03-25T00:00:00Z), 'SHIP-789012', 4.5, 2.0, 8.0, 'Manufacturing Facility',\n    datetime(2025-03-25T02:00:00Z), 'SHIP-789012', 4.1, 2.0, 8.0, 'Manufacturing Facility',\n    datetime(2025-03-25T04:00:00Z), 'SHIP-789012', 4.0, 2.0, 8.0, 'Manufacturing Facility',\n    datetime(2025-03-25T06:00:00Z), 'SHIP-789012', 3.8, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T08:00:00Z), 'SHIP-789012', 3.2, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T10:00:00Z), 'SHIP-789012', 1.5, 2.0, 8.0, 'In Transit', // Below min threshold\n    datetime(2025-03-25T12:00:00Z), 'SHIP-789012', 2.5, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T14:00:00Z), 'SHIP-789012', 3.8, 2.0, 8.0, 'In Transit',\n    datetime(2025-03-25T16:00:00Z), 'SHIP-789012', 4.2, 2.0, 8.0, 'Distribution Center',\n    datetime(2025-03-25T18:00:00Z), 'SHIP-789012', 4.5, 2.0, 8.0, 'Distribution Center',\n    datetime(2025-03-25T20:00:00Z), 'SHIP-789012', 4.8, 2.0, 8.0, 'Distribution Center',\n    datetime(2025-03-25T22:00:00Z), 'SHIP-789012', 4.5, 2.0, 8.0, 'Distribution Center'\n];\n\ntemperatureData\n| extend Status = case(\n    Temperature < ThresholdMin, 'Below Threshold',\n    Temperature > ThresholdMax, 'Above Threshold',\n    'Within Range'\n)\n| project TimeGenerated, ShipmentID, Temperature, ThresholdMin, ThresholdMax, Location, Status",
        "size": 0,
        "title": "Cold Chain Temperature Monitoring",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "linechart",
        "chartSettings": {
          "ySettings": {
            "min": 0
          },
          "showLegend": true,
          "seriesLabelSettings": [
            {
              "seriesName": "Temperature",
              "label": "Temperature (°C)"
            },
            {
              "seriesName": "ThresholdMin",
              "label": "Min Threshold (°C)"
            },
            {
              "seriesName": "ThresholdMax",
              "label": "Max Threshold (°C)"
            }
          ]
        }
      },
      "name": "cold-chain-monitoring-query",
      "conditionalVisibility": {
        "parameterName": "SupplyChainStage",
        "comparison": "isEqualTo",
        "value": "ColdChain"
      }
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: sentinelWorkspace.id
    category: 'sentinel'
    tags: [
      {
        'key': 'feature'
        'value': 'supply-chain-security'
      }
      {
        'key': 'industry'
        'value': 'bio-pharma'
      }
    ]
  }
}

// --------------------- ENHANCEMENT 4: CONTAINER SECURITY MONITORING -----------------------

// Container security monitoring workbook
resource containerSecurityWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${resourceNames.containerSecurityWorkbook}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Bio-Pharma Container Security Monitoring'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Bio-Pharmaceutical Container Security Monitoring\n---\n\nThis workbook provides security monitoring for containerized bio-pharma applications and research environments."
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
              "durationMs": 604800000
            },
            "typeSettings": {
              "selectableValues": [
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
            "name": "Environment",
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
            "jsonData": "[{\"value\":\"Research\",\"label\":\"Research Environment\"},{\"value\":\"Development\",\"label\":\"Development\"},{\"value\":\"QA\",\"label\":\"Quality Assurance\"},{\"value\":\"Production\",\"label\":\"Production\"}]",
            "defaultValue": "value::all",
            "label": "Environment"
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
        "query": "// Container Security Posture\n// Simulated data for demonstration purposes\nlet containerData = datatable(TimeGenerated:datetime, Environment:string, ClusterName:string, Namespace:string, ImageName:string, SecurityIssues:int, CriticalVulnerabilities:int, HighVulnerabilities:int, MediumVulnerabilities:int, LowVulnerabilities:int)\n[\n    datetime(2025-03-20T00:00:00Z), 'Research', 'aks-research-001', 'datascience', 'custom-r-analytics:latest', 12, 2, 4, 5, 1,\n    datetime(2025-03-20T00:00:00Z), 'Research', 'aks-research-001', 'genomics', 'genomics-processor:v1', 8, 1, 2, 3, 2,\n    datetime(2025-03-20T00:00:00Z), 'Research', 'aks-research-001', 'proteomics', 'protein-analysis:v2', 15, 3, 5, 6, 1,\n    datetime(2025-03-20T00:00:00Z), 'Development', 'aks-dev-001', 'clinical-app', 'clinical-api:dev', 10, 1, 3, 4, 2,\n    datetime(2025-03-20T00:00:00Z), 'Development', 'aks-dev-001', 'lims-dev', 'lims-service:dev', 7, 0, 2, 3, 2,\n    datetime(2025-03-20T00:00:00Z), 'QA', 'aks-qa-001', 'clinical-app', 'clinical-api:qa', 5, 0, 1, 2, 2,\n    datetime(2025-03-20T00:00:00Z), 'QA', 'aks-qa-001', 'lims-qa', 'lims-service:qa', 4, 0, 1, 2, 1,\n    datetime(2025-03-20T00:00:00Z), 'Production', 'aks-prod-001', 'clinical-app', 'clinical-api:prod', 2, 0, 0, 1, 1,\n    datetime(2025-03-20T00:00:00Z), 'Production', 'aks-prod-001', 'lims-prod', 'lims-service:prod', 1, 0, 0, 0, 1\n];\n\ncontainerData\n| where Environment in ({Environment}) or '*' in ({Environment})\n| project \n    Environment, \n    ClusterName, \n    Namespace, \n    ImageName, \n    SecurityIssues, \n    ['Critical Vulnerabilities'] = CriticalVulnerabilities, \n    ['High Vulnerabilities'] = HighVulnerabilities, \n    ['Medium Vulnerabilities'] = MediumVulnerabilities, \n    ['Low Vulnerabilities'] = LowVulnerabilities\n| sort by SecurityIssues desc",
        "size": 0,
        "title": "Container Security Posture",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "table",
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "SecurityIssues",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "<=",
                    "thresholdValue": "3",
                    "representation": "green",
                    "text": "{0}"
                  },
                  {
                    "operator": "<=",
                    "thresholdValue": "8",
                    "representation": "yellow",
                    "text": "{0}"
                  },
                  {
                    "operator": ">",
                    "thresholdValue": "8",
                    "representation": "redBright",
                    "text": "{0}"
                  }
                ]
              }
            },
            {
              "columnMatch": "Critical Vulnerabilities",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "==",
                    "thresholdValue": "0",
                    "representation": "green",
                    "text": "{0}"
                  },
                  {
                    "operator": ">",
                    "thresholdValue": "0",
                    "representation": "redBright",
                    "text": "{0}"
                  }
                ]
              }
            },
            {
              "columnMatch": "High Vulnerabilities",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "==",
                    "thresholdValue": "0",
                    "representation": "green",
                    "text": "{0}"
                  },
                  {
                    "operator": "<=",
                    "thresholdValue": "2",
                    "representation": "yellow",
                    "text": "{0}"
                  },
                  {
                    "operator": ">",
                    "thresholdValue": "2",
                    "representation": "orange",
                    "text": "{0}"
                  }
                ]
              }
            }
          ]
        }
      },
      "name": "container-security-query"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// Container Runtime Security Events\n// Simulated data for demonstration purposes\nlet containerEvents = datatable(TimeGenerated:datetime, Environment:string, ClusterName:string, Namespace:string, PodName:string, EventType:string, Severity:string, Description:string)\n[\n    datetime(2025-03-22T09:15:00Z), 'Research', 'aks-research-001', 'datascience', 'r-analytics-pod-7', 'Privilege Escalation', 'High', 'Process running with escalated privileges detected',\n    datetime(2025-03-22T14:22:00Z), 'Research', 'aks-research-001', 'genomics', 'genomics-proc-3', 'Unusual Network', 'Medium', 'Outbound connection to unusual endpoint',\n    datetime(2025-03-22T10:30:00Z), 'Research', 'aks-research-001', 'proteomics', 'protein-pod-2', 'Sensitive File Access', 'High', 'Sensitive configuration file accessed',\n    datetime(2025-03-23T11:45:00Z), 'Development', 'aks-dev-001', 'clinical-app', 'clinical-api-pod-5', 'File Modification', 'Medium', 'Unexpected modification to application file',\n    datetime(2025-03-23T16:15:00Z), 'Development', 'aks-dev-001', 'lims-dev', 'lims-pod-1', 'Process Execution', 'Low', 'Unusual process execution detected',\n    datetime(2025-03-24T12:20:00Z), 'QA', 'aks-qa-001', 'clinical-app', 'clinical-api-pod-2', 'Container Escape', 'Critical', 'Potential container escape attempt detected',\n    datetime(2025-03-24T13:10:00Z), 'QA', 'aks-qa-001', 'lims-qa', 'lims-pod-3', 'Reverse Shell', 'High', 'Potential reverse shell detected',\n    datetime(2025-03-25T09:15:00Z), 'Production', 'aks-prod-001', 'clinical-app', 'clinical-api-pod-1', 'Unusual Network', 'Medium', 'Unusual internal network scanning activity',\n    datetime(2025-03-25T10:30:00Z), 'Production', 'aks-prod-001', 'lims-prod', 'lims-pod-2', 'Resource Abuse', 'Low', 'Unusual CPU utilization spike'\n];\n\ncontainerEvents\n| where Environment in ({Environment}) or '*' in ({Environment})\n| project \n    TimeGenerated, \n    Environment, \n    ClusterName, \n    Namespace, \n    PodName, \n    ['Event Type'] = EventType, \n    Severity, \n    Description\n| sort by TimeGenerated desc",
        "size": 0,
        "title": "Container Runtime Security Events",
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "table",
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "Severity",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "==",
                    "thresholdValue": "Low",
                    "representation": "green",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "Medium",
                    "representation": "yellow",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "High",
                    "representation": "orange",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "Critical",
                    "representation": "redBright",
                    "text": "{0}"
                  }
                ]
              }
            }
          ]
        }
      },
      "name": "container-events-query"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: sentinelWorkspace.id
    category: 'sentinel'
    tags: [
      {
        'key': 'feature'
        'value': 'container-security'
      }
      {
        'key': 'industry'
        'value': 'bio-pharma'
      }
    ]
  }
}

// --------------------- ENHANCEMENT 5: ATTACK SIMULATION FRAMEWORK -----------------------

// Attack simulation framework - Logic App
resource attackSimulationLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${resourceNames.logicAppPrefix}-attack-simulation'
  location: location
  tags: resourceTags
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              properties: {
                attackScenario: {
                  type: 'string'
                  enum: [
                    'IP_Theft'
                    'Clinical_Data_Breach'
                    'Supply_Chain_Attack'
                    'Insider_Threat'
                    'Ransomware'
                  ]
                }
                intensity: {
                  type: 'string'
                  enum: [
                    'Low'
                    'Medium'
                    'High'
                  ]
                }
                timeout: {
                  default: 60
                  type: 'integer'
                }
              }
              required: [
                'attackScenario'
                'intensity'
              ]
              type: 'object'
            }
          }
        }
      }
      actions: {
        Parse_request: {
          runAfter: {}
          type: 'ParseJson'
          inputs: {
            content: '@triggerBody()'
            schema: {
              properties: {
                attackScenario: {
                  type: 'string'
                }
                intensity: {
                  type: 'string'
                }
                timeout: {
                  type: 'integer'
                }
              }
              type: 'object'
            }
          }
        }
        Run_simulation_script: {
          runAfter: {
            Parse_request: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://funcionapp-not-real-url.azurewebsites.net/api/RunSimulation'
            body: {
              attackScenario: '@body(\'Parse_request\').attackScenario'
              intensity: '@body(\'Parse_request\').intensity'
              timeout: '@body(\'Parse_request\').timeout'
              workspaceId: '@{listCallbackUrl().queries.triggerHash}'
            }
          }
        }
        Return_simulation_result: {
          runAfter: {
            Run_simulation_script: [
              'Succeeded'
            ]
          }
          type: 'Response'
          inputs: {
            body: {
              simulationId: '@guid()'
              message: 'Attack simulation started successfully.'
              details: 'The @{body(\'Parse_request\').attackScenario} scenario is being simulated at @{body(\'Parse_request\').intensity} intensity for maximum @{body(\'Parse_request\').timeout} minutes.'
              estimatedCompletion: '@{addMinutes(utcNow(), body(\'Parse_request\').timeout)}'
            }
            statusCode: 200
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {}
      }
    }
  }
}

// --------------------- ENHANCEMENT 6: MULTI-TENANT SUPPORT -----------------------

// Multi-tenant configuration workbook
resource multiTenantWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('${resourceNames.multiTenantConfig}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Bio-Pharma Multi-Tenant Configuration'
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Bio-Pharmaceutical Multi-Tenant Configuration\n---\n\nThis workbook helps configure and manage multi-tenant deployments for pharmaceutical organizations with multiple subsidiaries or business units."
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
            "name": "Tenant",
            "type": 2,
            "typeSettings": {
              "additionalResourceOptions": [],
              "showDefault": false
            },
            "jsonData": "[{\"value\":\"Corporate\",\"label\":\"Corporate SOC\"},{\"value\":\"ResearchDivision\",\"label\":\"Research Division\"},{\"value\":\"ClinicalTrials\",\"label\":\"Clinical Trials Unit\"},{\"value\":\"Manufacturing\",\"label\":\"Manufacturing Division\"},{\"value\":\"Distribution\",\"label\":\"Distribution & Supply Chain\"}]",
            "label": "Tenant View"
          }
        ],
        "style": "pills",
        "queryType": 0
      },
      "name": "parameters"
    },
    {
      "type": 1,
      "content": {
        "json": "## Tenant Configuration\n\nThis section provides the multi-tenant configuration and separation of duties between different business units.\n\n### How Multi-Tenancy Works\n\n1. **Centralized SOC with Tenant Views**: The central security operations center has visibility across all tenants, while each tenant has limited visibility to their specific scope.\n\n2. **Resource Isolation**: Each tenant's data is logically isolated using separate workspaces and custom RBAC.\n\n3. **Cross-Tenant Correlation**: Security events are correlated across tenants while maintaining appropriate isolation.\n\n4. **Regulatory Separation**: Allows different regulatory frameworks to be applied to different business units as needed."
      },
      "name": "text-section"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// Tenant Configuration Table\n// Simulated data for demonstration purposes\ndatatable(TenantName:string, Status:string, WorkspaceCount:int, DataConnectors:int, AnalyticsRules:int, LastUpdated:datetime, PrimaryRegion:string, TenantType:string)\n[\n    'Corporate', 'Active', 5, 18, 42, datetime(2025-03-15), 'US East', 'Management',\n    'ResearchDivision', 'Active', 3, 12, 36, datetime(2025-03-10), 'US East', 'Research',\n    'ClinicalTrials', 'Active', 2, 10, 28, datetime(2025-03-12), 'EU West', 'Clinical',\n    'Manufacturing', 'Active', 4, 15, 32, datetime(2025-03-08), 'APAC', 'Manufacturing',\n    'Distribution', 'Active', 2, 8, 18, datetime(2025-03-05), 'Multiple', 'Distribution'\n]\n| where TenantName == '{Tenant}' or '{Tenant}' == 'Corporate'\n| project ['Tenant Name'] = TenantName, Status, ['Workspace Count'] = WorkspaceCount, ['Data Connectors'] = DataConnectors, ['Analytics Rules'] = AnalyticsRules, ['Last Updated'] = LastUpdated, ['Primary Region'] = PrimaryRegion, ['Tenant Type'] = TenantType",
        "size": 0,
        "title": "Tenant Configuration",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "table"
      },
      "name": "tenant-config-query"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "// Tenant Security Events\n// Simulated data for demonstration purposes\ndatatable(TimeGenerated:datetime, TenantName:string, EventSeverity:string, EventCount:int, EventType:string)\n[\n    datetime(2025-03-20), 'Corporate', 'High', 12, 'User Account',\n    datetime(2025-03-20), 'Corporate', 'Medium', 45, 'User Account',\n    datetime(2025-03-20), 'Corporate', 'Low', 156, 'User Account',\n    datetime(2025-03-20), 'Corporate', 'High', 8, 'Endpoint',\n    datetime(2025-03-20), 'Corporate', 'Medium', 34, 'Endpoint',\n    datetime(2025-03-20), 'Corporate', 'Low', 128, 'Endpoint',\n    datetime(2025-03-20), 'Corporate', 'High', 5, 'Network',\n    datetime(2025-03-20), 'Corporate', 'Medium', 28, 'Network',\n    datetime(2025-03-20), 'Corporate', 'Low', 98, 'Network',\n    datetime(2025-03-20), 'ResearchDivision', 'High', 6, 'Data Access',\n    datetime(2025-03-20), 'ResearchDivision', 'Medium', 22, 'Data Access',\n    datetime(2025-03-20), 'ResearchDivision', 'Low', 85, 'Data Access',\n    datetime(2025-03-20), 'ResearchDivision', 'High', 4, 'User Account',\n    datetime(2025-03-20), 'ResearchDivision', 'Medium', 18, 'User Account',\n    datetime(2025-03-20), 'ResearchDivision', 'Low', 67, 'User Account',\n    datetime(2025-03-20), 'ClinicalTrials', 'High', 3, 'PHI Access',\n    datetime(2025-03-20), 'ClinicalTrials', 'Medium', 15, 'PHI Access',\n    datetime(2025-03-20), 'ClinicalTrials', 'Low', 48, 'PHI Access',\n    datetime(2025-03-20), 'Manufacturing', 'High', 5, 'System Change',\n    datetime(2025-03-20), 'Manufacturing', 'Medium', 23, 'System Change',\n    datetime(2025-03-20), 'Manufacturing', 'Low', 76, 'System Change',\n    datetime(2025-03-20), 'Distribution', 'High', 2, 'Supply Chain',\n    datetime(2025-03-20), 'Distribution', 'Medium', 11, 'Supply Chain',\n    datetime(2025-03-20), 'Distribution', 'Low', 42, 'Supply Chain'\n]\n| where TenantName == '{Tenant}' or '{Tenant}' == 'Corporate'\n| summarize ['Event Count'] = sum(EventCount) by TenantName, EventSeverity, EventType\n| order by TenantName, EventSeverity, ['Event Count'] desc",
        "size": 0,
        "title": "Tenant Security Events",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [
          "{Workspace}"
        ],
        "visualization": "table",
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "EventSeverity",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  {
                    "operator": "==",
                    "thresholdValue": "Low",
                    "representation": "green",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "Medium",
                    "representation": "yellow",
                    "text": "{0}"
                  },
                  {
                    "operator": "==",
                    "thresholdValue": "High",
                    "representation": "redBright",
                    "text": "{0}"
                  }
                ]
              }
            }
          ]
        }
      },
      "name": "tenant-events-query"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
'''
    sourceId: sentinelWorkspace.id
    category: 'sentinel'
    tags: [
      {
        'key': 'feature'
        'value': 'multi-tenant'
      }
      {
        'key': 'industry'
        'value': 'bio-pharma'
      }
    ]
  }
}

// Output all enhancement resource IDs for reference
output complianceDashboardId string = complianceDashboard.id
output mlAnomalyDetectionId string = mlAnomalyDetection.id
output supplyChainWorkbookId string = supplyChainWorkbook.id
output containerSecurityWorkbookId string = containerSecurityWorkbook.id
output attackSimulationLogicAppId string = attackSimulationLogicApp.id
output multiTenantWorkbookId string = multiTenantWorkbook.id
