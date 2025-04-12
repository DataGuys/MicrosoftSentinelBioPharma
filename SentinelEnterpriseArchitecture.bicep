// Bio-Pharma Specialized Workspaces Module - Improved Architecture
// Deploys Sentinel and specialized workspaces for bio-pharmaceutical organizations

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

@description('Default retention days for Log Analytics Workspaces')
param defaultRetentionDays int = 2557  // 7 years for 21 CFR Part 11 compliance

@description('Retention days for research data workspace')
param researchRetentionDays int = 2557

@description('Retention days for manufacturing data workspace')
param manufacturingRetentionDays int = 2557

@description('Retention days for clinical data workspace')
param clinicalRetentionDays int = 2557

@description('Pricing tier for the central Sentinel workspace')
@allowed([
  'CapacityReservation'
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param sentinelWorkspaceSku string = 'PerGB2018'

@description('Pricing tier for the specialized workspaces')
param specializedWorkspaceSku string = 'PerGB2018' // Changed from Basic to PerGB2018 for better feature support

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

// Variables - improved naming convention
var resourceNames = {
  sentinelWorkspace: '${prefix}-${environment}-sentinel-ws'
  researchWorkspace: '${prefix}-${environment}-research-ws'
  manufacturingWorkspace: '${prefix}-${environment}-manufacturing-ws'
  clinicalWorkspace: '${prefix}-${environment}-clinical-ws'
  laCluster: '${prefix}-${environment}-la-cluster'
  queryPack: '${prefix}-${environment}-biopharma-queries'
}

// Improved tags that include standardized metadata
var resourceTags = union(tags, {
  'environment': environment
  'application': 'Microsoft Sentinel'
  'business-unit': 'Security'
  'deployment-date': utcNow('yyyy-MM-dd')
})

// --------------------- LOG ANALYTICS CLUSTER (OPTIONAL) -----------------------

// Log Analytics Cluster for high-volume bio-pharma environments
resource laCluster 'Microsoft.OperationalInsights/clusters@2021-06-01' = if (useLogAnalyticsCluster) {
  name: resourceNames.laCluster
  location: location
  tags: resourceTags
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
  name: resourceNames.sentinelWorkspace
  location: location
  tags: union(resourceTags, {
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
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for compliance
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// 2. Research Workspace for intellectual property protection
resource researchWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: resourceNames.researchWorkspace
  location: location
  tags: union(resourceTags, {
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
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for IP traceability
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// 3. Manufacturing Workspace for GxP systems
resource manufacturingWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: resourceNames.manufacturingWorkspace
  location: location
  tags: union(resourceTags, {
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
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for audit trails
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// 4. Clinical Workspace for clinical trial and patient data
resource clinicalWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: resourceNames.clinicalWorkspace
  location: location
  tags: union(resourceTags, {
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
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for PII/PHI compliance
    }
    clusterResourceId: useLogAnalyticsCluster ? laCluster.id : null
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
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
  name: resourceNames.queryPack
  location: location
  tags: resourceTags
  properties: {
    displayName: 'Bio-Pharma Global Operations Queries'
    description: 'Cross-workspace queries for bio-pharmaceutical security operations'
  }
}

// Added cross-workspace query examples
module queryPackItems 'modules/queryPackItems.bicep' = {
  name: 'bioPharmaQueryPackItems'
  params: {
    queryPackName: bioPharmaQueryPack.name
    researchWorkspaceName: researchWorkspace.name
    manufacturingWorkspaceName: manufacturingWorkspace.name
    clinicalWorkspaceName: clinicalWorkspace.name
  }
}

// Diagnostic settings for monitoring the Sentinel workspaces
resource sentinelDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sentinelWorkspace
  name: '${resourceNames.sentinelWorkspace}-diagnostics'
  properties: {
    workspaceId: sentinelWorkspace.id
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          days: 365
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 365
          enabled: true
        }
      }
    ]
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
