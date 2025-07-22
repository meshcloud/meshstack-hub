# Agentic Coding Sandbox Backplane

This building block is a composition of the following components:
- [AWS Bedrock LZ](./landingzone/README.md): A landing zone for using AWS Bedrock in sandboxed to access LLM models for developers.
- [AWS Budget Alert Building Block](https://hub.meshcloud.io/definitions/aws-budget-alert)
- [AWS Enable Opt-In Region Building Block](https://hub.meshcloud.io/definitions/aws-opt-in-region)

As a composition, this building block does not need any dedicated backplane except a meshObject API Key with appropriate permissions to manage meshProjects, meshTenants and meshBuildingBlocks in the users workspace.