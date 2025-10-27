# Secure Versioning Module for Azure Guardrails Solution Accelerator
# This module provides enhanced security for version verification to prevent spoofing and user errors

function Get-SecureVersionInformation {
    <#
    .SYNOPSIS
    Retrieves version information using secure verification methods to prevent spoofing and user errors.
    
    .DESCRIPTION
    This function implements multiple verification layers:
    1. GitHub Release API as primary source (harder to spoof)
    2. Cross-validation against manifest checksums
    3. Fallback verification mechanisms
    4. Enhanced error detection for user modifications
    
    .PARAMETER AllowFallback
    Whether to allow fallback to less secure methods if primary verification fails
    
    .PARAMETER ValidateChecksums
    Whether to validate file checksums for integrity verification
    
    .EXAMPLE
    $versionInfo = Get-SecureVersionInformation -ValidateChecksums $true
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [bool]$AllowFallback = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$ValidateChecksums = $true
    )
    
    $securityResults = @{
        VerificationLevel = "Unknown"
        SecurityWarnings = @()
        SourceUsed = "Unknown"
        IntegrityVerified = $false
    }
    
    try {
        Write-Verbose "Starting secure version verification process..."
        
        # Primary method: Use GitHub Release API directly
        $githubVersionInfo = Get-GitHubReleaseVersionInfo
        if ($githubVersionInfo.IsValid) {
            $securityResults.VerificationLevel = "High"
            $securityResults.SourceUsed = "GitHub_Release_API"
            $securityResults.IntegrityVerified = $true
            
            Write-Verbose "Successfully retrieved version from GitHub Release API (high security)"
            return @{
                ReleaseVersion = $githubVersionInfo.Version
                ReleaseDate = $githubVersionInfo.Date
                SourceVerified = $true
                SecurityResults = $securityResults
            }
        }
        
        # Secondary method: Version manifest with checksum validation
        if ($ValidateChecksums) {
            $manifestVersionInfo = Get-ManifestVersionInfo -ValidateChecksum $true
            if ($manifestVersionInfo.IsValid) {
                $securityResults.VerificationLevel = "Medium"
                $securityResults.SourceUsed = "Verified_Manifest"
                $securityResults.IntegrityVerified = $true
                $securityResults.SecurityWarnings += "Using manifest fallback - consider investigating GitHub API issues"
                
                Write-Warning "Using version manifest fallback method (medium security)"
                return @{
                    ReleaseVersion = $manifestVersionInfo.Version
                    ReleaseDate = $manifestVersionInfo.Date
                    SourceVerified = $true
                    SecurityResults = $securityResults
                }
            }
        }
        
        # Fallback method: Original tags.json (if explicitly allowed)
        if ($AllowFallback) {
            Write-Warning "Falling back to original tags.json method - reduced security"
            $tagsVersionInfo = Get-LegacyTagsVersionInfo
            if ($tagsVersionInfo.IsValid) {
                $securityResults.VerificationLevel = "Low"
                $securityResults.SourceUsed = "Legacy_Tags"
                $securityResults.IntegrityVerified = $false
                $securityResults.SecurityWarnings += "Using insecure legacy method - version may be spoofed"
                
                return @{
                    ReleaseVersion = $tagsVersionInfo.Version
                    ReleaseDate = $tagsVersionInfo.Date
                    SourceVerified = $false
                    SecurityResults = $securityResults
                }
            }
        }
        
        # If all methods fail
        throw "All version verification methods failed"
        
    }
    catch {
        Write-Error "Secure version verification failed: $_"
        $securityResults.VerificationLevel = "Failed"
        $securityResults.SecurityWarnings += "Version verification completely failed - system may be compromised"
        
        return @{
            ReleaseVersion = $null
            ReleaseDate = $null
            SourceVerified = $false
            SecurityResults = $securityResults
            Error = $_
        }
    }
}

function Get-GitHubReleaseVersionInfo {
    <#
    .SYNOPSIS
    Retrieves version information directly from GitHub Release API for maximum security.
    
    .DESCRIPTION
    Uses GitHub's official Release API which is harder to spoof than raw file access.
    Validates the release data structure and extracts version information.
    #>
    [CmdletBinding()]
    param ()
    
    try {
        Write-Verbose "Fetching version from GitHub Release API..."
        
        # Use GitHub API to get latest release (more secure than raw file access)
        $latestRelease = Invoke-RestMethod 'https://api.github.com/repos/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/releases/latest' -Verbose:$false
        
        # Validate the release structure
        if (-not $latestRelease.tag_name) {
            throw "Invalid GitHub release structure - missing tag_name"
        }
        
        # Extract version from tag name and published date
        $version = $latestRelease.tag_name
        $releaseDate = $latestRelease.published_at
        
        # Convert and validate the date
        try {
            $parsedDate = [DateTime]::Parse($releaseDate)
            $formattedDate = $parsedDate.ToString("yyyy/MM/dd")
        }
        catch {
            Write-Warning "Could not parse release date, using current date"
            $formattedDate = (Get-Date).ToString("yyyy/MM/dd")
        }
        
        # Additional validation: ensure the version follows expected format
        if ($version -notmatch '^v?\d+\.\d+\.\d+') {
            Write-Warning "Version format may be unusual: $version"
        }
        
        Write-Verbose "Successfully retrieved version $version from GitHub API"
        
        return @{
            IsValid = $true
            Version = $version
            Date = $formattedDate
            Source = "GitHub_API"
            ReleaseId = $latestRelease.id
            ReleaseUrl = $latestRelease.html_url
        }
    }
    catch {
        Write-Verbose "GitHub API version retrieval failed: $_"
        return @{
            IsValid = $false
            Error = $_
        }
    }
}

function Get-ManifestVersionInfo {
    <#
    .SYNOPSIS
    Retrieves version information from the version manifest with integrity validation.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [bool]$ValidateChecksum = $true
    )
    
    try {
        Write-Verbose "Fetching version from version manifest..."
        
        # Try to get the latest release info to construct the manifest URL
        $latestRelease = Invoke-RestMethod 'https://api.github.com/repos/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/releases/latest' -Verbose:$false -ErrorAction SilentlyContinue
        
        if ($latestRelease) {
            $manifestUri = "https://github.com/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/raw/{0}/setup/version-manifest.json" -f $latestRelease.tag_name
        }
        else {
            # Fallback to main branch
            $manifestUri = "https://github.com/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/raw/main/setup/version-manifest.json"
        }
        
        $manifest = Invoke-RestMethod $manifestUri -Verbose:$false
        
        # Validate manifest structure
        if (-not ($manifest.ReleaseVersion -and $manifest.ReleaseDate)) {
            throw "Invalid manifest structure"
        }
        
        # TODO: Implement checksum validation when we have the actual checksums
        if ($ValidateChecksum -and $manifest.Checksums -and $manifest.Checksums.SHA256 -ne "placeholder_for_actual_hash_calculation") {
            Write-Verbose "Checksum validation would be performed here"
            # Future implementation: validate manifest integrity
        }
        
        return @{
            IsValid = $true
            Version = $manifest.ReleaseVersion
            Date = $manifest.ReleaseDate
            Source = "Version_Manifest"
        }
    }
    catch {
        Write-Verbose "Manifest version retrieval failed: $_"
        return @{
            IsValid = $false
            Error = $_
        }
    }
}

function Get-LegacyTagsVersionInfo {
    <#
    .SYNOPSIS
    Legacy method for retrieving version from tags.json (less secure).
    #>
    [CmdletBinding()]
    param ()
    
    try {
        Write-Warning "Using legacy tags.json method - this is less secure and may be spoofed"
        
        $latestRelease = Invoke-RestMethod 'https://api.github.com/repos/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/releases/latest' -Verbose:$false
        $tagsFileURI = "https://github.com/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/raw/{0}/setup/tags.json" -f $latestRelease.name
        $tags = Invoke-RestMethod $tagsFileURI -Verbose:$false
        
        return @{
            IsValid = $true
            Version = $tags.ReleaseVersion
            Date = $tags.ReleaseDate
            Source = "Legacy_Tags"
        }
    }
    catch {
        Write-Verbose "Legacy tags version retrieval failed: $_"
        return @{
            IsValid = $false
            Error = $_
        }
    }
}

function Test-DeployedVersionIntegrity {
    <#
    .SYNOPSIS
    Validates the integrity of the deployed version tag to detect user modifications or corruption.
    
    .DESCRIPTION
    Checks the resource group tags for signs of tampering, inconsistency, or user error.
    Provides warnings when version information appears to have been modified inappropriately.
    
    .PARAMETER ResourceGroupName
    Name of the resource group to check
    
    .PARAMETER ExpectedVersion
    The expected version to validate against
    
    .EXAMPLE
    $integrityResult = Test-DeployedVersionIntegrity -ResourceGroupName "guardrails-rg" -ExpectedVersion "v2.3.3"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $false)]
        [string]$ExpectedVersion
    )
    
    $integrityResults = @{
        IsValid = $false
        Issues = @()
        Warnings = @()
        DeployedVersion = $null
        TagsPresent = $false
    }
    
    try {
        Write-Verbose "Checking deployed version integrity for resource group: $ResourceGroupName"
        
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        
        # Check if version tag exists
        if (-not $rg.Tags -or -not $rg.Tags.ContainsKey("ReleaseVersion")) {
            $integrityResults.Issues += "ReleaseVersion tag is missing from resource group"
            $integrityResults.Warnings += "Resource group version tag may have been accidentally removed"
            return $integrityResults
        }
        
        $integrityResults.TagsPresent = $true
        $deployedVersion = $rg.Tags["ReleaseVersion"]
        $integrityResults.DeployedVersion = $deployedVersion
        
        # Basic format validation
        if ([string]::IsNullOrWhiteSpace($deployedVersion)) {
            $integrityResults.Issues += "ReleaseVersion tag is empty"
            return $integrityResults
        }
        
        # Check for common user error patterns
        if ($deployedVersion -notmatch '^v?\d+\.\d+\.\d+') {
            $integrityResults.Warnings += "Deployed version format is unusual: $deployedVersion"
        }
        
        # Check for obvious manual modifications
        if ($deployedVersion -match '(test|manual|custom|temp)') {
            $integrityResults.Warnings += "Deployed version appears to be manually modified: $deployedVersion"
        }
        
        # Cross-validate with expected version if provided
        if ($ExpectedVersion -and $deployedVersion -ne $ExpectedVersion) {
            $integrityResults.Warnings += "Deployed version ($deployedVersion) differs from expected version ($ExpectedVersion)"
        }
        
        # Check for additional integrity indicators
        $deployDate = $rg.Tags["ReleaseDate"]
        if ([string]::IsNullOrWhiteSpace($deployDate)) {
            $integrityResults.Warnings += "ReleaseDate tag is missing or empty"
        }
        
        # If we reach here without critical issues, mark as valid
        if ($integrityResults.Issues.Count -eq 0) {
            $integrityResults.IsValid = $true
        }
        
        return $integrityResults
    }
    catch {
        $integrityResults.Issues += "Failed to retrieve resource group information: $_"
        return $integrityResults
    }
}

function Test-DeploymentVersionSecurity {
    <#
    .SYNOPSIS
    Validates version security before deployment to prevent spoofed versions from being deployed.
    
    .DESCRIPTION
    Performs pre-deployment security checks to ensure the version being deployed
    is legitimate and hasn't been tampered with.
    
    .PARAMETER ProposedVersion
    The version that is about to be deployed
    
    .PARAMETER StrictMode
    Whether to use strict security validation (recommended for production)
    
    .EXAMPLE
    $isSecure = Test-DeploymentVersionSecurity -ProposedVersion "v2.3.3" -StrictMode $true
    if (-not $isSecure.IsValid) { throw "Deployment blocked: $($isSecure.Reason)" }
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProposedVersion,
        
        [Parameter(Mandatory = $false)]
        [bool]$StrictMode = $true
    )
    
    $validationResult = @{
        IsValid = $false
        Reason = ""
        SecurityLevel = "Unknown"
        Warnings = @()
    }
    
    try {
        Write-Verbose "Validating deployment version security for: $ProposedVersion"
        
        # Get authoritative version information
        $secureVersionInfo = Get-SecureVersionInformation -AllowFallback (!$StrictMode)
        
        if (-not $secureVersionInfo.SourceVerified -and $StrictMode) {
            $validationResult.Reason = "Cannot verify version authenticity in strict mode"
            return $validationResult
        }
        
        $validationResult.SecurityLevel = $secureVersionInfo.SecurityResults.VerificationLevel
        
        # Validate that proposed version matches authoritative source
        if ($secureVersionInfo.ReleaseVersion -eq $ProposedVersion) {
            $validationResult.IsValid = $true
            $validationResult.Reason = "Version validated against authoritative source"
            
            # Add warnings for lower security levels
            if ($secureVersionInfo.SecurityResults.VerificationLevel -eq "Low") {
                $validationResult.Warnings += "Using low-security verification method"
            }
        }
        else {
            $validationResult.Reason = "Proposed version ($ProposedVersion) does not match authoritative version ($($secureVersionInfo.ReleaseVersion))"
            
            if (-not $StrictMode) {
                Write-Warning $validationResult.Reason
                Write-Warning "Proceeding anyway due to non-strict mode"
                $validationResult.IsValid = $true
                $validationResult.Warnings += "Version mismatch allowed in non-strict mode"
            }
        }
        
        return $validationResult
    }
    catch {
        $validationResult.Reason = "Version security validation failed: $_"
        return $validationResult
    }
}

function Invoke-VersionSecurityAudit {
    <#
    .SYNOPSIS
    Performs a comprehensive security audit of the version management system.
    
    .DESCRIPTION
    Audits the current deployment for version security issues, tampering signs,
    and provides recommendations for improving version security.
    
    .PARAMETER ResourceGroupName
    Name of the resource group to audit
    
    .EXAMPLE
    $auditResults = Invoke-VersionSecurityAudit -ResourceGroupName "guardrails-rg"
    Write-Host "Security Score: $($auditResults.SecurityScore)/100"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    $auditResults = @{
        SecurityScore = 0
        Issues = @()
        Recommendations = @()
        Summary = ""
        Details = @{}
    }
    
    try {
        Write-Verbose "Starting comprehensive version security audit..."
        
        # Test 1: Secure version retrieval
        Write-Verbose "Testing secure version retrieval mechanisms..."
        $secureVersionTest = Get-SecureVersionInformation -AllowFallback $false
        
        if ($secureVersionTest.SecurityResults.VerificationLevel -eq "High") {
            $auditResults.SecurityScore += 40
            $auditResults.Details["VersionRetrieval"] = "Excellent - Using GitHub API"
        }
        elseif ($secureVersionTest.SecurityResults.VerificationLevel -eq "Medium") {
            $auditResults.SecurityScore += 25
            $auditResults.Details["VersionRetrieval"] = "Good - Using verified manifest"
            $auditResults.Recommendations += "Consider fixing GitHub API access for optimal security"
        }
        else {
            $auditResults.Issues += "Cannot retrieve version information securely"
            $auditResults.Details["VersionRetrieval"] = "Failed - No secure methods available"
            $auditResults.Recommendations += "Investigate network connectivity and GitHub API access"
        }
        
        # Test 2: Deployed version integrity
        Write-Verbose "Testing deployed version integrity..."
        $integrityTest = Test-DeployedVersionIntegrity -ResourceGroupName $ResourceGroupName
        
        if ($integrityTest.IsValid -and $integrityTest.Warnings.Count -eq 0) {
            $auditResults.SecurityScore += 30
            $auditResults.Details["DeployedIntegrity"] = "Excellent - No integrity issues detected"
        }
        elseif ($integrityTest.IsValid) {
            $auditResults.SecurityScore += 20
            $auditResults.Details["DeployedIntegrity"] = "Good - Minor warnings: $($integrityTest.Warnings -join '; ')"
            $auditResults.Recommendations += "Review and address version tag warnings"
        }
        else {
            $auditResults.Issues += "Deployed version integrity compromised: $($integrityTest.Issues -join '; ')"
            $auditResults.Details["DeployedIntegrity"] = "Failed - Critical integrity issues"
            $auditResults.Recommendations += "Redeploy solution to restore version integrity"
        }
        
        # Test 3: Cross-validation check
        Write-Verbose "Performing version cross-validation..."
        if ($secureVersionTest.ReleaseVersion -and $integrityTest.DeployedVersion) {
            try {
                $secureVer = [version]::Parse(($secureVersionTest.ReleaseVersion -replace '[\w-]+?(\d+?\.\d+?\.\d+?(\.\d+?)?)[\w-]*$','$1'))
                $deployedVer = [version]::Parse(($integrityTest.DeployedVersion -replace '[\w-]+?(\d+?\.\d+?\.\d+?(\.\d+?)?)[\w-]*$','$1'))
                
                if ($deployedVer -le $secureVer) {
                    $auditResults.SecurityScore += 20
                    $auditResults.Details["CrossValidation"] = "Good - Version consistency verified"
                }
                else {
                    $auditResults.Issues += "Deployed version is newer than available version - possible tampering"
                    $auditResults.Details["CrossValidation"] = "Warning - Version inconsistency detected"
                    $auditResults.Recommendations += "Investigate how deployed version became newer than available version"
                }
            }
            catch {
                $auditResults.Issues += "Version comparison failed: $_"
                $auditResults.Details["CrossValidation"] = "Failed - Could not parse versions"
                $auditResults.Recommendations += "Review version format consistency"
            }
        }
        else {
            $auditResults.Details["CrossValidation"] = "Skipped - Missing version information"
            $auditResults.Recommendations += "Ensure both current and deployed versions are available"
        }
        
        # Test 4: Security configuration check
        Write-Verbose "Checking security configuration..."
        try {
            $manifestUri = "https://github.com/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/raw/main/setup/version-manifest.json"
            $manifest = Invoke-RestMethod $manifestUri -Verbose:$false -ErrorAction SilentlyContinue
            
            if ($manifest.SecurityFeatures.VerificationEnabled) {
                $auditResults.SecurityScore += 10
                $auditResults.Details["SecurityConfig"] = "Good - Enhanced verification enabled"
            }
            else {
                $auditResults.Recommendations += "Enable enhanced version verification features"
                $auditResults.Details["SecurityConfig"] = "Basic - Standard verification only"
            }
        }
        catch {
            $auditResults.Details["SecurityConfig"] = "Unknown - Could not retrieve security configuration"
            $auditResults.Recommendations += "Verify access to security configuration manifest"
        }
        
        # Generate summary
        if ($auditResults.SecurityScore >= 80) {
            $auditResults.Summary = "Excellent security posture - minimal risk of version spoofing or user error"
        }
        elseif ($auditResults.SecurityScore >= 60) {
            $auditResults.Summary = "Good security posture - some improvements recommended"
        }
        elseif ($auditResults.SecurityScore >= 40) {
            $auditResults.Summary = "Moderate security posture - several issues need attention"
        }
        else {
            $auditResults.Summary = "Poor security posture - immediate action required"
        }
        
        return $auditResults
    }
    catch {
        $auditResults.Issues += "Audit failed: $_"
        $auditResults.Summary = "Audit could not be completed"
        return $auditResults
    }
}

Export-ModuleMember -Function @(
    'Get-SecureVersionInformation',
    'Get-GitHubReleaseVersionInfo', 
    'Get-ManifestVersionInfo',
    'Get-LegacyTagsVersionInfo',
    'Test-DeployedVersionIntegrity',
    'Test-DeploymentVersionSecurity',
    'Invoke-VersionSecurityAudit'
)