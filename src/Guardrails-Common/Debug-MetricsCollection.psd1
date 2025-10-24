@{
    RootModule = 'Debug-MetricsCollection.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b8d4e8a2-4f3a-4d2c-8e5f-1a9b7c6d5e4f'
    Author = 'Azure Guardrails Solution Accelerator Team'
    CompanyName = 'Shared Services Canada'
    Copyright = '(c) Microsoft Corporation. All rights reserved.'
    Description = 'Enhanced metrics and debugging support module for Azure Compliance as Code (CaC) solution'
    PowerShellVersion = '5.1'
    
    RequiredModules = @(
        'Az.Accounts',
        'Az.Profile',
        'Az.Resources',
        'Az.OperationalInsights'
    )
    
    FunctionsToExport = @(
        'Add-GuardrailDebugData',
        'Start-ModuleMetricsCollection', 
        'Stop-ModuleMetricsCollection',
        'Add-MetricsContextData',
        'Get-AutomationAccountVariables',
        'Test-RequiredPermissions',
        'Get-GuardrailsRuntimeContext'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'Compliance', 'Guardrails', 'Debugging', 'Metrics', 'CaC')
            ProjectUri = 'https://github.com/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator'
            ReleaseNotes = 'Initial release of enhanced metrics and debugging support for Azure CaC'
        }
    }
}