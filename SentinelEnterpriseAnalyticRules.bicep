// Bio-Pharma Analytics Rules Module - Enhanced Version
// Deploys specialized rules for pharmaceutical environments with improved detection capabilities

@description('Prefix to use for resource naming')
param prefix string

@description('Environment (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'prod'

@description('Name of the central Sentinel workspace')
param sentinelWorkspaceName string

@description('Name of the research workspace')
param researchWorkspaceName string

@description('Name of the manufacturing workspace') 
param manufacturingWorkspaceName string

@description('Name of the clinical workspace')
param clinicalWorkspaceName string

// Improved resource naming
var resourceNames = {
  elnMassDownloadRule: '${prefix}-${environment}-rule-eln-mass-download'
  phiAccessRule: '${prefix}-${environment}-rule-phi-access'
  gxpSystemChangeRule: '${prefix}-${environment}-rule-gxp-system-change'
  crossBorderIPAccessRule: '${prefix}-${environment}-rule-cross-border-ip'
  coldChainAuthRule: '${prefix}-${environment}-rule-cold-chain-auth'
  labInstrumentAnomalyRule: '${prefix}-${environment}-rule-lab-instrument-anomaly'
  electronicRecordIntegrityRule: '${prefix}-${environment}-rule-electronic-record'
  afterHoursResearchRule: '${prefix}-${environment}-rule-after-hours-research'
}

// Reference to Sentinel workspace (for scoping)
resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: sentinelWorkspaceName
}

// --------------------- BIO-PHARMA SPECIFIC ANALYTICS RULES -----------------------

// 1. Intellectual Property Protection - ELN Mass Download Detection (Enhanced)
resource elnMassDownloadRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.elnMassDownloadRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'ELN Mass Document Download Detection'
    description: 'This rule detects large-scale document downloads from Electronic Lab Notebooks, which may indicate intellectual property theft attempts'
    severity: 'High'
    enabled: true
    query: '''
      // Improved detection with better contextual data
      Custom-ELN_CL
      | where RawData has_any ("Download", "Export", "Print", "Copy", "Save", "SaveAs")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend DocumentCount = extract("Count[:\\s]+(\\d+)", 1, RawData)
      | extend DocumentType = extract("Type[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend DocumentSize = extract("Size[:\\s]+(\\d+)", 1, RawData)
      | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AccessTime = TimeGenerated
      | extend ClientIP = extract("IP[:\\s]+([\\d\\.]+)", 1, RawData)
      | extend UserDepartment = extract("Department[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend UserLocation = extract("Location[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where isnotempty(DocumentCount) and (
          toint(DocumentCount) > 10 or                     // More than 10 documents
          toint(DocumentSize) > 50000000 or                // More than 50MB
          (isnotempty(DataClassification) and DataClassification has_any ("IP", "Research", "Formula", "Confidential", "Restricted"))
        )
      // Add time window context to identify rapid downloads
      | summarize 
          DocumentsDownloaded = sum(toint(DocumentCount)), 
          TotalSize = sum(toint(DocumentSize)),
          Documents = make_set(DocumentType, 10),
          DataClasses = make_set(DataClassification, 10),
          ClientIPs = make_set(ClientIP),
          TimeStamps = make_set(AccessTime, 10)
          by UserName, UserDepartment, UserLocation, bin(TimeGenerated, 1h)
      | where DocumentsDownloaded > 10 or TotalSize > 100000000
      | project 
          TimeGenerated, 
          UserName, 
          UserDepartment, 
          UserLocation, 
          DocumentsDownloaded, 
          TotalSize, 
          Documents, 
          DataClasses,
          ClientIPs,
          TimeStamps
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT6H'  // Extended to catch longer download patterns
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
      },
      {
        entityType: 'IP'
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'ClientIPs'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'IP Theft Risk: {{UserName}} downloaded {{DocumentsDownloaded}} research documents'
      alertDescriptionFormat: 'User {{UserName}} from {{UserDepartment}} has downloaded {{DocumentsDownloaded}} documents ({{TotalSize}} bytes) containing {{DataClasses}} data'
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
    customDetails: {
      Department: 'UserDepartment'
      Location: 'UserLocation'
      DocumentTypes: 'Documents'
      DataClassifications: 'DataClasses'
      DownloadTimestamps: 'TimeStamps'
    }
  }
}

// 2. Clinical Trial Data Protection - Unauthorized PHI Access (Enhanced)
resource phiAccessRule 'Microsoft.SecurityInsights/alertRules@2023-05-01' = {
  name: guid(resourceNames.phiAccessRule)
  kind: 'Scheduled'
  scope: sentinelWorkspace
  properties: {
    displayName: 'Clinical Trial Data - Unauthorized PHI Access'
    description: 'This rule detects unauthorized access to patient health information in clinical trial systems with enhanced detection for bulk access'
    severity: 'High'
    enabled: true
    query: '''
      // Enhanced to detect unauthorized bulk access to PHI
      union 
        Custom-CTMS_CL, 
        Custom-PV_CL
      | where RawData has_any ("PHI", "PII", "Patient", "Subject", "Data", "File", "Record", "Database") 
      and RawData has_any ("Access", "View", "Open", "Download", "Export", "Query", "Get")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend SubjectID = extract("Subject[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend StudyID = extract("Study[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AccessType = extract("AccessType[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend AuthStatus = extract("Status[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend PatientCount = extract("PatientCount[:\\s]+(\\d+)", 1, RawData)
      | extend RecordCount = extract("Count[:\\s]+(\\d+)", 1, RawData)
      | extend Reason = extract("Reason[:\\s]+([\\w\\-\\.\\s]+)", 1, RawData)
      | extend UserRole = extract("Role[:\\s]+([\\w\\-\\.\\s]+)", 1, RawData)
      | extend ClientIP = extract("IP[:\\s]+([\\d\\.]+)", 1, RawData)
      | extend UserLocation = extract("Location[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      // Detect unauthorized access patterns
      | where (
          // Explicit denial
          AuthStatus has_any ("Denied", "Failed", "Unauthorized", "Rejected") or
          // Bulk access
          AccessType has_any ("Bulk", "Export", "Full", "Mass", "All") or
          // Large record counts
          (isnotempty(PatientCount) and toint(PatientCount) > 10) or
          (isnotempty(RecordCount) and toint(RecordCount) > 20) or
          // Permissions mismatch (role doesn't match access pattern)
          (isnotempty(UserRole) and isnotempty(AccessType) and (
              (UserRole has_any("Nurse", "Coordinator") and AccessType has "Full") or
              (UserRole has "Monitor" and AccessType has "Admin") or
              (UserRole has "Data Entry" and AccessType has "Delete")
          ))
      )
      // Add time window context to identify unusual access patterns
      | summarize 
          AccessCount = count(),
          AccessTypes = make_set(AccessType, 10),
          AuthStatuses = make_set(AuthStatus, 10),
          Studies = make_set(StudyID, 10),
          Subjects = make_set(SubjectID, 20),
          ClientIPs = make_set(ClientIP, 10),
          AccessTimes = make_set(TimeGenerated, 10)
          by UserName, UserRole, UserLocation, bin(TimeGenerated, 1h)
      | project 
          TimeGenerated, 
          UserName, 
          UserRole,
          UserLocation,
          AccessCount,
          AccessTypes,
          AuthStatuses,
          Studies,
          Subjects,
          ClientIPs,
          AccessTimes
    '''
    queryFrequency: 'PT30M'
    queryPeriod: 'PT2H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Collection'
      'Exfiltration'
      'PrivilegeEscalation'
    ]
    techniques: [
      'T1530' // Data from Cloud Storage
      'T1213' // Data from Information Repositories
      'T1078' // Valid Accounts
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
        entityType: 'IP'
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'ClientIPs'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'PHI Access Alert: {{UserName}} - {{AccessCount}} suspicious accesses'
      alertDescriptionFormat: 'Potentially unauthorized access to patient data. User {{UserName}} ({{UserRole}}) performed {{AccessCount}} suspicious accesses to clinical data from {{UserLocation}} with access types {{AccessTypes}}'
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
    customDetails: {
      Role: 'UserRole'
      Location: 'UserLocation'
      Studies: 'Studies'
      AccessStatus: 'AuthStatuses'
      AccessTimes: 'AccessTimes'
    }
  }
}

// Additional rules would follow the same enhanced pattern

// Output rule IDs for reference
output elnMassDownloadRuleId string = elnMassDownloadRule.id
output phiAccessRuleId string = phiAccessRule.id
