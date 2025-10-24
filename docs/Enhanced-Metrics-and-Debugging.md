# Enhanced Metrics and Debugging Support for Azure CaC

This document describes the enhanced metrics and debugging capabilities added to the Azure Compliance as Code (CaC) solution to improve operational visibility and troubleshooting.

## Overview

The enhanced metrics and debugging support provides comprehensive insights into:
- Module execution performance and timing
- Error tracking and troubleshooting information
- Automation account configuration validation
- Resource processing metrics
- Permission verification results

## Features

### 1. Runtime Metrics Collection
- **Module Execution Times**: Tracks how long each guardrail module takes to execute
- **Resource Processing Counts**: Monitors how many resources each module processes
- **API Call Tracking**: Counts Microsoft Graph API calls per module
- **Memory Usage**: Tracks memory utilization patterns

### 2. Enhanced Error Tracking
- **Detailed Error Logging**: Captures full error context with stack traces
- **Error Categorization**: Classifies errors by type (permission, API, configuration)
- **Module Failure Analysis**: Tracks which modules fail and why
- **Warning Collection**: Captures non-fatal warnings for analysis

### 3. Configuration Validation
- **Automation Variables**: Logs all non-sensitive automation account variables
- **Permission Verification**: Tests required permissions for each service
- **Environment Information**: Captures PowerShell version, Azure module versions
- **Tenant and Subscription Context**: Tracks execution context

### 4. Performance Analytics
- **Execution Trends**: Historical performance data over time
- **Performance Baselines**: Identifies unusual execution patterns
- **Resource Utilization**: Tracks resource consumption per module
- **Bottleneck Identification**: Highlights slow-running modules

## Configuration

### Enabling Debug Collection

Debug metrics collection is **disabled by default** to ensure no impact on existing deployments. To enable it:

1. **Via Automation Account Variable**:
   ```powershell
   New-AzAutomationVariable -AutomationAccountName "your-automation-account" `
     -ResourceGroupName "your-resource-group" `
     -Name "EnableDebugMetrics" `
     -Value "true" `
     -Encrypted $false
   ```

2. **Via ARM Template** (add to your deployment):
   ```json
   {
     "type": "Microsoft.Automation/automationAccounts/variables",
     "apiVersion": "2020-01-13-preview",
     "name": "[concat(parameters('automationAccountName'), '/EnableDebugMetrics')]",
     "properties": {
       "value": "\"true\"",
       "isEncrypted": false
     }
   }
   ```

### Configuration Options

| Variable Name | Description | Default | Values |
|---------------|-------------|---------|--------|
| `EnableDebugMetrics` | Master switch for debug collection | `false` | `true`, `false` |

## Data Schema

### GuardrailsDebugMetrics_CL Table

The debug data is stored in a dedicated Log Analytics table with the following key fields:

| Field | Type | Description |
|-------|------|-------------|
| `ReportTime_s` | string | Report timestamp matching main compliance data |
| `ModuleName_s` | string | Name of the executed module |
| `ControlName_s` | string | Guardrail control name (e.g., "Guardrails1") |
| `ExecutionTimeMs_d` | double | Module execution time in milliseconds |
| `ExecutionTimeSeconds_d` | double | Module execution time in seconds |
| `ErrorCount_d` | double | Number of errors encountered |
| `WarningCount_d` | double | Number of warnings encountered |
| `GraphApiCalls_d` | double | Number of Microsoft Graph API calls made |
| `ResourcesProcessed_d` | double | Number of resources processed |
| `ComplianceStatus_s` | string | Module compliance result status |
| `TenantId_g` | guid | Azure AD tenant ID |
| `SubscriptionId_g` | guid | Azure subscription ID |
| `PowerShellVersion_s` | string | PowerShell version used |
| `Errors_s` | string | JSON array of error messages |
| `Warnings_s` | string | JSON array of warning messages |

### Additional Fields by Module Type

Different modules may include additional fields:
- `UsersProcessed_d`: Number of users processed (identity modules)
- `PoliciesEvaluated_d`: Number of policies evaluated (policy modules)
- `StorageAccountsChecked_d`: Number of storage accounts checked
- `PermissionTestResults_s`: Results of permission validation tests

## Dashboard and Visualization

### Azure Workbook Template

A pre-built Azure Workbook template is provided at `/tools/debug-dashboard-workbook.json` with:

1. **Executive Summary**
   - Overall execution status
   - Total modules processed
   - Success/failure rates
   - Performance metrics

2. **Module Performance Analysis**
   - Execution time trends
   - Performance comparisons
   - Slowest running modules
   - Resource utilization patterns

3. **Error Analysis**
   - Recent errors by module
   - Error trends over time
   - Error categorization
   - Common failure patterns

4. **Configuration Overview**
   - Automation account settings
   - Environment information
   - Permission validation results
   - Module configuration details

5. **Troubleshooting Queries**
   - Pre-built KQL queries for common issues
   - Performance investigation queries
   - Error investigation helpers

### Importing the Dashboard

1. Navigate to Azure Monitor > Workbooks
2. Click "New" > "Advanced Editor"
3. Copy the contents of `/tools/debug-dashboard-workbook.json`
4. Paste into the Gallery Template tab
5. Click "Apply" and save the workbook

## Common Troubleshooting Scenarios

### 1. Module Taking Too Long (Timeout Issues)

**Query to identify slow modules:**
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(24h)
| where ExecutionTimeSeconds_d > 300  // Modules taking > 5 minutes
| summarize MaxTime = max(ExecutionTimeSeconds_d), AvgTime = avg(ExecutionTimeSeconds_d), Count = count() by ModuleName_s
| order by MaxTime desc
```

**Analysis:**
- Check `GraphApiCalls_d` for excessive API usage
- Review `ResourcesProcessed_d` for large datasets
- Look at `Errors_s` for retry loops
- Examine automation account resource limits

### 2. Module Failures with No Results in Logs

**Query to find modules with execution failures:**
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(24h)
| where ErrorCount_d > 0 or FailureReason_s == "ModuleExecutionFailure"
| project TimeGenerated, ModuleName_s, ErrorDetails_s, Errors_s, FailureReason_s
| order by TimeGenerated desc
```

**Analysis:**
- Check `ErrorDetails_s` for specific error messages
- Verify automation account permissions via `PermissionTestResults_s`
- Review module configuration in `ModuleConfig_s`
- Check for dependency issues

### 3. Permission-Related Issues

**Query to identify permission problems:**
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(24h)
| where Errors_s contains "permission" or Errors_s contains "forbidden" or Errors_s contains "unauthorized"
   or PermissionTestResults_s contains "FAIL"
| project TimeGenerated, ModuleName_s, PermissionTestResults_s, Errors_s
```

**Analysis:**
- Review `PermissionTestResults_s` for specific permission failures
- Check automation account managed identity assignments
- Verify service principal permissions
- Review conditional access policies

### 4. Performance Degradation Over Time

**Query to track performance trends:**
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(7d)
| where ModuleName_s != "MainRunbook"
| summarize AvgExecutionTime = avg(ExecutionTimeSeconds_d) by ModuleName_s, bin(TimeGenerated, 1d)
| render timechart
```

**Analysis:**
- Compare execution times across days
- Look for correlation with `ResourcesProcessed_d` increases
- Check for Azure service throttling patterns
- Review `GraphApiCalls_d` for API limit approaching

## KQL Query Examples

### Top 10 Slowest Modules (Last 24 Hours)
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(24h)
| where ModuleName_s != "MainRunbook"
| summarize AvgTime = avg(ExecutionTimeSeconds_d), MaxTime = max(ExecutionTimeSeconds_d), RunCount = count() by ModuleName_s, ControlName_s
| top 10 by AvgTime desc
```

### Modules with High Error Rates
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(7d)
| where ModuleName_s != "MainRunbook"
| summarize TotalRuns = count(), ErrorRuns = sumif(1, ErrorCount_d > 0) by ModuleName_s
| extend ErrorRate = round(100.0 * ErrorRuns / TotalRuns, 1)
| where ErrorRate > 10
| order by ErrorRate desc
```

### Graph API Usage by Module
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(24h)
| where GraphApiCalls_d > 0
| summarize TotalCalls = sum(GraphApiCalls_d), AvgCalls = avg(GraphApiCalls_d) by ModuleName_s
| order by TotalCalls desc
```

### Daily Execution Summary
```kusto
GuardrailsDebugMetrics_CL
| where TimeGenerated >= ago(30d)
| where ModuleName_s == "MainRunbook" and ControlName_s == "OverallExecution"
| extend ExecutionDate = format_datetime(TimeGenerated, 'yyyy-MM-dd')
| summarize 
    TotalExecutionTime = max(TotalExecutionTimeSeconds_d),
    TotalModules = max(TotalModulesProcessed_d),
    SuccessfulModules = max(SuccessfulModules_d),
    FailedModules = max(FailedModules_d)
    by ExecutionDate
| order by ExecutionDate desc
```

## Best Practices

### 1. Monitoring Setup
- Set up alerts for modules consistently failing
- Monitor execution time trends for performance regression
- Track error rates by guardrail control
- Set up notifications for permission failures

### 2. Data Retention
- Debug metrics follow standard Log Analytics retention policies
- Consider exporting historical data for long-term analysis
- Implement data lifecycle management for cost optimization

### 3. Performance Optimization
- Use debug data to identify bottleneck modules
- Optimize modules with high Graph API call counts
- Consider breaking down large modules into smaller components
- Monitor resource usage patterns for capacity planning

### 4. Security Considerations
- Debug data excludes sensitive information (secrets are sanitized)
- Access to debug metrics requires Log Analytics Reader permissions
- Consider additional access controls for production environments
- Regular audit of debug data access patterns

## Alerting Recommendations

### Critical Alerts
1. **Module Failure Rate > 20%**: Indicates systematic issues
2. **Execution Time > 30 minutes**: Potential timeout issues
3. **Permission Failures**: Security or configuration issues
4. **No Data Ingestion**: System availability issues

### Warning Alerts
1. **Execution Time Increase > 50%**: Performance degradation
2. **Error Rate > 5%**: Increasing error patterns
3. **Graph API Throttling**: API limit approaching
4. **Memory Usage High**: Resource constraints

## Support and Troubleshooting

### Common Issues

1. **Debug Data Not Appearing**
   - Verify `EnableDebugMetrics` automation variable is set to "true"
   - Check automation account has Log Analytics Contributor permissions
   - Ensure Log Analytics workspace is accessible
   - Allow 5-15 minutes for first-time table creation

2. **Incomplete Debug Data**
   - Check for module execution failures
   - Verify debug functions are properly loaded
   - Review automation account memory/CPU limits
   - Check for PowerShell execution policy issues

3. **Dashboard Not Loading**
   - Verify Log Analytics workspace access permissions
   - Ensure GuardrailsDebugMetrics_CL table exists
   - Check workbook template syntax
   - Verify time range parameters

### Getting Help

For issues with the enhanced metrics and debugging features:

1. Check the troubleshooting queries in the dashboard
2. Review automation account logs for initialization errors
3. Verify all prerequisites are met
4. Contact the Azure CaC support team with debug data samples

## Changelog

### v1.0.0 (Current)
- Initial implementation of enhanced metrics collection
- Basic performance and error tracking
- Azure Workbook dashboard template
- Configuration validation capabilities
- Comprehensive documentation

### Planned Features
- Advanced alerting templates
- Automated performance optimization recommendations
- Integration with Azure Monitor alerts
- Custom metric exports for external monitoring systems
- Machine learning-based anomaly detection