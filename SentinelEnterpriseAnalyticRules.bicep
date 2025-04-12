// Bio-Pharma Analytics Rules Module - Deploys specialized rules for pharmaceutical environments
@description('Prefix to use for resource naming')
param prefix string

@description('Name of the central Sentinel workspace')
param sentinelWorkspaceName string

@description('Name of the research workspace')
param researchWorkspaceName string

@description('Name of the manufacturing workspace') 
param manufacturingWorkspaceName string

@description('Name of the clinical workspace')
param clinicalWorkspaceName string

// Reference to Sentinel workspace (for scoping)
resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: sentinelWorkspaceName
}

// --------------------- BIO-PHARMA SPECIFIC ANALYTICS RULES -----------------------

// 1. Intellectual Property Protection - ELN Mass Download Detection
resource elnMassDownloadRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-eln-mass-download')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'ELN Mass Document Download Detection'
    description: 'This rule detects large-scale document downloads from Electronic Lab Notebooks, which may indicate intellectual property theft attempts'
    severity: 'High'
    enabled: true
    query: '''
      Custom-ELN_CL
      | where RawData has_any ("Download", "Export", "Print")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend DocumentCount = extract("Count[:\\s]+(\\d+)", 1, RawData)
      | extend DocumentType = extract("Type[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend DocumentSize = extract("Size[:\\s]+(\\d+)", 1, RawData)
      | where isnotempty(DocumentCount) and (toint(DocumentCount) > 10 or toint(DocumentSize) > 50000000)
      | project TimeGenerated, UserName, DocumentCount, DocumentType, DocumentSize, RawData
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Exfiltration'
      'Collection'
    ]
    techniques: [
      'T1048' // Exfiltration Over Alternative Protocol
      'T1530' // Data from Cloud Storage
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'IP Theft Risk: ELN Mass Download by {{UserName}}'
      alertDescriptionFormat: 'User {{UserName}} has downloaded {{DocumentCount}} research documents'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// 2. Clinical Trial Data Protection - Unauthorized PHI Access
resource phiAccessRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-phi-access')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Clinical Trial Data - Unauthorized PHI Access'
    description: 'This rule detects unauthorized access to patient health information in clinical trial systems'
    severity: 'High'
    enabled: true
    query: '''
      union 
        Custom-CTMS_CL, 
        Custom-PV_CL
      | where RawData has_any ("PHI", "PII", "Patient", "Subject") and RawData has "Access"
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend SubjectID = extract("Subject[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AccessType = extract("AccessType[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AuthStatus = extract("Status[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where isnotempty(SubjectID) and (AuthStatus has_any ("Denied", "Failed", "Unauthorized") or AccessType has_any ("Bulk", "Export", "Full"))
      | project TimeGenerated, UserName, SubjectID, AccessType, AuthStatus, RawData
    '''
    queryFrequency: 'PT30M'
    queryPeriod: 'PT30M'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Collection'
      'Exfiltration'
    ]
    techniques: [
      'T1530' // Data from Cloud Storage
      'T1213' // Data from Information Repositories
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'PHI Access Alert: {{UserName}} attempted access to {{SubjectID}}'
      alertDescriptionFormat: 'Potentially unauthorized access to patient data. User {{UserName}} attempted {{AccessType}} access to subject {{SubjectID}} with status {{AuthStatus}}'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// 3. Manufacturing System Security - GxP Validated System Change
resource gxpSystemChangeRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-gxp-system-change')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'GxP Validated System Change Detection'
    description: 'This rule detects changes to GxP validated systems outside of change control'
    severity: 'Medium'
    enabled: true
    query: '''
      union 
        Custom-MES_CL, 
        Custom-InstrumentQual_CL
      | where RawData has_any ("Configuration", "Setting", "Parameter", "Recipe", "Validation") and RawData has "Change"
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend SystemName = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ChangeType = extract("Change[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ChangeID = extract("ChangeID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ValidationStatus = extract("ValidationStatus[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where isempty(ChangeID) or ValidationStatus has_any ("Validated", "Qualified", "Production") or ChangeType has_any ("Critical", "Recipe", "Formula")
      | project TimeGenerated, UserName, SystemName, ChangeType, ChangeID, ValidationStatus, RawData
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Impact'
      'Persistence'
    ]
    techniques: [
      'T1195' // Supply Chain Compromise
      'T1505' // Server Software Component
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      },
      {
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'HostName'
            columnName: 'SystemName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'GxP System Change: {{SystemName}} by {{UserName}}'
      alertDescriptionFormat: 'Validated system {{SystemName}} was modified by {{UserName}} with change type {{ChangeType}}. Change Control ID: {{ChangeID}}. System validation status: {{ValidationStatus}}'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
          'Host'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// 4. Research Data Protection - Cross-Border IP Access
resource crossBorderIPAccessRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-cross-border-ip')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Cross-Border Research IP Access'
    description: 'This rule detects access to intellectual property from unexpected geographic locations'
    severity: 'Medium'
    enabled: true
    query: '''
      union 
        Custom-ELN_CL, 
        Custom-LIMS_CL
      | where RawData has_any ("Access", "View", "Open", "Download") 
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend UserLocation = extract("Location[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend DataLocation = extract("DataLocation[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where isnotempty(UserLocation) and isnotempty(DataLocation) and UserLocation != DataLocation
      | where DataClassification has_any ("IP", "Research", "Formula", "Confidential", "Restricted")
      | project TimeGenerated, UserName, ResourceName, DataClassification, UserLocation, DataLocation, RawData
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'InitialAccess'
      'Collection'
    ]
    techniques: [
      'T1078' // Valid Accounts
      'T1213' // Data from Information Repositories
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Cross-Border IP Access: {{UserName}} accessing {{DataClassification}} data'
      alertDescriptionFormat: 'User {{UserName}} from {{UserLocation}} accessed {{DataClassification}} data located in {{DataLocation}}. Resource: {{ResourceName}}'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// 5. Cold Chain Monitoring - Temperature Excursion With Authentication Anomaly
resource coldChainAuthRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-cold-chain-auth')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Cold Chain Authentication Anomaly with Temperature Excursion'
    description: 'This rule detects unusual authentication to cold chain systems followed by temperature excursions'
    severity: 'High'
    enabled: true
    query: '''
      // First identify authentication events
      let authEvents = Custom-ColdChain_CL
      | where RawData has_any ("Authentication", "Login", "Access")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend SystemName = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AuthType = extract("AuthType[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AuthStatus = extract("Status[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where AuthType has_any ("Remote", "API", "External") or AuthStatus has_any ("New IP", "New Location", "First Time")
      | project TimeGenerated, UserName, SystemName, AuthType, AuthStatus, RawData, AuthEvent=true;
      
      // Then identify temperature excursions
      let tempEvents = Custom-ColdChain_CL
      | where RawData has_any ("Temperature", "Excursion", "Violation", "Alarm", "Alert")
      | extend SystemName = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend TempValue = extract("Temperature[:\\s]+([\\-\\d\\.]+)", 1, RawData)
      | extend TempLimit = extract("Limit[:\\s]+([\\-\\d\\.]+)", 1, RawData)
      | extend ExcursionType = extract("Excursion[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where isnotempty(TempValue) and isnotempty(TempLimit)
      | project TimeGenerated, SystemName, TempValue, TempLimit, ExcursionType, RawData, TempEvent=true;
      
      // Correlate auth events with temperature excursions
      authEvents 
      | join kind=inner (tempEvents) on SystemName
      | where (TimeGenerated1 - TimeGenerated) between (0min .. 30min)
      | project 
          TimeGenerated, 
          UserName, 
          SystemName, 
          AuthType, 
          AuthStatus, 
          TempValue, 
          TempLimit, 
          ExcursionType,
          TimeBetweenEvents = datetime_diff('minute', TimeGenerated1, TimeGenerated)
    '''
    queryFrequency: 'PT30M'
    queryPeriod: 'PT2H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'InitialAccess'
      'Impact'
    ]
    techniques: [
      'T1078' // Valid Accounts
      'T1496' // Resource Hijacking
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      },
      {
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'HostName'
            columnName: 'SystemName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Cold Chain Security: {{SystemName}} auth followed by temperature excursion'
      alertDescriptionFormat: 'Unusual authentication by {{UserName}} to cold chain system {{SystemName}} was followed by a temperature excursion ({{TempValue}} vs limit {{TempLimit}}) within {{TimeBetweenEvents}} minutes'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
          'Host'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// 6. Laboratory Instrument Anomaly Detection
resource labInstrumentAnomalyRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-lab-instrument-anomaly')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Laboratory Instrument Control System Anomaly'
    description: 'This rule detects anomalies in laboratory instrument control systems that may indicate tampering'
    severity: 'Medium'
    enabled: true
    query: '''
      Custom-Instruments_CL
      | where RawData has_any ("Configuration", "Calibration", "Method", "Remote", "Connection", "Update")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend InstrumentID = extract("InstrumentID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ChangeType = extract("Change[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ConnectionType = extract("Connection[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend OperatingMode = extract("Mode[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where OperatingMode has_any ("Service", "Diagnostic", "Maintenance", "Debug")
      | where ConnectionType has_any ("Remote", "External", "VPN", "Internet") 
      | where ChangeType has_any ("Critical", "Method", "Calibration", "Firmware")
      | project TimeGenerated, UserName, InstrumentID, ChangeType, ConnectionType, OperatingMode, RawData
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'InitialAccess'
      'Persistence'
      'Tampering'
    ]
    techniques: [
      'T1078' // Valid Accounts
      'T1195' // Supply Chain Compromise
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      },
      {
        entityType: 'IoT Device'
        fieldMappings: [
          {
            identifier: 'DeviceId'
            columnName: 'InstrumentID'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Instrument Anomaly: {{InstrumentID}} modified in {{OperatingMode}} mode'
      alertDescriptionFormat: 'Laboratory instrument {{InstrumentID}} was remotely modified by {{UserName}} with connection type {{ConnectionType}} while in {{OperatingMode}} mode. Change type: {{ChangeType}}'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
          'IoT Device'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// 7. 21 CFR Part 11 Electronic Record Integrity Alert
resource electronicRecordIntegrityRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-electronic-record')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: '21 CFR Part 11 Electronic Record Integrity Alert'
    description: 'This rule detects potential tampering with electronic records covered by 21 CFR Part 11'
    severity: 'High'
    enabled: true
    query: '''
      union 
        Custom-MES_CL, 
        Custom-LIMS_CL,
        Custom-InstrumentQual_CL,
        Custom-CTMS_CL
      | where RawData has_any ("21CFR11", "Electronic Record", "Electronic Signature", "Audit Trail")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend RecordID = extract("RecordID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend PreviousHash = extract("PreviousHash[:\\s]+([a-fA-F0-9]+)", 1, RawData)
      | extend CurrentHash = extract("CurrentHash[:\\s]+([a-fA-F0-9]+)", 1, RawData)
      | extend SignatureStatus = extract("SignatureStatus[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where ActionType has_any ("Modify", "Delete", "Edit", "Change") or isempty(PreviousHash) or isempty(CurrentHash) or isempty(SignatureStatus) or SignatureStatus != "Valid"
      | project TimeGenerated, UserName, RecordID, ActionType, PreviousHash, CurrentHash, SignatureStatus, RawData
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'DefenseEvasion'
      'Impact'
    ]
    techniques: [
      'T1565' // Data Manipulation
      'T1070' // Indicator Removal
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: '21 CFR Part 11 Alert: Record {{RecordID}} integrity issue'
      alertDescriptionFormat: 'Potential electronic record compliance issue detected for record {{RecordID}}. Action: {{ActionType}}, Signature Status: {{SignatureStatus}}'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// 8. After-Hours Access to Proprietary Research
resource afterHoursResearchRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid('${prefix}-rule-after-hours-research')
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'After-Hours Access to Proprietary Research'
    description: 'This rule detects access to sensitive research data outside of normal business hours'
    severity: 'Medium'
    enabled: true
    query: '''
      union 
        Custom-ELN_CL, 
        Custom-LIMS_CL
      | where RawData has_any ("Access", "View", "Open", "Download", "Print", "Export")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AccessTime = TimeGenerated
      | extend UserLocation = extract("Location[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend UserDepartment = extract("Department[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where isnotempty(DataClassification) and DataClassification has_any ("IP", "Research", "Formula", "Confidential", "Restricted", "Proprietary")
      | where (dayofweek(AccessTime) == 0 or dayofweek(AccessTime) == 6) or (hourofday(AccessTime) < 6 or hourofday(AccessTime) > 20)
      | project AccessTime, UserName, UserDepartment, UserLocation, ResourceName, DataClassification, RawData
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Collection'
      'Exfiltration'
    ]
    techniques: [
      'T1530' // Data from Cloud Storage
      'T1213' // Data from Information Repositories
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'After-Hours Research Access: {{UserName}} at {{AccessTime}}'
      alertDescriptionFormat: 'User {{UserName}} from {{UserDepartment}} accessed {{DataClassification}} resource "{{ResourceName}}" at {{AccessTime}} from {{UserLocation}}'
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'Account'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
}

// Output rule IDs for reference
output elnMassDownloadRuleId string = elnMassDownloadRule.id
output phiAccessRuleId string = phiAccessRule.id
output gxpSystemChangeRuleId string = gxpSystemChangeRule.id
output crossBorderIPAccessRuleId string = crossBorderIPAccessRule.id
output coldChainAuthRuleId string = coldChainAuthRule.id
output labInstrumentAnomalyRuleId string = labInstrumentAnomalyRule.id
output electronicRecordIntegrityRuleId string = electronicRecordIntegrityRule.id
output afterHoursResearchRuleId string = afterHoursResearchRule.id
