// Bio-Pharma Specialized Workspaces Module
// Deploys Sentinel and specialized workspaces for bio-pharmaceutical organizations

@description('The location for all resources')
param location string

@description('Prefix to use for resource naming')
param prefix string

@description('Tags to apply to all resources')
param tags object

@description('Default retention days for Log Analytics Workspaces')
param defaultRetentionDays int = 2557  // 7 years for 21 CFR Part 11 compliance

@description('Retention days for research data workspace')
param researchRetentionDays int = 2557

@description('Retention days for manufacturing data workspace')
param manufacturingRetentionDays int = 2557

@description('Retention days for clinical data workspace')
param clinicalRetentionDays int = 2557

@description('Pricing tier for the central Sentinel workspace')
param sentinelWorkspaceSku string = 'PerGB2018'

@description('Pricing tier for the specialized workspaces')
param specializedWorkspaceSku string = 'Basic' // Cost-saving tier for high-volume data

@description('Flag to deploy a Log Analytics Cluster instead of regular workspaces')
param useLogAnalyticsCluster bool = false

@description('Capacity reservation in GB per day for the Log Analytics Cluster')
param laClusterCapacityReservationGB int = 2000

@description('Enable Customer-Managed Keys for encryption')
param enableCustomerManagedKey bool = false

@description('Key Vault ID containing the encryption key')
param keyVaultId string = ''

@description('Key name in the Key Vault')
param keyName string = ''

@description('Key version in the Key Vault')
param keyVersion string = ''

// Variables
var sentinelWorkspaceName = '${prefix}-sentinel-ws'
var researchWorkspaceName = '${prefix}-research-ws'
var manufacturingWorkspaceName = '${prefix}-manufacturing-ws'
var clinicalWorkspaceName = '${prefix}-clinical-ws'

// --------------------- LOG ANALYTICS CLUSTER (OPTIONAL) -----------------------

// Log Analytics Cluster for high-volume bio-pharma environments
resource laCluster 'Microsoft.OperationalInsights/clusters@2021-06-01' = if (useLogAnalyticsCluster) {
  name: '${prefix}-la-cluster'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'CapacityReservation'
      capacity: laClusterCapacityReservationGB
    }
    keyVaultProperties: enableCustomerManagedKey ? {
      keyVaultUri: keyVaultId
      keyName: keyName
      keyVersion: keyVersion
    } : null
  }
}

// --------------------- WORKSPACES -----------------------

// 1. Central Sentinel Workspace for Global Security Operations
resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: sentinelWorkspaceName
  location: location
  tags: union(tags, {
    'workspaceType': 'Global-SOC'
    'dataClassification': 'Confidential'
    'complianceFrameworks': 'GDPR,HIPAA,21CFR11,SOX'
  })
  properties: {
    sku: {
      name: useLogAnalyticsCluster ? 'LACluster' : sentinelWorkspaceSku
    }
    retentionInDays: defaultRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for compliance
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
  }
}

// 2. Research Workspace for intellectual property protection
resource researchWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: researchWorkspaceName
  location: location
  tags: union(tags, {
    'workspaceType': 'Research'
    'dataClassification': 'Highly-Confidential'
    'complianceFrameworks': 'IP-Protection,SOX'
    'dataType': 'Intellectual-Property'
  })
  properties: {
    sku: {
      name: useLogAnalyticsCluster ? 'LACluster' : specializedWorkspaceSku
    }
    retentionInDays: researchRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for compliance and IP protection
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
  }
}

// 3. Manufacturing Workspace for GxP systems
resource manufacturingWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: manufacturingWorkspaceName
  location: location
  tags: union(tags, {
    'workspaceType': 'Manufacturing'
    'dataClassification': 'Confidential'
    'complianceFrameworks': '21CFR11,GxP,SOX'
    'dataType': 'Manufacturing-Systems'
  })
  properties: {
    sku: {
      name: useLogAnalyticsCluster ? 'LACluster' : specializedWorkspaceSku
    }
    retentionInDays: manufacturingRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for 21 CFR Part 11 compliance
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
  }
}

// 4. Clinical Workspace for clinical trial and patient data
resource clinicalWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: clinicalWorkspaceName
  location: location
  tags: union(tags, {
    'workspaceType': 'Clinical'
    'dataClassification': 'Protected-Health-Information'
    'complianceFrameworks': 'HIPAA,GDPR,21CFR11'
    'dataType': 'Clinical-Trial-Data'
  })
  properties: {
    sku: {
      name: useLogAnalyticsCluster ? 'LACluster' : specializedWorkspaceSku
    }
    retentionInDays: clinicalRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for compliance
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
  }
}

// Enable Microsoft Sentinel on the central workspace
resource enableSentinel 'Microsoft.SecurityInsights/onboardingStates@2023-05-01' = {
  scope: sentinelWorkspace
  name: 'default'
  properties: {}
}

// Deploy cross-workspace query pack for bio-pharma global operations
resource bioPharmaQueryPack 'Microsoft.OperationalInsights/queryPacks@2019-09-01' = {
  name: '${prefix}-biopharma-queries'
  location: location
  tags: tags
  properties: {
    displayName: 'Bio-Pharma Global Operations Queries'
    description: 'Cross-workspace queries for bio-pharmaceutical security operations'
  }
}

// Add bio-pharma specific queries to query pack
resource crossWorkspaceIPQuery 'Microsoft.OperationalInsights/queryPacks/queries@2019-09-01' = {
  parent: bioPharmaQueryPack
  name: guid('ip-protection-cross-workspace')
  properties: {
    displayName: 'Cross-Workspace Intellectual Property Protection Query'
    description: 'Monitors IP access across all workspaces'
    body: '''
      // Research system access data
      let researchData = workspace("${researchWorkspaceName}").Custom-ELN_CL
      | where TimeGenerated > ago(7d)
      | where RawData has_any ("Access", "Download", "Export", "Print")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend DataClassification = extract("Classification[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | where DataClassification has_any ("IP", "Research", "Formula", "Confidential", "Restricted")
      | project TimeGenerated, UserName, ResourceName, DataClassification, Source="Research";
      
      // Sentinel security events
      let sentinelData = SigninLogs
      | where TimeGenerated > ago(7d)
      | project TimeGenerated, UserName=UserPrincipalName, IPAddress, Location, ResultType, Source="Sentinel";
      
      // Manufacturing system access (for formula access)
      let manufacturingData = workspace("${manufacturingWorkspaceName}").Custom-MES_CL
      | where TimeGenerated > ago(7d)
      | where RawData has_any ("Recipe", "Formula", "Access")
      | extend UserName = extract("User[:\\s]+([\\w\\-\\.@]+)", 1, RawData)
      | extend ResourceName = extract("Resource[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | project TimeGenerated, UserName, ResourceName, Source="Manufacturing";
      
      // Combine and analyze
      researchData
      | union sentinelData, manufacturingData
      | order by UserName asc, TimeGenerated asc
    '''
    tags: {
      'purpose': 'IP-Protection'
      'coverage': 'Global'
      'criticality': 'High'
    }
  }
}

resource crossWorkspaceGxPQuery 'Microsoft.OperationalInsights/queryPacks/queries@2019-09-01' = {
  parent: bioPharmaQueryPack
  name: guid('gxp-compliance-cross-workspace')
  properties: {
    displayName: 'Cross-Workspace GxP Compliance Validation'
    description: 'Confirms GxP system integrity across all workspaces'
    body: '''
      // Manufacturing GxP system validation status
      let gxpStatus = workspace("${manufacturingWorkspaceName}").Custom-InstrumentQual_CL
      | where TimeGenerated > ago(30d)
      | where RawData has_any ("Validation", "Qualification", "Status")
      | extend SystemName = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ValidationStatus = extract("ValidationStatus[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | project TimeGenerated, SystemName, ValidationStatus, Source="Manufacturing";
      
      // Sentinel security events for GxP systems
      let sentinelGxPEvents = SecurityEvent
      | where TimeGenerated > ago(30d)
      | where Computer has_any ("GxP", "MES", "LIMS", "QMS")
      | project TimeGenerated, Computer, Account, EventID, Activity, Source="Sentinel";
      
      // Clinical system validation events
      let clinicalValidation = workspace("${clinicalWorkspaceName}").Custom-CTMS_CL
      | where TimeGenerated > ago(30d)
      | where RawData has_any ("Validation", "21CFR11", "Compliance")
      | extend SystemName = extract("System[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | extend ComplianceStatus = extract("ComplianceStatus[:\\s]+([\\w\\-\\.]+)", 1, RawData)
      | project TimeGenerated, SystemName, ComplianceStatus, Source="Clinical";
      
      // Combine for compliance overview
      gxpStatus
      | union sentinelGxPEvents, clinicalValidation
      | order by TimeGenerated desc
    '''
    tags: {
      'purpose': 'GxP-Compliance'
      'coverage': 'Global'
      'criticality': 'High'
      'regulation': '21CFR11'
    }
  }
}

// Output workspace IDs and names for reference
output sentinelWorkspaceId string = sentinelWorkspace.id
output researchWorkspaceId string = researchWorkspace.id
output manufacturingWorkspaceId string = manufacturingWorkspace.id
output clinicalWorkspaceId string = clinicalWorkspace.id

output sentinelWorkspaceName string = sentinelWorkspace.name
output researchWorkspaceName string = researchWorkspace.name
output manufacturingWorkspaceName string = manufacturingWorkspace.name
output clinicalWorkspaceName string = clinicalWorkspace.name

output laClusterId string = useLogAnalyticsCluster ? laCluster.id : 'Not deployed'
output queryPackId string = bioPharmaQueryPack.id
