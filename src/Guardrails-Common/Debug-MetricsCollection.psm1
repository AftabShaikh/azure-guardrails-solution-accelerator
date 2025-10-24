function Add-GuardrailDebugData {
    <#
    .SYNOPSIS
    Collects and sends debug/metrics data to Log Analytics for troubleshooting and performance monitoring.
    
    .DESCRIPTION
    This function collects detailed debug and performance metrics for Azure CaC guardrails execution.
    It sends data to a dedicated GuardrailsDebugMetrics_CL table in Log Analytics for analysis and dashboards.
    
    .PARAMETER DebugData
    Hashtable containing debug information to be logged
    
    .PARAMETER WorkSpaceID
    Log Analytics Workspace ID
    
    .PARAMETER WorkspaceKey
    Log Analytics Workspace Key
    
    .PARAMETER ReportTime
    Timestamp for the report
    
    .PARAMETER ModuleName
    Name of the module generating the debug data
    
    .PARAMETER ControlName
    Name of the guardrail control (e.g., "Guardrails1")
    
    .EXAMPLE
    Add-GuardrailDebugData -DebugData @{
        ModuleExecutionTime = 1234
        ResourcesProcessed = 50
        PermissionsValidated = @("Reader", "Contributor")
    } -WorkSpaceID $workspaceId -WorkspaceKey $key -ReportTime $reportTime -ModuleName "Check-AllUserMFARequired" -ControlName "Guardrails1"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $DebugData,
        
        [Parameter(Mandatory = $true)]
        [string] $WorkSpaceID,
        
        [Parameter(Mandatory = $true)]
        [string] $WorkspaceKey,
        
        [Parameter(Mandatory = $true)]
        [string] $ReportTime,
        
        [Parameter(Mandatory = $true)]
        [string] $ModuleName,
        
        [Parameter(Mandatory = $true)]
        [string] $ControlName,
        
        [Parameter(Mandatory = $false)]
        [string] $LogType = "GuardrailsDebugMetrics"
    )
    
    try {
        # Create standardized debug record
        $debugRecord = [PSCustomObject]@{
            ReportTime = $ReportTime
            ModuleName = $ModuleName
            ControlName = $ControlName
            TenantId = (Get-AzContext).Tenant.Id
            SubscriptionId = (Get-AzContext).Subscription.Id
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        # Add all debug data as properties
        foreach ($key in $DebugData.Keys) {
            $value = $DebugData[$key]
            # Convert arrays and complex objects to JSON strings for Log Analytics
            if ($value -is [array] -or $value -is [hashtable]) {
                $value = $value | ConvertTo-Json -Compress -Depth 3
            }
            $debugRecord | Add-Member -MemberType NoteProperty -Name $key -Value $value
        }
        
        # Send to Log Analytics
        New-LogAnalyticsData -Data @($debugRecord) -WorkSpaceID $WorkSpaceID -WorkSpaceKey $WorkspaceKey -LogType $LogType
        
        Write-Verbose "Debug data sent for module: $ModuleName"
        
    } catch {
        Write-Warning "Failed to send debug data for module $ModuleName : $_"
        # Don't throw - debug logging should not break the main process
    }
}

function Start-ModuleMetricsCollection {
    <#
    .SYNOPSIS
    Starts performance metrics collection for a module
    
    .DESCRIPTION
    Creates a metrics collection context that tracks various performance indicators during module execution
    
    .PARAMETER ModuleName
    Name of the module being executed
    
    .PARAMETER ControlName  
    Name of the guardrail control
    
    .EXAMPLE
    $metricsContext = Start-ModuleMetricsCollection -ModuleName "Check-AllUserMFARequired" -ControlName "Guardrails1"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName,
        
        [Parameter(Mandatory = $true)]
        [string] $ControlName
    )
    
    $context = @{
        ModuleName = $ModuleName
        ControlName = $ControlName
        StartTime = Get-Date
        StartTimeString = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        GraphApiCalls = 0
        ResourcesProcessed = 0
        ErrorCount = 0
        WarningCount = 0
        PermissionsChecked = @()
        AutomationVariables = @{}
        Errors = @()
        Warnings = @()
        AdditionalMetrics = @{}
    }
    
    Write-Verbose "Started metrics collection for module: $ModuleName"
    return $context
}

function Stop-ModuleMetricsCollection {
    <#
    .SYNOPSIS
    Stops metrics collection and returns collected data
    
    .DESCRIPTION
    Finalizes metrics collection and returns all collected data for logging
    
    .PARAMETER MetricsContext
    The metrics context returned by Start-ModuleMetricsCollection
    
    .EXAMPLE
    $debugData = Stop-ModuleMetricsCollection -MetricsContext $metricsContext
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $MetricsContext
    )
    
    $MetricsContext.Stopwatch.Stop()
    $MetricsContext.EndTime = Get-Date
    $MetricsContext.EndTimeString = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $MetricsContext.ExecutionTimeMs = $MetricsContext.Stopwatch.ElapsedMilliseconds
    $MetricsContext.ExecutionTimeSeconds = [Math]::Round($MetricsContext.Stopwatch.ElapsedMilliseconds / 1000, 2)
    
    # Remove the stopwatch object as it can't be serialized
    $MetricsContext.Remove('Stopwatch')
    
    Write-Verbose "Stopped metrics collection for module: $($MetricsContext.ModuleName) - Duration: $($MetricsContext.ExecutionTimeSeconds)s"
    
    return $MetricsContext
}

function Add-MetricsContextData {
    <#
    .SYNOPSIS
    Adds data to an existing metrics context
    
    .DESCRIPTION
    Allows modules to add specific metrics data during execution
    
    .PARAMETER MetricsContext
    The metrics context to update
    
    .PARAMETER Key
    The key for the metric
    
    .PARAMETER Value
    The value for the metric
    
    .EXAMPLE
    Add-MetricsContextData -MetricsContext $context -Key "UsersProcessed" -Value 150
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $MetricsContext,
        
        [Parameter(Mandatory = $true)]
        [string] $Key,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    $MetricsContext.AdditionalMetrics[$Key] = $Value
    Write-Verbose "Added metrics data: $Key = $Value"
}

function Get-AutomationAccountVariables {
    <#
    .SYNOPSIS
    Retrieves and sanitizes automation account variables for debugging
    
    .DESCRIPTION
    Collects automation account variables while sanitizing sensitive information
    
    .EXAMPLE
    $variables = Get-AutomationAccountVariables
    #>
    [CmdletBinding()]
    param ()
    
    $variables = @{}
    
    try {
        # Common automation variables to collect (non-sensitive)
        $variableNames = @(
            'ResourceGroupName', 'StorageAccountName', 'DepartmentNumber',
            'CBSSubscriptionName', 'GuardRailsLocale', 'securityRetentionDays',
            'cloudUsageProfiles', 'LogType', 'ContainerName'
        )
        
        foreach ($varName in $variableNames) {
            try {
                $value = Get-GSAAutomationVariable -Name $varName -ErrorAction SilentlyContinue
                if ($null -ne $value) {
                    $variables[$varName] = $value
                }
            } catch {
                $variables[$varName] = "ERROR_RETRIEVING_VALUE"
            }
        }
        
        # Add context information
        $variables['TenantId'] = (Get-AzContext).Tenant.Id
        $variables['SubscriptionId'] = (Get-AzContext).Subscription.Id
        $variables['PowerShellVersion'] = $PSVersionTable.PSVersion.ToString()
        $variables['AzModuleVersion'] = (Get-Module Az.Accounts -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString()
        
    } catch {
        Write-Warning "Failed to retrieve automation variables: $_"
    }
    
    return $variables
}

function Test-RequiredPermissions {
    <#
    .SYNOPSIS
    Tests and logs required permissions for guardrails execution
    
    .DESCRIPTION
    Validates that the automation account has required permissions and logs results for debugging
    
    .PARAMETER MetricsContext
    Optional metrics context to update
    
    .EXAMPLE
    $permissionResults = Test-RequiredPermissions -MetricsContext $context
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [hashtable] $MetricsContext
    )
    
    $permissionResults = @{
        HasReaderAccess = $false
        HasGraphPermissions = $false
        HasLogAnalyticsAccess = $false
        HasStorageAccess = $false
        TestedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Details = @()
    }
    
    try {
        # Test basic Azure access
        $subscription = Get-AzSubscription -ErrorAction SilentlyContinue
        if ($subscription) {
            $permissionResults.HasReaderAccess = $true
            $permissionResults.Details += "Azure subscription access: PASS"
        } else {
            $permissionResults.Details += "Azure subscription access: FAIL"
        }
        
        # Test Microsoft Graph access
        try {
            $testQuery = "/users?`$top=1&`$select=id"
            $response = Invoke-GraphQuery -urlPath $testQuery -ErrorAction SilentlyContinue
            if ($response -and $response.StatusCode -eq 200) {
                $permissionResults.HasGraphPermissions = $true
                $permissionResults.Details += "Microsoft Graph access: PASS"
            } else {
                $permissionResults.Details += "Microsoft Graph access: FAIL"
            }
        } catch {
            $permissionResults.Details += "Microsoft Graph access: FAIL - $_"
        }
        
        # Test Log Analytics access
        try {
            $workspaceId = Get-GSAAutomationVariable -Name "WorkSpaceID" -ErrorAction SilentlyContinue
            if ($workspaceId) {
                $testQuery = "Heartbeat | limit 1"
                Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $testQuery -ErrorAction SilentlyContinue | Out-Null
                $permissionResults.HasLogAnalyticsAccess = $true
                $permissionResults.Details += "Log Analytics access: PASS"
            } else {
                $permissionResults.Details += "Log Analytics access: FAIL - No WorkSpaceID"
            }
        } catch {
            $permissionResults.Details += "Log Analytics access: FAIL - $_"
        }
        
        # Test Storage account access
        try {
            $storageAccountName = Get-GSAAutomationVariable -Name "StorageAccountName" -ErrorAction SilentlyContinue
            $resourceGroupName = Get-GSAAutomationVariable -Name "ResourceGroupName" -ErrorAction SilentlyContinue
            if ($storageAccountName -and $resourceGroupName) {
                Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue | Out-Null
                $permissionResults.HasStorageAccess = $true
                $permissionResults.Details += "Storage account access: PASS"
            } else {
                $permissionResults.Details += "Storage account access: FAIL - Missing variables"
            }
        } catch {
            $permissionResults.Details += "Storage account access: FAIL - $_"
        }
        
        # Update metrics context if provided
        if ($MetricsContext) {
            $MetricsContext.PermissionsChecked = $permissionResults.Details
            $MetricsContext.AdditionalMetrics['PermissionTestResults'] = $permissionResults
        }
        
    } catch {
        Write-Warning "Failed to test permissions: $_"
        $permissionResults.Details += "Permission testing failed: $_"
    }
    
    return $permissionResults
}

function Get-GuardrailsRuntimeContext {
    <#
    .SYNOPSIS
    Gathers comprehensive runtime context information for debugging
    
    .DESCRIPTION
    Collects system information, configuration, and runtime state for troubleshooting
    
    .EXAMPLE
    $runtimeContext = Get-GuardrailsRuntimeContext
    #>
    [CmdletBinding()]
    param ()
    
    $context = @{
        CollectedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SystemInfo = @{}
        AzureContext = @{}
        Configuration = @{}
        ModuleVersions = @{}
    }
    
    try {
        # System information
        $context.SystemInfo = @{
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            ExecutionPolicy = (Get-ExecutionPolicy).ToString()
            Culture = (Get-Culture).Name
            TimeZone = (Get-TimeZone).Id
            IsRunningInAutomation = ($ENV:AZUREPS_HOST_ENVIRONMENT -eq 'AzureAutomation/' -or $PSPrivateMetadata.JobId)
        }
        
        # Azure context
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if ($azContext) {
            $context.AzureContext = @{
                TenantId = $azContext.Tenant.Id
                SubscriptionId = $azContext.Subscription.Id
                SubscriptionName = $azContext.Subscription.Name
                Account = $azContext.Account.Id
                Environment = $azContext.Environment.Name
            }
        }
        
        # Module versions
        $importantModules = @('Az.Accounts', 'Az.Profile', 'Az.Resources', 'Az.Storage', 'Az.OperationalInsights', 'Az.KeyVault')
        foreach ($moduleName in $importantModules) {
            $module = Get-Module $moduleName -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
            if ($module) {
                $context.ModuleVersions[$moduleName] = $module.Version.ToString()
            } else {
                $context.ModuleVersions[$moduleName] = "Not Available"
            }
        }
        
        # Configuration (non-sensitive)
        $context.Configuration = Get-AutomationAccountVariables
        
    } catch {
        Write-Warning "Failed to gather runtime context: $_"
        $context['ErrorCollectingContext'] = $_.Exception.Message
    }
    
    return $context
}

Export-ModuleMember -Function @(
    'Add-GuardrailDebugData',
    'Start-ModuleMetricsCollection', 
    'Stop-ModuleMetricsCollection',
    'Add-MetricsContextData',
    'Get-AutomationAccountVariables',
    'Test-RequiredPermissions',
    'Get-GuardrailsRuntimeContext'
)