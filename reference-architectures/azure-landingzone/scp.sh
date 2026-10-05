PARENT_MG="flo-test-ref-arch"   # the hierarchy is created under this
SP_NAME="flo-azure-landingzone-deployer"

# Create the service principal and grant it Owner on the parent management group in one step.
SP=$(az ad sp create-for-rbac --name "$SP_NAME" \
  --role Owner \
  --scopes "/providers/Microsoft.Management/managementGroups/$PARENT_MG" -o json)
echo "$SP"   # appId = client id, password = client secret, tenant = tenant id

# Grant the three Microsoft Graph app roles the run needs, resolving every id from $SP so there is
# nothing to copy-paste (Application.ReadWrite.All, Directory.Read.All, AppRoleAssignment.ReadWrite.All).
SP_OID=$(az ad sp show --id "$(echo "$SP" | jq -r .appId)" --query id -o tsv)
GRAPH_OID=$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id -o tsv)
for ROLE in 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9 \
            7ab1d382-f21e-4acd-a863-ba3e13f7da61 \
            06b708a9-e830-4db3-a914-8e69da51d44f; do
  az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OID/appRoleAssignments" \
    --body "{\"principalId\":\"$SP_OID\",\"resourceId\":\"$GRAPH_OID\",\"appRoleId\":\"$ROLE\"}"
done
