# Version Security Enhancements

## Overview

This document describes the security enhancements implemented to address spoofing and user error protections for Azure CaC (Compliance as Code) version numbering.

## Problem Statement

The original Azure CaC versioning system had two main security vulnerabilities:

1. **Spoofing Vulnerability**: Version information was retrieved from `tags.json` which could be easily manipulated by changing git tags
2. **User Error Prone**: Resource group tags containing version information could be accidentally modified or removed by administrators

## Solution Architecture

### Multi-Layered Version Verification

The new secure versioning system implements multiple verification layers:

#### 1. Primary Source: GitHub Release API
- **Source**: `GET /repos/ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator/releases/latest`
- **Security Level**: High
- **Benefits**: 
  - Harder to spoof than raw file access
  - Authenticated API endpoint
  - Structured response validation

#### 2. Secondary Source: Version Manifest with Checksums
- **Source**: `setup/version-manifest.json`
- **Security Level**: Medium
- **Benefits**:
  - Includes integrity checksums
  - Enhanced metadata validation
  - Fallback when API is unavailable

#### 3. Fallback Source: Legacy Tags (Optional)
- **Source**: `setup/tags.json` 
- **Security Level**: Low
- **Usage**: Only when explicitly enabled with warnings

### Enhanced Security Features

#### Anti-Spoofing Measures
- **GitHub API Verification**: Uses official GitHub Release API as primary source
- **Cross-Reference Validation**: Compares multiple sources for consistency
- **Checksum Validation**: Verifies file integrity using SHA-256 hashes
- **Deployment Version Validation**: Validates version before deployment

#### User Error Prevention
- **Automated Integrity Checks**: Detects when resource group tags have been modified
- **Version Format Validation**: Ensures version strings follow expected patterns
- **Warning on Manual Modifications**: Alerts when tags appear manually changed
- **Audit Trail**: Enhanced logging of version verification results

## Implementation Details

### New Security Module

**File**: `src/Guardrails-Common/SecureVersioning.psm1`

#### Core Functions

##### `Get-SecureVersionInformation`
- Main function for secure version retrieval
- Implements multi-layered verification
- Returns security level and verification status

##### `Get-GitHubReleaseVersionInfo`
- Retrieves version from GitHub Release API
- Validates response structure
- Extracts version and date information

##### `Get-ManifestVersionInfo`
- Retrieves version from enhanced manifest
- Validates checksums (when available)
- Provides medium-security fallback

##### `Test-DeployedVersionIntegrity`
- Validates deployed version tags
- Detects signs of user modification
- Provides integrity assessment

##### `Test-DeploymentVersionSecurity`
- Pre-deployment security validation
- Prevents spoofed versions from being deployed
- Supports strict and non-strict modes

##### `Invoke-VersionSecurityAudit`
- Comprehensive security audit
- Generates security score (0-100)
- Provides recommendations

### Enhanced Logging

The updated system provides enhanced logging with security context:

```json
{
  "DeployedVersion": "v2.3.3beta2",
  "AvailableVersion": "v2.3.3",
  "UpdateNeeded": true,
  "SecurityLevel": "High",
  "VerificationSource": "GitHub_Release_API", 
  "IntegrityVerified": true,
  "SecurityWarnings": "",
  "VersionComparison": "Update available"
}
```

## Security Levels

### High Security (Recommended)
- **Method**: GitHub Release API
- **Verification**: Full API validation
- **Risk**: Minimal spoofing risk
- **Use Case**: Production deployments

### Medium Security 
- **Method**: Version manifest with checksums
- **Verification**: Checksum validation
- **Risk**: Low spoofing risk
- **Use Case**: API unavailable scenarios

### Low Security (Deprecated)
- **Method**: Legacy tags.json
- **Verification**: Basic format validation
- **Risk**: High spoofing risk  
- **Use Case**: Emergency fallback only

## Migration Guide

### For Existing Deployments

1. **Update PowerShell Modules**: The new security module is automatically imported
2. **Verify Functionality**: Run version security audit
3. **Review Logs**: Check for security warnings in deployment logs
4. **Optional**: Enable strict mode for maximum security

### For New Deployments

New deployments automatically use the enhanced security features with no additional configuration required.

## Configuration Options

### Strict Mode
- **Purpose**: Maximum security validation
- **Effect**: Blocks deployment if version cannot be securely verified
- **Default**: Disabled (for compatibility)
- **Recommendation**: Enable for production environments

### Fallback Options
- **Legacy Fallback**: Allow use of tags.json when secure methods fail
- **Checksum Validation**: Enable/disable manifest checksum verification
- **Warning Suppression**: Control warning verbosity

## Monitoring and Alerting

### Security Warnings
The system generates warnings for:
- Version integrity issues
- Manual tag modifications
- Failed security verifications
- Use of low-security methods

### Audit Capabilities
- **Security Score**: 0-100 assessment of version security posture
- **Detailed Analysis**: Per-component security evaluation  
- **Recommendations**: Specific improvement suggestions
- **Trend Monitoring**: Track security posture over time

## API Reference

### Security Assessment
```powershell
# Run comprehensive security audit
$auditResults = Invoke-VersionSecurityAudit -ResourceGroupName "guardrails-rg"

# Check deployment security
$isSecure = Test-DeploymentVersionSecurity -ProposedVersion "v2.3.3"

# Validate deployed version integrity  
$integrity = Test-DeployedVersionIntegrity -ResourceGroupName "guardrails-rg"
```

### Secure Version Retrieval
```powershell  
# Get version with high security
$versionInfo = Get-SecureVersionInformation -AllowFallback $false

# Get version with fallback allowed
$versionInfo = Get-SecureVersionInformation -AllowFallback $true
```

## Best Practices

### For Administrators
1. **Regular Audits**: Run security audits monthly
2. **Monitor Warnings**: Investigate all security warnings
3. **Avoid Manual Edits**: Don't manually modify version tags
4. **Use Strict Mode**: Enable in production environments

### For Developers
1. **Handle Failures**: Gracefully handle verification failures  
2. **Log Security Events**: Log all security-related decisions
3. **Validate Input**: Always validate version formats
4. **Test Scenarios**: Test with different security levels

## Troubleshooting

### Common Issues

#### GitHub API Unavailable
- **Symptom**: Cannot retrieve version from GitHub API
- **Solution**: System automatically falls back to manifest verification
- **Prevention**: Ensure network connectivity to GitHub

#### Version Mismatch
- **Symptom**: Deployed version differs from authoritative version
- **Solution**: Investigate source of version modification
- **Prevention**: Use read-only deployment credentials

#### Integrity Warnings
- **Symptom**: Resource group tags appear modified
- **Solution**: Redeploy solution to restore integrity
- **Prevention**: Restrict resource group permissions

### Debug Commands

```powershell
# Check version retrieval methods
Get-GitHubReleaseVersionInfo -Verbose
Get-ManifestVersionInfo -Verbose  
Get-LegacyTagsVersionInfo -Verbose

# Test deployment security
Test-DeploymentVersionSecurity -ProposedVersion "v2.3.3" -StrictMode $true
```

## Security Considerations

### Threat Model
- **Malicious Actor**: Cannot easily spoof versions due to API verification
- **Accidental Modification**: System detects and warns about integrity issues
- **Network Issues**: Graceful fallback maintains functionality
- **Configuration Errors**: Enhanced validation prevents deployment errors

### Limitations  
- **Network Dependency**: Highest security requires GitHub API access
- **Trust Model**: Relies on GitHub's security for authoritative versions
- **Backward Compatibility**: Legacy fallback reduces security for compatibility

## Future Enhancements

### Planned Improvements
1. **Digital Signatures**: Cryptographic signing of version manifests
2. **Certificate Validation**: PKI-based version verification
3. **Blockchain Ledger**: Immutable version history
4. **AI Anomaly Detection**: Machine learning-based tampering detection

### Feedback and Contributions
Please submit security enhancement suggestions through the standard GitHub issue process with the "security" label.