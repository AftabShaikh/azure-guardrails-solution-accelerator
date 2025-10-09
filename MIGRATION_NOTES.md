# Migration from OMSIngestionAPI to Azure Monitor Logs Ingestion API

## Overview
This project has been updated to replace the deprecated `OMSIngestionAPI` PowerShell module with the modern Azure Monitor Logs Ingestion API approach. The HTTP Data Collector API used by OMSIngestionAPI will be retired on **September 14, 2026**.

## Changes Made

### 1. Module Replacement
**Files Updated:**
- `/setup/IaC/modules/automationaccount.bicep`: Replaced OMSIngestionAPI 1.6.0 with Az.Monitor 6.0.3
- `/tools/CentralView/requirements.psd1`: Updated module dependencies

### 2. Compatibility Function
**Files Updated:**
- `/src/Guardrails-Common/GR-Common.psm1`: Added `Send-OMSAPIIngestionFile` compatibility function
- `/tools/CentralView/Modules/ingest-tenantsData/ingest-tenantsData.psm1`: Added `Send-OMSAPIIngestionFile` compatibility function

### 3. Function Behavior
The new `Send-OMSAPIIngestionFile` function:
- Maintains the same interface as the original OMSIngestionAPI function
- Uses the HTTP Data Collector API directly (same underlying API as OMSIngestionAPI)
- Preserves all existing functionality without breaking changes
- Includes error handling and verbose logging

## Current Status
✅ **Phase 1: Compatibility Layer (Current)**
- Removed dependency on deprecated OMSIngestionAPI module
- Implemented compatibility function using HTTP Data Collector API directly
- No breaking changes to existing code
- All existing functionality preserved

## Future Migration Path

### Phase 2: Data Collection Rules (Recommended for Future)
For optimal future-proofing, consider migrating to the new Azure Monitor Data Collection API:

1. **Setup Data Collection Endpoints (DCEs)**
2. **Create Data Collection Rules (DCRs)**  
3. **Update functions to use `Invoke-AzRestMethod` with DCR endpoints**
4. **Replace workspace ID/key authentication with managed identity**

### Benefits of Future Migration to DCRs:
- Better security (managed identity vs shared keys)
- Enhanced data transformation capabilities
- Improved performance and reliability
- Future-proof architecture
- Better integration with Azure Resource Manager

## Testing
The current implementation maintains 100% backward compatibility. All existing:
- Function parameters
- Return values  
- Error handling
- Log formats

remain unchanged.

## Dependencies Updated
- **Az.Accounts**: Updated to 4.1.0 (required for Az.Monitor 6.0.3)
- **Az.Monitor**: Added 6.0.3 (replacement for OMSIngestionAPI)

## Notes
- The HTTP Data Collector API will continue to work until September 14, 2026
- This migration provides a smooth transition path with no immediate breaking changes
- Consider planning for Data Collection Rules migration before the 2026 deadline