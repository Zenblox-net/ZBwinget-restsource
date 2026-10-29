// -----------------------------------------------------------------------
// <copyright file="AzureFunctionEnvironment.cs" company="Microsoft Corporation">
//     Copyright (c) Microsoft Corporation. Licensed under the MIT License.
// </copyright>
// -----------------------------------------------------------------------

namespace Microsoft.WinGet.RestSource.Functions.Constants
{
    using System;

    /// <summary>
    /// Environment Variables used by Azure Functions.
    /// </summary>
    public class AzureFunctionEnvironment
    {
        /// <summary>
        /// App Insights Instrumentation Key Variable.
        /// </summary>
        private const string AppInsightsInstrumentationKeyVariable = "APPINSIGHTS_INSTRUMENTATIONKEY";

        /// <summary>
        /// Monitor Metrics Account Variable.
        /// </summary>
        private const string MonitorMetricsAccountVariable = "WinGetRest__Telemetry__Metrics";

        /// <summary>
        /// Monitor Role Variable.
        /// </summary>
        private const string MonitorRoleVariable = "WinGetRest__Telemetry__Role";

        /// <summary>
        /// Monitor Tenant Variable.
        /// </summary>
        private const string MonitorTenantVariable = "WinGetRest__Telemetry__Tenant";

        /// <summary>
        /// Server Identifier Variable.
        /// </summary>
        private const string ServerIdentifierVariable = "ServerIdentifier";

        /// <summary>
        /// Gets AppInsights Instrumentation key.
        /// </summary>
        public static string AppInsightsInstrumentationKey => Environment.GetEnvironmentVariable(AppInsightsInstrumentationKeyVariable);

        /// <summary>
        /// Gets Geneva Monitoring Account.
        /// </summary>
        public static string MonitoringAccount => Environment.GetEnvironmentVariable(MonitorMetricsAccountVariable);

        /// <summary>
        /// Gets Telemetry Role.
        /// </summary>
        public static string MonitorRole => Environment.GetEnvironmentVariable(MonitorRoleVariable);

        /// <summary>
        /// Gets Telemetry Tenant.
        /// </summary>
        public static string MonitorTenant => Environment.GetEnvironmentVariable(MonitorTenantVariable);

        /// <summary>
        /// Gets Telemetry Tenant.
        /// </summary>
        public static string ServerIdentifier => Environment.GetEnvironmentVariable(ServerIdentifierVariable);
    }
}