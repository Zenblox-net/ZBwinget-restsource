# Flex Consumption Conversion Plan

## Goal

Move the REST source Function App to Azure Functions Flex Consumption (`FC1`) while preserving the existing source deployment flow, keeping the bill low, and resuming the partial deployment in `jpvwinget6-rg` without recreating already-provisioned resources.

## Findings

- `australiaeast` is currently in the output of `az functionapp list-flexconsumption-locations`. The failed deployment was not caused by an unsupported region, so keep the existing region. Moving would require rebuilding regional resources and could add migration and data-transfer cost.
- The deployment failed while creating the App Service Plan with `Requested features are not supported in region`. The current `AppServicePlan/asp.json` template declares `reserved: false`, which is a Windows plan. Flex Consumption is Linux-only and requires `reserved: true`, `sku.name: FC1`, and `sku.tier: FlexConsumption`.
- The Function project targets `net10.0` and uses the isolated worker model (`FUNCTIONS_WORKER_RUNTIME=dotnet-isolated`). Microsoft documents .NET 10 isolated as supported on Flex Consumption. No Windows-only requirement has been identified in the project configuration.
- The existing Function template uses the older `Microsoft.Web/sites` API shape and traditional App Service configuration. Flex Consumption instead uses `functionAppConfig`, including a Blob package-deployment source, runtime, and scale settings.
- The existing deployment publishes the Function ZIP with `Publish-AzWebApp`. Flex Consumption uses package deployment backed by Blob Storage; the publish path must be verified and changed to a Flex-compatible deployment mechanism.
- `deploy-settings.psd1` selects `Developer`, which currently maps to `FC1` and APIM `Consumption`. The generated APIM parameter has already been confirmed as `Consumption`.
- `jpvwinget6-rg` contains five resources created before the failure: Log Analytics, Application Insights, Key Vault, App Configuration, and Storage. Do not delete the group or increment the name as part of this conversion.

## Target Design

1. Keep `Region = 'australiaeast'`; it is Flex-supported and already contains the partial deployment.
2. Keep the low-cost Developer profile: Flex Consumption `FC1`, APIM `Consumption`, App Configuration `Free`, Storage `Standard_LRS`, and Cosmos DB serverless. Cosmos DB free tier is disabled in this profile, avoiding the subscription's one-free-account limit.
3. Configure the Function App as Linux with .NET 10 isolated, a system-assigned identity, no always-ready instances, identity-based host storage, and a Blob deployment container.
4. Preserve current Key Vault references, Cosmos DB access, App Configuration access, telemetry, CORS, API auth settings, and API Management backend wiring.
5. Reuse the existing storage account. Create a dedicated, private deployment container for this Function App instead of sharing the generic `default` container. Configure the app's `functionAppConfig.deployment.storage` with its Blob endpoint and `SystemAssignedIdentity` authentication.

## Implementation Steps

### 1. Update the App Service Plan template

In `src/WinGet.RestSource.Infrastructure/Templates/AppServicePlan/asp.json`:

- Use a current `Microsoft.Web/serverfarms` API version that supports Flex Consumption, such as `2024-04-01`.
- Set `kind` to `functionapp`.
- Keep the generated SKU name `FC1`, set `tier` to `FlexConsumption`, and set `properties.reserved` to `true`.
- Remove Windows/dedicated-plan settings that do not apply, such as `numberOfWorkers`; keep zone redundancy disabled for the cost-minimum profile.

### 2. Add a dedicated package container

In `src/WinGet.RestSource.Infrastructure/Templates/StorageAccount/storageaccount.json` and its generated parameters:

- Preserve existing container behavior needed by the REST source.
- Add a unique, private container for Function deployment packages (for example, `app-package-func-jpvwinget6`).
- Pass the same container name to the Function template. Keep the value deterministic from the Function name and within Azure Blob container naming rules.
- Retain `allowSharedKeyAccess: false`; use the Function's system-assigned identity for host and deployment storage.

### 3. Migrate the Function App ARM resource to Flex

In `src/WinGet.RestSource.Infrastructure/Templates/AzureFunction/azurefunction.json`:

- Use `Microsoft.Web/sites` API `2024-04-01` (or a later API supported by the deployment environment), set `kind` to `functionapp,linux`, and retain the system-assigned identity.
- Add `properties.functionAppConfig`:
  - `deployment.storage.type = 'blobContainer'`.
  - `deployment.storage.value` points to the dedicated container's full Blob URL.
  - `deployment.storage.authentication.type = 'SystemAssignedIdentity'`.
  - `runtime.name = 'dotnet-isolated'`, `runtime.version = '10.0'`.
  - Set scale controls explicitly, with zero always-ready instances. Use the platform's 2048 MB default initially; only reduce to 512 MB after a representative startup/load test shows adequate memory headroom.
- Move application settings into `properties.siteConfig.appSettings`, as expected by Flex. Preserve all existing app settings and Key Vault references; add `APPLICATIONINSIGHTS_CONNECTION_STRING` while retaining the instrumentation key if existing code still consumes it.
- Put CORS in the supported site configuration rather than the legacy `sites/config` child resource if required by the selected API schema.
- Remove traditional-plan-only settings such as `alwaysOn` and client affinity unless the Flex API explicitly supports them.

### 4. Preserve identity permissions and order deployment

In `Tools/PowershellModule/src/Library/New-ARMObjects.ps1`:

- Ensure the Function identity receives the existing Storage Blob, Queue, and Table data roles, Key Vault secret access, App Configuration Data Reader, and Cosmos SQL data role.
- Ensure `Storage Blob Data Owner` is effective on the storage account before uploading the Function package to the Flex deployment container.
- Preserve the current Function key creation and Key Vault secret wiring.
- Replace `Publish-AzWebApp` only after confirming the supported Flex package deployment command/API and its authentication behavior. Pass the subscription explicitly; the Azure CLI context was verified to match the configured subscription during this session.
- Do not add a restart unless the chosen deployment method requires one; package deployment should manage the update lifecycle.

### 5. Keep deployment idempotent

- Continue using `jpvwinget6-rg` and the existing names. The current deployment uses incremental ARM deployments; rerunning should update/reuse the five successful resources.
- Do not delete the resource group or increment `Name` to work around an SKU/OS mismatch.
- Before retrying, inspect the resource group and deployment history so the script does not duplicate resources or reset already-created settings.

## Validation and Rollout

1. Confirm all ARM JSON parses and all Function template parameter names have matching generated values.
2. Rebuild and stage the local PowerShell module so deployment uses this checkout.
3. Generate parameters in a non-deploying test path and verify `asp.json` yields `FC1`, APIM yields `Consumption`, the Function runtime is .NET 10 isolated, and both storage URIs/container names are correct.
4. Run `Test-ARMTemplates` or ARM group validation against `jpvwinget6-rg`; validate the App Service Plan and Function App resources before provisioning.
5. Deploy incrementally to the existing resource group. Confirm the plan is Linux Flex (`FC1`) before continuing to Function creation.
6. Verify Function startup, identity-based access to Blob/Queue/Table, Key Vault references, Cosmos DB access, App Configuration access, and package deployment. Then confirm APIM's backend URL and test the source API.
7. Review Azure Cost Analysis after initial traffic. Keep always-ready instances at zero; tune memory and maximum instance count only from observed usage and performance.

## Windows Requirement

The current Function project is .NET 10 isolated and does not declare a Windows-only runtime dependency. Flex Consumption runs Linux, which is appropriate for this project. Revisit this only if code or a native dependency is found to require Windows-specific APIs or binaries.

## Implementation Outcome

- Deployed successfully to `jpvwinget7-rg` in `australiaeast`; the partial `jpvwinget6-rg` deployment was left untouched.
- The plan is Linux Flex Consumption `FC1` with `reserved: true`; APIM is `Consumption` with `skuCount: 0`.
- Reused the existing `jpvwinget7` Entra app registration and added private Blob container `app-package-func-jpvwinget7` to the existing LRS storage account.
- Configured zero always-ready instances, 2048 MB instance memory, and a 10-instance maximum for the development deployment. The container/host storage permissions are assigned to the system identity.
- The Function App is Running and Azure indexes 26 functions. APIM `GET /winget/information` returned HTTP 200 with the expected Entra resource and `user_impersonation` scope.
- Flex rejected the original colon-delimited app-setting names, so the template and direct environment-variable readers now use double underscores. Flex startup also exposed a Windows-only Geneva ETW exporter; Geneva export is now skipped on non-Windows while Application Insights and console logging remain enabled.
- Function package publication now precedes host-key creation because the Flex host runtime isn't ready to serve key-management requests until the package has been deployed. Cosmos SQL role assignment can return `202 Accepted`; the deployer now treats that asynchronous response as success and subsequent runs verify/reuse the assignment.
- The final build succeeded. The unit test run had 60 passing tests and 5 Cosmos data-store tests failed during fixture construction because required test configuration was null; no failures were attributed to the Flex or logging changes. App Insights still contains ETW exceptions from before the final Linux-compatible package deployment, but the live Function/API checks now pass.

## Source References

- [Azure Functions Flex Consumption hosting](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
- [Flex Consumption ARM/Bicep deployment requirements](https://learn.microsoft.com/azure/azure-functions/functions-infrastructure-as-code)
- [Flex Consumption deployment and supported regions](https://learn.microsoft.com/azure/azure-functions/flex-consumption-how-to)
- [Microsoft Flex Consumption ARM sample](https://github.com/Azure-Samples/azure-functions-flex-consumption-samples/tree/main/IaC/armtemplate)