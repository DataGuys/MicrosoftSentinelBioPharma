// Example policy to enforce regulatory tagging
resource compliancePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${prefix}-policy-compliance-tagging'
  properties: {
    policyType: 'Custom'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        field: 'type',
        equals: 'Microsoft.OperationalInsights/workspaces'
      },
      then: {
        effect: 'audit',
        details: {
          requiredTags: ['complianceFrameworks']
        }
      }
    }
  }
}
