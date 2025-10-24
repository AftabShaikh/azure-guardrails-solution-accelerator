function Get-DefenderForCloudAlerts {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ControlName,
        [Parameter(Mandatory=$true)]
        [string]$ItemName,
        [Parameter(Mandatory=$true)]
        [string]$itsgcode,
        [Parameter(Mandatory=$true)]
        [hashtable]$msgTable,
        [Parameter(Mandatory=$true)]
        [string]$ReportTime,
        [string] 
        $CloudUsageProfiles = "3",  # Passed as a string
        [string] $ModuleProfiles,  # Passed as a string
        [switch] 
        $EnableMultiCloudProfiles # default is false
    )

    [PSCustomObject] $PsObject = New-Object System.Collections.ArrayList
    [PSCustomObject] $ErrorList = New-Object System.Collections.ArrayList

    # Get All the Subscriptions
    try {
        $subs = Get-AzSubscription -ErrorAction Stop | Where-Object {$_.State -eq "Enabled"} 
    }
    catch {
        $Errorlist.Add("Failed to execute the 'Get-AzSubscription' command--verify your permissions and the installion of the Az.Resources module; returned error message: $_" )
        throw "Error: Failed to execute the 'Get-AzSubscription' command--verify your permissions and the installion of the Az.Resources module; returned error message: $_"
    }


    foreach($subscription in $subs){
        # Initialize
        $isCompliant = $true
        $Comments = ""

        # find subscription information
        $subId = $subscription.Id
        Set-AzContext -SubscriptionId $subId

        # Get all resources in the subscription to check what types exist
        try {
            $allResources = Get-AzResource -ErrorAction Stop
        }
        catch {
            $isCompliant = $false
            $Comments = $msgTable.errorRetrievingResources
            $ErrorList.Add("Failed to execute the 'Get-AzResource' command for subscription $($subscription.Name): $_")
        }

        if ($isCompliant) {
            # Define mapping of Defender plan names to Azure resource types
            $defenderPlanMapping = @{
                'VirtualMachines' = @('Microsoft.Compute/virtualMachines')
                'StorageAccounts' = @('Microsoft.Storage/storageAccounts')
                'SqlServers' = @('Microsoft.Sql/servers')
                'AppServices' = @('Microsoft.Web/sites')
                'Containers' = @('Microsoft.ContainerService/managedClusters', 'Microsoft.ContainerRegistry/registries', 'Microsoft.ContainerInstance/containerGroups')
            }

            # Count resources by type
            $resourceCounts = @{}
            foreach ($planName in $defenderPlanMapping.Keys) {
                $count = 0
                foreach ($resourceType in $defenderPlanMapping[$planName]) {
                    $count += ($allResources | Where-Object {$_.ResourceType -eq $resourceType}).Count
                }
                $resourceCounts[$planName] = $count
            }

            # Get defender plans for the subscription
            $defenderPlans = Get-AzSecurityPricing
            $enabledDefenderPlans = $defenderPlans | Where-Object {$_.PricingTier -eq 'Standard'}

            # Check if any resources exist that require Defender protection
            $plansRequiringProtection = @()
            $missingProtectionPlans = @()

            foreach ($planName in $defenderPlanMapping.Keys) {
                $resourceCount = $resourceCounts[$planName]
                if ($resourceCount -gt 0) {
                    $plansRequiringProtection += $planName
                    $planEnabled = $enabledDefenderPlans | Where-Object {$_.Name -eq $planName}
                    if (-not $planEnabled) {
                        $missingProtectionPlans += "$planName ($resourceCount resources)"
                    }
                }
            }

            # Determine compliance based on protection plan requirements
            if ($plansRequiringProtection.Count -eq 0) {
                # No resources requiring protection found - this is compliant
                $Comments = $msgTable.DefenderCompliantNoResourcesFound
            }
            elseif ($missingProtectionPlans.Count -gt 0) {
                # Some required protection plans are missing
                $isCompliant = $false
                $Comments = $msgTable.DefenderPlansNotEnabledForResources -f ($missingProtectionPlans -join ', ')
            }
            # If $plansRequiringProtection.Count > 0 and $missingProtectionPlans.Count == 0,
            # then all required plans are enabled, continue to notification checks
        }

        # Continue with notification checks only if defender plans are properly configured and resources exist
        if ($isCompliant -and $plansRequiringProtection.Count -gt 0) {
            $azContext = Get-AzContext
            $token = Get-AzAccessToken -TenantId $azContext.Subscription.TenantId 
            
            $authHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = 'Bearer ' + $token.Token
            }

            # Retrieve notifications for alert and attack paths
            $restUri = "https://management.azure.com/subscriptions/$($azContext.Subscription.Id)/providers/Microsoft.Security/securityContacts/default?api-version=2023-12-01-preview"

            try{
                $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader
            }
            catch{
                $isCompliant = $false
                $Comments = $msgTable.errorRetrievingNotifications
                $ErrorList = "Error invoking $restUri for notifications for the subscription: $_"
                
            }
            
            $notificationSources = $response.properties.notificationsSources
            $notificationEmails = $response.properties.emails
            $ownerRole = $response.properties.notificationsByRole.roles | Where-Object {$_ -eq "Owner"}
            $ownerState = $response.properties.notificationsByRole.State

            # Filter to get required notification types
            $alertNotification = $notificationSources | Where-Object {$_.sourceType -eq "Alert" -and $_.minimalSeverity -in @("Medium","Low")}
            $attackPathNotification = $notificationSources | Where-Object {$_.sourceType -eq "AttackPath" -and $_.minimalRiskLevel -in @("Medium","Low")}

            $emailCount = ($notificationEmails -split ";").Count

            # CONDITION: Check if there is minimum two emails and owner is also notified
            if(($emailCount -lt 2) -or ($ownerState -ne "On" -or $ownerRole -ne "Owner")){
                $isCompliant = $false
                $Comments = $msgTable.EmailsOrOwnerNotConfigured -f $($subscription.Name)
            }

            if($null -eq $alertNotification){
                $isCompliant = $false
                $Comments = $msgTable.AlertNotificationNotConfigured
                
            }

            if($null -eq $attackPathNotification){
                $isCompliant = $false
                $Comments = $msgTable.AttackPathNotificationNotConfigured
                
            }

        }

        # Set final compliance message if still compliant and no message was set
        if ($isCompliant -and -not $Comments) {
            if ($plansRequiringProtection.Count -eq 0) {
                $Comments = $msgTable.DefenderCompliantNoResourcesFound
            } else {
                $Comments = $msgTable.DefenderCompliant
            }
        }

        $C = [PSCustomObject]@{
            SubscriptionName = $subscription.Name
            ComplianceStatus = $isCompliant
            ControlName = $ControlName
            Comments = $Comments
            ItemName = $ItemName
            ReportTime = $ReportTime
            itsgcode = $itsgcode
        }
        
        # Add profile information if MCUP feature is enabled
        if($EnableMultiCloudProfiles){
            $result = Add-ProfileInformation -Result $C -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $subscriptionId -ErrorList $ErrorList
            Write-Host "$result"
            $PsObject.add($result) | Out-Null
        } else {
            $PsObject.add($C) | Out-Null
        }
        
    }
    
    $moduleOutput = [PSCustomObject]@{
        ComplianceResults = $PsObject
        Errors = $ErrorList
    }

    return $moduleOutput
}
