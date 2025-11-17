# Azure Virtual Machine Starterkit Backplane

There is no terraform for starterkit backplane.

You need to manually create an API Key in meshStack and fill in the variables in the imported definition.

## How to create an API Key

> **Note**: you need to have Organization Admin permission in meshStack to create an API Key with admin rights.

1. In the Admin Area, go to "Access Control" > "API Keys"
2. Create a new API Key with the required permissions for managing:
   - Projects
   - Tenants
   - Building Blocks
3. Copy the key ID to MESHSTACK_API_KEY and secret to MESHSTACK_API_SECRET

## Required Building Block Definitions

This starterkit requires the following building block definition to be configured in your meshStack:

1. **Azure Virtual Machine Building Block**: The actual VM provisioning building block
   - Ensure it's configured to work with your Azure platform
   - Note the definition version UUID for the starterkit configuration

## Configuration

When configuring the starterkit as a building block definition in meshStack:

1. Set the appropriate platform support (Azure)
2. Configure all required input variables
3. Link to the correct Azure VM building block definition
