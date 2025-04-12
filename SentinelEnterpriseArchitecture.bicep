// Bio-Pharma Specialized Workspaces Module - Simplified Version
// Deploys Sentinel and specialized workspaces with standard configurations

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

@description('Deployment timestamp')
param deploymentTimestamp string = utcNow('yyyy-MM-dd')

@description('Default retention days for Log Analytics Workspaces')
param defaultRetentionDays int = 30  // Default retention for free and PerGB2018 SKUs

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
param specializedWorkspaceSku string = 'PerGB2018'

// Variables - improved naming convention
var resourceNames = {
  sentinelWorkspace: '${prefix}-${environment}-sentinel-ws'
  researchWorkspace: '${prefix}-${environment}-research-ws'
  manufacturingWorkspace: '${prefix}-${environment}-manufacturing-ws'
  clinicalWorkspace: '${prefix}-${environment}-clinical-ws'
  queryPack: '${prefix}-${environment}-biopharma-queries'
}

// Improved tags that include standardized metadata
var standardTags = {
  environment: environment
  application: 'Microsoft Sentinel'
  'business-unit': 'Security'
  'deployment-date': deploymentTimestamp
}

// Combine standard tags with provided tags
var mergedTags = union(tags, standardTags)

// --------------------- WORKSPACES -----------------------

// 1. Central Sentinel Workspace for Global Security Operations
resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: resourceNames.sentinelWorkspace
  location: location
  tags: union(mergedTags, {
    workspaceType: 'Global-SOC'
    dataClassification: 'Confidential'
    complianceFrameworks: 'GDPR,HIPAA,21CFR11,SOX'
  })
  properties: {
    sku: {
      name: sentinelWorkspaceSku
    }
    retentionInDays: defaultRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for compliance
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for compliance
    }
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
  tags: union(mergedTags, {
    workspaceType: 'Research'
    dataClassification: 'Highly-Confidential'
    complianceFrameworks: 'IP-Protection,SOX'
    dataType: 'Intellectual-Property'
  })
  properties: {
    sku: {
      name: specializedWorkspaceSku
    }
    retentionInDays: defaultRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for compliance and IP protection
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for IP traceability
    }
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
  tags: union(mergedTags, {
    workspaceType: 'Manufacturing'
    dataClassification: 'Confidential'
    complianceFrameworks: '21CFR11,GxP,SOX'
    dataType: 'Manufacturing-Systems'
  })
  properties: {
    sku: {
      name: specializedWorkspaceSku
    }
    retentionInDays: defaultRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for 21 CFR Part 11 compliance
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for audit trails
    }
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
  tags: union(mergedTags, {
    workspaceType: 'Clinical'
    dataClassification: 'Protected-Health-Information'
    complianceFrameworks: 'HIPAA,GDPR,21CFR11'
    dataType: 'Clinical-Trial-Data'
  })
  properties: {
    sku: {
      name: specializedWorkspaceSku
    }
    retentionInDays: defaultRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false // Disabled for compliance
      disableLocalAuth: true // Enhanced security - require AAD auth
      enableDataExport: true // Enable data export capability for PII/PHI compliance
    }
    workspaceCapping: {
      dailyQuotaGb: -1 // Unlimited
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Create a query pack for specialized bio-pharma queries
resource bioPharmaQueries 'Microsoft.OperationalInsights/queryPacks@2019-09-01' = {
  name: resourceNames.queryPack
  location: location
  tags: mergedTags
  properties: {}
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

output queryPackId string = bioPharmaQueries.id
