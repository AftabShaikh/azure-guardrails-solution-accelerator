<#
.SYNOPSIS
Administrative utility to check Azure Guardrails version security posture.

.DESCRIPTION
This script helps administrators quickly assess the security of their Azure Guardrails
version management system and provides recommendations for improvement.

.PARAMETER ResourceGroupName
Name of the Azure resource group containing the Guardrails deployment.

.PARAMETER GenerateReport
Generate a detailed security report file.

.PARAMETER ReportPath
Path where to save the security report (default: current directory).

.EXAMPLE
.\Check-VersionSecurity.ps1 -ResourceGroupName "guardrails-rg"

.EXAMPLE
.\Check-VersionSecurity.ps1 -ResourceGroupName "guardrails-rg" -GenerateReport -ReportPath "C:\Reports"

.NOTES
This tool requires:
- Azure PowerShell module
- Access to the specified resource group
- Internet connectivity for secure version verification
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "."
)

# Import required modules
try {
    Write-Host "Loading Azure Guardrails Security Modules..." -ForegroundColor Blue
    
    $secureVersioningPath = Join-Path $PSScriptRoot "../src/Guardrails-Common/SecureVersioning.psm1"
    if (Test-Path $secureVersioningPath) {
        Import-Module $secureVersioningPath -Force
        Write-Host "✓ Secure Versioning module loaded" -ForegroundColor Green
    }
    else {
        Write-Warning "Secure Versioning module not found. Some features may be unavailable."
    }
}
catch {
    Write-Error "Failed to load required modules: $_"
    exit 1
}

# Check if user is connected to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Please connect to Azure first using Connect-AzAccount" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Connected to Azure subscription: $($context.Subscription.Name)" -ForegroundColor Green
}
catch {
    Write-Host "Please install and configure Azure PowerShell module" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Azure Guardrails Version Security Assessment ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Assessment Time: $(Get-Date)" -ForegroundColor Yellow

# Initialize report data
$reportData = @{
    ResourceGroup = $ResourceGroupName
    AssessmentTime = Get-Date
    Results = @{}
    Recommendations = @()
    SecurityScore = 0
}

# Test 1: Resource Group Existence and Access
Write-Host "`n1. Testing Resource Group Access..." -ForegroundColor Blue
try {
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    Write-Host "   ✓ Resource group found and accessible" -ForegroundColor Green
    $reportData.Results["ResourceGroupAccess"] = "Success"
}
catch {
    Write-Host "   ✗ Cannot access resource group: $_" -ForegroundColor Red
    $reportData.Results["ResourceGroupAccess"] = "Failed: $_"
    exit 1
}

# Test 2: Version Tag Validation
Write-Host "`n2. Checking Deployed Version Integrity..." -ForegroundColor Blue
if (Get-Command Test-DeployedVersionIntegrity -ErrorAction SilentlyContinue) {
    try {
        $integrityResults = Test-DeployedVersionIntegrity -ResourceGroupName $ResourceGroupName
        
        if ($integrityResults.IsValid) {
            Write-Host "   ✓ Deployed version integrity validated" -ForegroundColor Green
            $reportData.SecurityScore += 25
        }
        else {
            Write-Host "   ✗ Deployed version integrity issues detected" -ForegroundColor Red
            foreach ($issue in $integrityResults.Issues) {
                Write-Host "     - $issue" -ForegroundColor Red
            }
        }
        
        if ($integrityResults.Warnings.Count -gt 0) {
            Write-Host "   ⚠ Integrity warnings:" -ForegroundColor Yellow
            foreach ($warning in $integrityResults.Warnings) {
                Write-Host "     - $warning" -ForegroundColor Yellow
                $reportData.Recommendations += $warning
            }
        }
        
        $reportData.Results["IntegrityCheck"] = $integrityResults
    }
    catch {
        Write-Host "   ✗ Integrity check failed: $_" -ForegroundColor Red
        $reportData.Results["IntegrityCheck"] = "Failed: $_"
    }
}
else {
    Write-Host "   ⚠ Secure versioning module not available - using basic check" -ForegroundColor Yellow
    
    # Basic version tag check
    if ($resourceGroup.Tags -and $resourceGroup.Tags.ContainsKey("ReleaseVersion")) {
        $deployedVersion = $resourceGroup.Tags["ReleaseVersion"]
        Write-Host "   ✓ Version tag present: $deployedVersion" -ForegroundColor Green
        $reportData.SecurityScore += 10
        
        if ($deployedVersion -match '^v?\d+\.\d+\.\d+') {
            Write-Host "   ✓ Version format appears valid" -ForegroundColor Green
        }
        else {
            Write-Host "   ⚠ Version format may be invalid: $deployedVersion" -ForegroundColor Yellow
            $reportData.Recommendations += "Review version format: $deployedVersion"
        }
    }
    else {
        Write-Host "   ✗ Version tag missing from resource group" -ForegroundColor Red
        $reportData.Recommendations += "Version tag is missing - redeploy solution"
    }
}

# Test 3: Secure Version Retrieval
Write-Host "`n3. Testing Secure Version Retrieval..." -ForegroundColor Blue
if (Get-Command Get-SecureVersionInformation -ErrorAction SilentlyContinue) {
    try {
        $secureVersionInfo = Get-SecureVersionInformation -AllowFallback $true
        
        if ($secureVersionInfo.SourceVerified) {
            Write-Host "   ✓ Secure version retrieval successful" -ForegroundColor Green
            Write-Host "     Security Level: $($secureVersionInfo.SecurityResults.VerificationLevel)" -ForegroundColor Cyan
            Write-Host "     Source: $($secureVersionInfo.SecurityResults.SourceUsed)" -ForegroundColor Cyan
            
            switch ($secureVersionInfo.SecurityResults.VerificationLevel) {
                "High" { $reportData.SecurityScore += 40 }
                "Medium" { $reportData.SecurityScore += 25 }
                "Low" { $reportData.SecurityScore += 10 }
            }
        }
        else {
            Write-Host "   ✗ Secure version retrieval failed" -ForegroundColor Red
            $reportData.Recommendations += "Investigate network connectivity and GitHub API access"
        }
        
        if ($secureVersionInfo.SecurityResults.SecurityWarnings.Count -gt 0) {
            Write-Host "   ⚠ Security warnings:" -ForegroundColor Yellow
            foreach ($warning in $secureVersionInfo.SecurityResults.SecurityWarnings) {
                Write-Host "     - $warning" -ForegroundColor Yellow
                $reportData.Recommendations += $warning
            }
        }
        
        $reportData.Results["SecureVersionRetrieval"] = $secureVersionInfo
    }
    catch {
        Write-Host "   ✗ Secure version retrieval test failed: $_" -ForegroundColor Red
        $reportData.Results["SecureVersionRetrieval"] = "Failed: $_"
    }
}
else {
    Write-Host "   ⚠ Secure versioning functions not available" -ForegroundColor Yellow
    $reportData.Recommendations += "Deploy updated Guardrails version with security enhancements"
}

# Test 4: Comprehensive Security Audit
Write-Host "`n4. Running Comprehensive Security Audit..." -ForegroundColor Blue
if (Get-Command Invoke-VersionSecurityAudit -ErrorAction SilentlyContinue) {
    try {
        $auditResults = Invoke-VersionSecurityAudit -ResourceGroupName $ResourceGroupName
        
        Write-Host "   Security Score: $($auditResults.SecurityScore)/100" -ForegroundColor Cyan
        Write-Host "   Summary: $($auditResults.Summary)" -ForegroundColor Cyan
        
        $reportData.SecurityScore = $auditResults.SecurityScore
        $reportData.Results["SecurityAudit"] = $auditResults
        
        if ($auditResults.Issues.Count -gt 0) {
            Write-Host "   Issues detected:" -ForegroundColor Red
            foreach ($issue in $auditResults.Issues) {
                Write-Host "     - $issue" -ForegroundColor Red
            }
        }
        
        if ($auditResults.Recommendations.Count -gt 0) {
            $reportData.Recommendations += $auditResults.Recommendations
        }
    }
    catch {
        Write-Host "   ✗ Security audit failed: $_" -ForegroundColor Red
        $reportData.Results["SecurityAudit"] = "Failed: $_"
    }
}
else {
    Write-Host "   ⚠ Security audit function not available" -ForegroundColor Yellow
}

# Display Summary
Write-Host "`n=== ASSESSMENT SUMMARY ===" -ForegroundColor Cyan
Write-Host "Overall Security Score: $($reportData.SecurityScore)/100" -ForegroundColor $(
    if ($reportData.SecurityScore -ge 80) { "Green" }
    elseif ($reportData.SecurityScore -ge 60) { "Yellow" }
    else { "Red" }
)

if ($reportData.SecurityScore -ge 80) {
    Write-Host "✓ Excellent security posture" -ForegroundColor Green
}
elseif ($reportData.SecurityScore -ge 60) {
    Write-Host "⚠ Good security posture with room for improvement" -ForegroundColor Yellow
}
elseif ($reportData.SecurityScore -ge 40) {
    Write-Host "⚠ Moderate security posture - action recommended" -ForegroundColor Yellow
}
else {
    Write-Host "✗ Poor security posture - immediate action required" -ForegroundColor Red
}

# Display Recommendations
if ($reportData.Recommendations.Count -gt 0) {
    Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Cyan
    foreach ($recommendation in ($reportData.Recommendations | Sort-Object -Unique)) {
        Write-Host "• $recommendation" -ForegroundColor Yellow
    }
}

# Generate Report File
if ($GenerateReport) {
    Write-Host "`nGenerating detailed report..." -ForegroundColor Blue
    
    $reportFile = Join-Path $ReportPath "GuardrailsVersionSecurityReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    
    try {
        $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
        Write-Host "✓ Report saved to: $reportFile" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to save report: $_" -ForegroundColor Red
    }
}

Write-Host "`nAssessment completed at $(Get-Date)" -ForegroundColor Blue