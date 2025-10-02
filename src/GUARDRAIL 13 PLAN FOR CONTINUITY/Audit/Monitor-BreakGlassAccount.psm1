<#
.SYNOPSIS
   
The solution will ensures that Break Glass accounts remain active and secure by monitoring the last login date.
.DESCRIPTION
The solution ensures that Break Glass accounts remain active and secure by monitoring the last login date. 
This implementation uses Microsoft Graph API to retrieve user sign-in activity directly from Azure AD, 
bypassing Log Analytics Workspace retention limitations that could cause false non-compliance when 
LAW retention is set to less than a year.
.PARAMETER Name
        token : auth token 
        ControlName :-  GUARDRAIL 13 PLAN FOR CONTINUITY
        FirstBreakGlassUPN: UPN for the first Break Glass account 
        SecondBreakGlassUPN: UPN for the second Break Glass account
        ItemName, 
        LAWResourceId : Log Analytics Workspace Resource ID (kept for compatibility, but no longer used for sign-in validation - now uses Microsoft Graph API directly)
        WorkSpaceID : Workspace ID to ingest the logs 
        WorkSpaceKey: Workspace Key for the Workdspace 
        LogType: GuardrailsCompliance, it will show in log Analytics search as GuardrailsCompliance_CL
#>
function Test-BreakGlassAccounts {
   
  param (
    [string] $ControlName, 
    [string] $ItemName,
    [string] $FirstBreakGlassUPN, 
    [string] $SecondBreakGlassUPN,
    [Parameter(Mandatory=$true)]
    [string] $LAWResourceId,
    [hashtable] $msgTable,
    [string] $itsgcode,
    [Parameter(Mandatory=$true)]
    [string] $ReportTime,
    [string] $CloudUsageProfiles = "3",  # Passed as a string
    [string] $ModuleProfiles,  # Passed as a string
    [switch] $EnableMultiCloudProfiles # New feature flag, default to false    
  )

  [bool] $IsCompliant = $false
  $commentsArray = @()
  [PSCustomObject] $ErrorList = New-Object System.Collections.ArrayList

  [String] $FirstBreakGlassUPNUrl = $("/users/" + $FirstBreakGlassUPN + "?$" + "select=userPrincipalName,id,userType,signInActivity")
  [String] $SecondBreakGlassUPNUrl = $("/users/" + $SecondBreakGlassUPN + "?$" + "select=userPrincipalName,id,userType,signInActivity")
  
  $bgCountConfig = 0
  if ($FirstBreakGlassUPN -ne ""){$bgCountConfig += 1}
  if ($SecondBreakGlassUPN -ne ""){$bgCountConfig += 1}

  # Validate at least one unique BG accounts exist in config.json
  if($FirstBreakGlassUPN -eq "" -and $SecondBreakGlassUPN -eq ""){
    $IsCompliant = $false
    $PsObject = [PSCustomObject]@{
      ComplianceStatus = $IsCompliant
      ControlName      = $ControlName
      ItemName         = $ItemName
      Comments         = $msgTable.isNotCompliant + " " + $msgTable.bgAccountNotExist
      ReportTime       = $ReportTime
      itsgcode         = $itsgcode
    }
  }
  elseif (($bgCountConfig -eq 2) -and $FirstBreakGlassUPN -eq $SecondBreakGlassUPN){
      $IsCompliant = $false
      $PsObject = [PSCustomObject]@{
        ComplianceStatus = $IsCompliant
        ControlName      = $ControlName
        ItemName         = $ItemName
        Comments         = $msgTable.isNotCompliant + " " + $msgTable.bgAccountNotExist
        ReportTime       = $ReportTime
        itsgcode         = $itsgcode
      }
  }
  else{
    # Step 1: Validate listed BG accounts as members
    $FirstBreakGlassAcct = [PSCustomObject]@{
      UserPrincipalName  = $FirstBreakGlassUPN
      apiUrl             = $FirstBreakGlassUPNUrl
      existStatus        = $false
    }
    $SecondBreakGlassAcct = [PSCustomObject]@{
      UserPrincipalName   = $SecondBreakGlassUPN
      apiUrl              = $SecondBreakGlassUPNUrl
      existStatus         = $false
    }
    # get 1st break glass account
    try {
      $urlPath = $FirstBreakGlassAcct.apiUrl
      $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop

      $data = $response.Content
      
      if ($null -ne  $data) {
        $FirstBreakGlassAcct.existStatus = $true
      } 
    }
    catch {
      $ErrorList.Add("Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_")
      Write-Warning "Error: Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_"
    }

    # get 2nd break glass account
    try {
      $urlPath = $SecondBreakGlassAcct.apiURL
      $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop

      $data = $response.Content

      if ($null -ne  $data) {
        $SecondBreakGlassAcct.existStatus = $true
      } 
    }
    catch {
      $ErrorList.Add("Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_")
      Write-Warning "Error: Failed to call Microsoft Graph REST API at URL '$urlPath'; returned error message: $_"
    }

    if ($bgCountConfig -eq 2){
      $validBG = $FirstBreakGlassAcct.existStatus -and $SecondBreakGlassAcct.existStatus
    }
    else {
      $validBG = $FirstBreakGlassAcct.existStatus -or $SecondBreakGlassAcct.existStatus
    }
    
    Write-Host "step 1 validate listed BG accounts compliance status:  $validBG"
    # if not compliant
    if(-not $validBG){
      $PsObject = [PSCustomObject]@{
        ComplianceStatus = $validBG
        ControlName      = $ControlName
        ItemName         = $ItemName
        Comments         = $msgTable.isNotCompliant + " " + $msgTable.bgAccountNotExist
        ReportTime       = $ReportTime
        itsgcode = $itsgcode
      }
    }
    else {
      # Step 2: Validate BG account Sign-in activity using Microsoft Graph API
      # 
      # IMPORTANT: This implementation uses Microsoft Graph API user.signInActivity property
      # instead of querying SignInLogs from Log Analytics Workspace (LAW). This resolves 
      # the issue where compliance checks would fail when LAW retention is set to less than 
      # a year (e.g., 30 days) because logs get moved to cold storage and become inaccessible
      # via KQL queries. 
      #
      # Benefits of this approach:
      # - Works regardless of LAW retention policy (30 days, 90 days, 730 days, etc.)
      # - More reliable data source (Azure AD directly vs. potentially incomplete logs)
      # - Faster execution (single API call vs. complex LAW query)
      # - Eliminates dependency on SignInLogs diagnostic settings configuration
      
      # Re-fetch Break Glass accounts with signInActivity data
      $firstBGSignInData = $null
      $secondBGSignInData = $null
      
      # Get first break glass account sign-in activity
      if ($FirstBreakGlassAcct.existStatus -and $FirstBreakGlassUPN -ne "") {
        try {
          $urlPath = $FirstBreakGlassAcct.apiUrl
          $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop
          $firstBGSignInData = $response.Content.signInActivity
        }
        catch {
          $ErrorList.Add("Failed to retrieve sign-in activity for first Break Glass account '$FirstBreakGlassUPN': $_")
          Write-Warning "Error: Failed to retrieve sign-in activity for first Break Glass account '$FirstBreakGlassUPN': $_"
        }
      }
      
      # Get second break glass account sign-in activity  
      if ($SecondBreakGlassAcct.existStatus -and $SecondBreakGlassUPN -ne "") {
        try {
          $urlPath = $SecondBreakGlassAcct.apiUrl
          $response = Invoke-GraphQuery -urlPath $urlPath -ErrorAction Stop
          $secondBGSignInData = $response.Content.signInActivity
        }
        catch {
          $ErrorList.Add("Failed to retrieve sign-in activity for second Break Glass account '$SecondBreakGlassUPN': $_")
          Write-Warning "Error: Failed to retrieve sign-in activity for second Break Glass account '$SecondBreakGlassUPN': $_"
        }
      }
      
      # Check if either account has signed in within the last 365 days
      $currentDate = Get-Date
      $oneYearAgo = $currentDate.AddDays(-365)
      $hasRecentSignIn = $false
      
      # Check first Break Glass account
      if ($null -ne $firstBGSignInData -and $null -ne $firstBGSignInData.lastSignInDateTime) {
        try {
          $lastSignInDate = [DateTime]::Parse($firstBGSignInData.lastSignInDateTime)
          if ($lastSignInDate -gt $oneYearAgo) {
            $hasRecentSignIn = $true
            Write-Verbose "First Break Glass account '$FirstBreakGlassUPN' last signed in on $($lastSignInDate.ToString('yyyy-MM-dd HH:mm:ss')) UTC"
          } else {
            Write-Verbose "First Break Glass account '$FirstBreakGlassUPN' last signed in on $($lastSignInDate.ToString('yyyy-MM-dd HH:mm:ss')) UTC (older than 365 days)"
          }
        }
        catch {
          $ErrorList.Add("Failed to parse lastSignInDateTime for first Break Glass account '$FirstBreakGlassUPN': $_")
          Write-Warning "Error: Failed to parse lastSignInDateTime for first Break Glass account '$FirstBreakGlassUPN': $_"
        }
      } else {
        Write-Verbose "First Break Glass account '$FirstBreakGlassUPN' has no sign-in activity data available"
      }
      
      # Check second Break Glass account
      if ($null -ne $secondBGSignInData -and $null -ne $secondBGSignInData.lastSignInDateTime) {
        try {
          $lastSignInDate = [DateTime]::Parse($secondBGSignInData.lastSignInDateTime)
          if ($lastSignInDate -gt $oneYearAgo) {
            $hasRecentSignIn = $true
            Write-Verbose "Second Break Glass account '$SecondBreakGlassUPN' last signed in on $($lastSignInDate.ToString('yyyy-MM-dd HH:mm:ss')) UTC"
          } else {
            Write-Verbose "Second Break Glass account '$SecondBreakGlassUPN' last signed in on $($lastSignInDate.ToString('yyyy-MM-dd HH:mm:ss')) UTC (older than 365 days)"
          }
        }
        catch {
          $ErrorList.Add("Failed to parse lastSignInDateTime for second Break Glass account '$SecondBreakGlassUPN': $_")
          Write-Warning "Error: Failed to parse lastSignInDateTime for second Break Glass account '$SecondBreakGlassUPN': $_"
        }
      } else {
        Write-Verbose "Second Break Glass account '$SecondBreakGlassUPN' has no sign-in activity data available"
      }
      
      # Set compliance status based on sign-in activity
      $IsCompliant = $hasRecentSignIn
    }
    

    if($IsCompliant){
      $commentsArray = $msgTable.isCompliant + " " + $msgTable.bgAccountLoginValid
    }
    else {
      $commentsArray = $msgTable.isNotCompliant + " " + $msgTable.bgAccountLoginNotValid
    }
    
    $Comments = $commentsArray -join ";"

    $PsObject = [PSCustomObject]@{
      ComplianceStatus = $IsCompliant
      ControlName      = $ControlName
      ItemName         = $ItemName
      Comments         = $Comments
      ReportTime       = $ReportTime
      itsgcode         = $itsgcode
    }
    
  }

  # Add profile information if MCUP feature is enabled
  if ($EnableMultiCloudProfiles) {
      $result = Add-ProfileInformation -Result $PsObject -CloudUsageProfiles $CloudUsageProfiles -ModuleProfiles $ModuleProfiles -SubscriptionId $subscriptionId -ErrorList $ErrorList
      Write-Host "$result"
  }

  $moduleOutput= [PSCustomObject]@{ 
    ComplianceResults = $PsObject
    Errors            = $ErrorList
    AdditionalResults = $AdditionalResults
  }
  return $moduleOutput   
}    


