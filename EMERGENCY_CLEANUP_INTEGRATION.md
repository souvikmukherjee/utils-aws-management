# Emergency Cleanup Integration

## Overview

The `test-infrastructure.sh` script has been enhanced to automatically call the emergency cleanup script when it fails at any point during execution. This ensures that no AWS resources are left orphaned, preventing unexpected costs.

## How It Works

### 1. **Dual Cleanup Strategy**
When the test script fails, it implements a two-tier cleanup approach:

1. **State-based Cleanup**: Uses the `.test-infrastructure-state.json` file to clean up resources that were tracked during creation
2. **Emergency Cleanup**: Calls `emergency-cleanup.sh` to catch any orphaned resources that might not be in the state file

### 2. **Automatic Triggering**
The emergency cleanup is automatically triggered by:
- **Script errors** (ERR trap)
- **User interruption** (INT/TERM trap)
- **Any exit with non-zero status**

### 3. **Enhanced Error Handling**
```bash
# Trap handlers for cleanup
trap 'print_error "🛑 Script interrupted or failed. Starting emergency cleanup..."; cleanup_on_failure; exit 1' ERR
trap 'print_error "🛑 Script interrupted by user. Starting emergency cleanup..."; cleanup_on_failure; exit 1' INT TERM
```

## Cleanup Process

### Phase 1: State-based Cleanup
- Reads resources from `.test-infrastructure-state.json`
- Deletes resources in reverse order of creation
- Handles RDS, Redis, EC2, Security Groups, Key Pairs, Subnet Groups, and Cognito resources

### Phase 2: Emergency Cleanup
- Executes `./aws/resources/master/emergency-cleanup.sh`
- Searches for any resources with `_test` suffix
- Provides comprehensive cleanup even without state file

## Logging and Reporting

### Cleanup Log
- All cleanup actions are logged to `.test-cleanup.log`
- Includes timestamps and resource details
- Captures both state-based and emergency cleanup actions

### Failure Report
When the script fails, it generates `TEST_FAILURE_REPORT.md` containing:
- Failure timestamp and phase
- Resources created before failure
- Cleanup status and actions taken
- Next steps for manual intervention

## Benefits

1. **Cost Protection**: Prevents orphaned AWS resources from incurring charges
2. **Automatic Recovery**: No manual intervention required for cleanup
3. **Comprehensive Coverage**: Dual cleanup strategy catches all resources
4. **Detailed Logging**: Full audit trail of cleanup actions
5. **Failure Analysis**: Clear reports for debugging and improvement

## Usage

The enhanced cleanup is automatic - no changes needed to your workflow:

```bash
# Run the test infrastructure script
./aws/resources/master/test-infrastructure.sh

# If it fails, emergency cleanup runs automatically
# Check TEST_FAILURE_REPORT.md for details
```

## Manual Emergency Cleanup

If you need to run emergency cleanup manually:

```bash
./aws/resources/master/emergency-cleanup.sh
```

## Safety Features

- **Non-blocking**: Emergency cleanup continues even if some resources fail to delete
- **Error tolerance**: Individual resource deletion failures don't stop the process
- **Logging**: All actions are logged for audit purposes
- **State preservation**: State file is updated with cleanup status

## Testing the Integration

To test the emergency cleanup integration:

1. Start the test infrastructure script
2. Interrupt it with Ctrl+C during any phase
3. Verify that emergency cleanup runs automatically
4. Check the generated reports and logs
5. Verify no orphaned resources remain in AWS 