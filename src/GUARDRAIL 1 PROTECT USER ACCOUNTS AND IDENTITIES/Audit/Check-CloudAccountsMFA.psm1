function Check-CloudAccountsMFA {
    param (      
        [Parameter(Mandatory=$true)]
        [string] $ControlName,
        [Parameter(Mandatory=$true)]
        [string] $ItemName,
        [Parameter(Mandatory=$true)]
        [string] $itsgcode,
        [Parameter(Mandatory=$true)]
        [hashtable] $msgTable,
        [Parameter(Mandatory=$true)]
        [string] $ReportTime,
        [string] $CloudUsageProfiles = "3",  # Passed as a string
        [string] $ModuleProfiles,  # Passed as a string
        [switch] $EnableMultiCloudProfiles # New feature flag, default to false    
    )
    $IsCompliant = $false
    [PSCustomObject] $ErrorList = New-Object System.Collections.ArrayList
    

    # get conditional access policies
    $CABaseAPIUrl = '/identity/conditionalAccess/policies'
    try {
        $response = Invoke-GraphQuery -urlPath $CABaseAPIUrl -ErrorAction Stop
        
        $caps = $response.Content.value
    }
    catch {
        $Errorlist.Add("Failed to call Microsoft Graph REST API at URL '$CABaseAPIUrl'; returned error message: $_")
        Write-Warning "Error: Failed to call Microsoft Graph REST API at URL '$CABaseAPIUrl'; returned error message: $_"
    }
    
    # Get all users to identify Microsoft Entra Connector accounts
    $urlPath = "/users"
    $syncAccountIds = @()
    try {
        $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop
        $users = $response.Content.value | Select-Object userPrincipalName, id
        
        # Identify Microsoft Entra Connector accounts (sync accounts)
        # These typically start with "Sync_" and are auto-created by Entra ID Connect
        $syncAccounts = $users | Where-Object { $_.userPrincipalName -like "Sync_*" }
        $syncAccountIds = $syncAccounts.id
        
        if ($syncAccounts.Count -gt 0) {
            Write-Host "Found $($syncAccounts.Count) Microsoft Entra Connector sync account(s): $($syncAccounts.userPrincipalName -join ', ')"
        }
    }
    catch {
        $Errorlist.Add("Failed to retrieve users for sync account identification: $_")
        Write-Warning "Error: Failed to retrieve users for sync account identification: $_"
    }

    # check for a conditional access policy which meets these requirements:
    # 1. state =  'enabled'
    # 2. includedUsers = 'All'
    # 3. includedApplications = 'All'
    # 4. grantControls.builtInControls contains 'mfa'
    # 5. clientAppTypes contains 'all'
    # 6. userRiskLevels = @()
    # 7. signInRiskLevels = @()
    # 8. platforms = null
    # 9. locations = null
    # 10. devices = null
    # 11. clientApplications = null
    # 12. excludeUsers may contain Microsoft Entra Connector sync accounts

    $validPolicies = $caps | Where-Object {
        $_.state -eq 'enabled' -and
        $_.conditions.users.includeUsers -contains 'All' -and
        ($_.conditions.applications.includeApplications -contains 'All' -or
         $_.conditions.applications.includeApplications -contains 'MicrosoftAdminPortals') -and
        $_.grantControls.builtInControls -contains 'mfa' -and
        $_.conditions.clientAppTypes -contains 'all' -and
        [string]::IsNullOrEmpty($_.conditions.userRiskLevels) -and
        [string]::IsNullOrEmpty($_.conditions.signInRiskLevels) -and
        [string]::IsNullOrEmpty($_.conditions.platforms) -and
        [string]::IsNullOrEmpty($_.conditions.locations) -and
        [string]::IsNullOrEmpty($_.conditions.devices) -and
        [string]::IsNullOrEmpty($_.conditions.clientApplications) -and
        # Allow exclusions for Microsoft Entra Connector sync accounts only
        ($_.conditions.users.excludeUsers.Count -eq 0 -or 
         ($_.conditions.users.excludeUsers | ForEach-Object { $_ -in $syncAccountIds }) -notcontains $false)
    }

    if ($validPolicies.count -ne 0) {

        $IsCompliant = $true
        $Comments = $msgTable.mfaRequiredForAllUsers    

    }
    else {
        # Failed. Reason: No policies meet the requirements
        $Comments = $msgTable.noMFAPolicyForAllUsers
        $IsCompliant = $false
    }
    
    $PsObject = [PSCustomObject]@{
        ComplianceStatus = $IsCompliant
        ControlName      = $ControlName
        Comments         = $Comments
        ItemName         = $ItemName
        ReportTime       = $ReportTime
        itsgcode         = $itsgcode
    }

    # Add profile information if MCUP feature is enabled
    if ($EnableMultiCloudProfiles) {
        $result = Add-ProfileInformation -Result $PsObject -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $subscriptionId -ErrorList $ErrorList
        Write-Host "$result"
    }

    $moduleOutput= [PSCustomObject]@{ 
        ComplianceResults = $PsObject
        Errors=$ErrorList
        AdditionalResults = $AdditionalResults
    }
    return $moduleOutput   
}

