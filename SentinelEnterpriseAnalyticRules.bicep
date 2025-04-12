// Add these rules after the existing ones

// 3. GxP System Monitoring - Manufacturing Change Detection
resource gxpSystemChangeRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.gxpSystemChangeRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'GxP System - Unauthorized Configuration Change'
    description: 'Detects unauthorized changes to GxP-validated manufacturing systems'
    severity: 'High'
    enabled: true
    query: '''
      // Enhanced detection for GxP system changes
      Custom-MES_CL
      | where RawData has_any ("Configuration", "Recipe", "Parameter", "Change", "Setting")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend SystemName = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ChangeType = extract("Change[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ChangeID = extract("ChangeID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ValidationStatus = extract("ValidationStatus[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where ValidationStatus has_any ("Validated", "Qualified", "Production")
      | where isempty(ChangeID) or ChangeID == "" or ChangeID == "None"
      | project TimeGenerated, UserName, SystemName, ChangeType, ValidationStatus
    '''
    queryFrequency: 'PT15M'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Persistence'
      'PrivilegeEscalation'
    ]
    techniques: [
      'T1078' // Valid Accounts
      'T1098' // Account Manipulation
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
      alertDisplayNameFormat: 'GxP System Change Alert: {{UserName}} modified {{SystemName}}'
      alertDescriptionFormat: 'User {{UserName}} performed unauthorized {{ChangeType}} change to validated system {{SystemName}} without a change control ID'
    }
  }
}

// 4. Cross-Border IP Access Detection
resource crossBorderIPAccessRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.crossBorderIPAccessRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Cross-Border IP Access Detection'
    description: 'Detects access to intellectual property from unexpected geographic locations'
    severity: 'Medium'
    enabled: true
    query: '''
      // Cross-border IP access detection
      union Custom-ELN_CL, Custom-LIMS_CL
      | where RawData has_any ("IP", "Research", "Formula", "Confidential", "Restricted")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend UserLocation = extract("Location[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend DataLocation = extract("DataLocation[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where isnotempty(UserLocation) and isnotempty(DataLocation) and UserLocation != DataLocation
      | where DataClassification has_any ("IP", "Research", "Formula", "Confidential", "Restricted")
      | project TimeGenerated, UserName, ResourceName, UserLocation, DataLocation, DataClassification
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT4H'
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
  }
}

// 5. Cold Chain Monitoring Alert
resource coldChainAuthRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.coldChainAuthRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Cold Chain Monitoring System Alert'
    description: 'Detects unauthorized access or changes to cold chain monitoring systems'
    severity: 'High'
    enabled: true
    query: '''
      // Cold chain monitoring alert
      Custom-COLDCHAIN_CL
      | where RawData has_any ("Temperature", "Threshold", "Alert", "Deviation", "Configuration")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend SystemID = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend OldValue = extract("OldValue[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend NewValue = extract("NewValue[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ChangeID = extract("ChangeID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where ActionType has_any ("Threshold", "Configuration", "Setting", "Parameter") 
      | where isempty(ChangeID) or ChangeID == "" or ChangeID == "None"
      | project TimeGenerated, UserName, SystemID, ActionType, OldValue, NewValue
    '''
    queryFrequency: 'PT15M'
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
      'T1078' // Valid Accounts
      'T1565' // Data Manipulation
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
  }
}

// 6. Lab Instrument Anomaly Detection
resource labInstrumentAnomalyRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.labInstrumentAnomalyRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Laboratory Instrument Anomaly Detection'
    description: 'Detects unusual behavior or manipulation of laboratory instruments'
    severity: 'Medium'
    enabled: true
    query: '''
      // Laboratory instrument anomaly detection
      Custom-Instruments_CL
      | where RawData has_any ("Error", "Failed", "Critical", "Security", "Unauthorized", "Alert", "Unexpected")
      | extend InstrumentID = extract("Instrument[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ReadingType = extract("Reading[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ActionType = extract("Action[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend OperatorID = extract("Operator[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ErrorType = extract("Error[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | project TimeGenerated, InstrumentID, ReadingType, ActionType, OperatorID, ErrorType
    '''
    queryFrequency: 'PT30M'
    queryPeriod: 'PT6H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Impact'
      'Collection'
    ]
    techniques: [
      'T1565' // Data Manipulation
      'T1213' // Data from Information Repositories
    ]
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'OperatorID'
          }
        ]
      }
    ]
  }
}

// 7. Electronic Record Integrity Validation
resource electronicRecordIntegrityRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.electronicRecordIntegrityRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Electronic Record Integrity Validation'
    description: 'Detects potential tampering with electronic records for 21 CFR Part 11 compliance'
    severity: 'High'
    enabled: true
    query: '''
      // Electronic record integrity validation
      union 
        Custom-MES_CL, 
        Custom-ELN_CL,
        Custom-LIMS_CL,
        Custom-CTMS_CL
      | where RawData has_any ("Signature", "Validation", "Hash", "Checksum", "Integrity", "Record")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend RecordID = extract("RecordID[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend SignatureStatus = extract("SignatureStatus[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend HashValue = extract("Hash[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend SourceSystem = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where SignatureStatus has_any ("Invalid", "Failed", "Mismatch", "Error")
      | project TimeGenerated, UserName, RecordID, SignatureStatus, HashValue, SourceSystem
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT6H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Impact'
      'DefenseEvasion'
    ]
    techniques: [
      'T1565' // Data Manipulation
      'T1562' // Impair Defenses
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
  }
}

// 8. After-Hours Research Access Detection
resource afterHoursResearchRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.afterHoursResearchRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'After-Hours Research Data Access'
    description: 'Detects access to sensitive research data during non-business hours'
    severity: 'Medium'
    enabled: true
    query: '''
      // After-hours research access detection
      union 
        Custom-ELN_CL, 
        Custom-LIMS_CL
      | where RawData has_any ("Research", "Formula", "Confidential", "Restricted", "IP")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AccessType = extract("AccessType[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AccessHour = datetime_part("hour", TimeGenerated)
      | extend AccessDay = datetime_part("weekday", TimeGenerated)
      | where (AccessHour < 6 or AccessHour > 21 or AccessDay == 0 or AccessDay == 6)
      | where DataClassification has_any ("IP", "Research", "Formula", "Confidential", "Restricted")
      | project 
          TimeGenerated, 
          UserName, 
          ResourceName, 
          AccessType, 
          DataClassification, 
          ['Access Hour'] = AccessHour,
          ['Access Day'] = case(
            AccessDay == 0, "Sunday",
            AccessDay == 1, "Monday",
            AccessDay == 2, "Tuesday",
            AccessDay == 3, "Wednesday",
            AccessDay == 4, "Thursday",
            AccessDay == 5, "Friday",
            AccessDay == 6, "Saturday",
            "Unknown"
          )
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT4H'
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
  }
}

// Add output IDs for all new rules
output gxpSystemChangeRuleId string = gxpSystemChangeRule.id
output crossBorderIPAccessRuleId string = crossBorderIPAccessRule.id
output coldChainAuthRuleId string = coldChainAuthRule.id
output labInstrumentAnomalyRuleId string = labInstrumentAnomalyRule.id
output electronicRecordIntegrityRuleId string = electronicRecordIntegrityRule.id
output afterHoursResearchRuleId string = afterHoursResearchRule.id
