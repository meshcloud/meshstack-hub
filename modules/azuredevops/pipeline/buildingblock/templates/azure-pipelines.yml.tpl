pool: ${agent_pool_name}

trigger:
  - main

steps:
  - task: Kubernetes@1
    displayName: 'Create namespace from repo name'
    inputs:
      connectionType: 'Azure Resource Manager'
      azureSubscriptionEndpoint: '${service_connection_name}'
      azureResourceGroup: '$(AKS_RESOURCE_GROUP)'
      kubernetesCluster: '$(AKS_CLUSTER_NAME)'
      command: 'apply'
      useConfigurationFile: true
      configurationType: 'inline'
      inline: |
        apiVersion: v1
        kind: Namespace
        metadata:
          name: ${repository_name}
