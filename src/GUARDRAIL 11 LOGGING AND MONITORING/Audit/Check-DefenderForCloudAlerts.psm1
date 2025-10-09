function Test-SentinelInSubscription {
    <#
        Checks if Sentinel is in use within a subscription by looking for:
        1. Log Analytics Workspaces with approved locks (ReadOnly or CanNotDelete)
        2. Log Analytics Workspaces with sentinel=true tag
        3. Sentinel-specific tables in Log Analytics Workspaces
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SubscriptionId
    )

    try {
        # Set context to the subscription
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
        
        # Get all Log Analytics Workspaces in the subscription
        $workspaces = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
        
        if (-not $workspaces) {
            return $false
        }

        foreach ($workspace in $workspaces) {
            # Check for approved lock levels
            $lock = Get-AzResourceLock -ResourceGroupName $workspace.ResourceGroupName -ResourceName $workspace.Name -ResourceType "Microsoft.OperationalInsights/workspaces" -ErrorAction SilentlyContinue
            if ($lock -and ($lock.Properties.level -eq 'ReadOnly' -or $lock.Properties.level -eq 'CanNotDelete')) {
                return $true
            }

            # Check for sentinel=true tag
            if ($workspace.Tags -and $workspace.Tags.ContainsKey("sentinel") -and ($workspace.Tags["sentinel"].ToString().ToLower() -eq "true")) {
                return $true
            }

            # Check for Sentinel tables
            $sentinelTables = @('SecurityIncident', 'HuntingBookmark', 'SentinelHealth')
            foreach ($table in $sentinelTables) {
                try {
                    $query = "$table | take 0"
                    $null = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $query -ErrorAction Stop
                    return $true  # If any table exists, Sentinel is in use
                } catch {
                    # Table doesn't exist, continue checking
                }
            }
        }
        
        return $false
    } catch {
        # If any error occurs, assume Sentinel is not in use
        return $false
    }
}

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
        $sentinelInUse = $false

        # find subscription information
        $subId = $subscription.Id
        Set-AzContext -SubscriptionId $subId

        $defenderPlans = Get-AzSecurityPricing
        $defenderEnabled = $defenderPlans | Where-Object {$_.PricingTier -eq 'Standard'} #A paid plan should exist on the sub resource

        if(-not $defenderEnabled){
            $isCompliant = $false
            $Comments = $msgTable.NotAllSubsHaveDefenderPlans -f $subscription 
        }
        else{
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

            # Check if Sentinel is in use in this subscription
            $sentinelInUse = Test-SentinelInSubscription -SubscriptionId $subId

            # Filter to get required notification types
            $alertNotification = $notificationSources | Where-Object {$_.sourceType -eq "Alert" -and $_.minimalSeverity -in @("Medium","Low")}
            $attackPathNotification = $notificationSources | Where-Object {$_.sourceType -eq "AttackPath" -and $_.minimalRiskLevel -in @("Medium","Low")}

            # CONDITION: Check email requirements only if Sentinel is NOT in use
            if (-not $sentinelInUse) {
                $emailCount = ($notificationEmails -split ";").Count

                # Check if there is minimum two emails and owner is also notified
                if(($emailCount -lt 2) -or ($ownerState -ne "On" -or $ownerRole -ne "Owner")){
                    $isCompliant = $false
                    $Comments = $msgTable.EmailsOrOwnerNotConfigured -f $($subscription.Name)
                }
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

        # If it reaches here, then this subscription is compliant
        if ($isCompliant){
            if ($sentinelInUse) {
                $Comments = $msgTable.DefenderCompliantSentinel
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
