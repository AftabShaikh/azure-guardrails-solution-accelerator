# Azure Guardrails Tools

This directory contains administrative tools and utilities for managing Azure Guardrails deployments.

## Security Tools

### Check-VersionSecurity.ps1
**Purpose**: Administrative utility to assess version security posture

**Usage**:
```powershell
# Basic security check
.\Check-VersionSecurity.ps1 -ResourceGroupName "guardrails-rg"

# Generate detailed report
.\Check-VersionSecurity.ps1 -ResourceGroupName "guardrails-rg" -GenerateReport -ReportPath "C:\Reports"
```

**Features**:
- Tests resource group access and version tag integrity
- Evaluates secure version retrieval capabilities  
- Runs comprehensive security audit (0-100 score)
- Provides specific security recommendations
- Generates detailed JSON reports

**Requirements**:
- Azure PowerShell module
- Access to target resource group
- Internet connectivity for full security checks

**Output**: 
- Console display with color-coded results
- Optional detailed JSON report file
- Security score and recommendations

### Security Assessment Scoring

| Score Range | Security Level | Description |
|-------------|----------------|-------------|
| 80-100 | Excellent | Minimal risk, all security features active |
| 60-79 | Good | Acceptable with some improvements needed |
| 40-59 | Moderate | Action recommended to improve security |
| 0-39 | Poor | Immediate action required |

## Other Tools

### CentralView/
Contains tools for centralized monitoring and reporting across multiple Guardrails deployments.

### Update-ModuleVersions.ps1  
Utility for updating PowerShell module versions during development.

## Security Features Overview

The tools in this directory support the enhanced security features implemented for version management:

- **Anti-Spoofing Protection**: Multi-layered version verification
- **User Error Prevention**: Automated integrity checks and warnings
- **Security Monitoring**: Real-time assessment and audit capabilities
- **Compliance Reporting**: Detailed security posture documentation

For complete security documentation, see: `docs/VERSION-SECURITY.md`