# AKS Starterkit Backplane

There is no terraform for starterkit backplane.

You need to manually create an API Key in meshStack and fill in the variables in the imported definition.

## How to create an API Key

1. In meshStack, go to your workspace
2. Navigate to "Access Management" > "API Keys"
3. Create a new API Key with the following permissions:
![alt text](permissions.png)
4. Copy the key ID to MESHSTACK_API_KEY and secret to MESHSTACK_API_SECRET
5. Set the MESHSTACK_ENDPOINT to your meshStack API endpoint, e.g., `https://api.<your-meshstack-domain>`
