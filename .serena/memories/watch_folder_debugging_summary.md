# Watch Folder Debugging Summary

## Problem
Files placed in `C:\Temp\Incoming\` are NOT moved to destination folders (e.g., `C:\Temp\Night\`), despite the Watch Folder Service starting successfully without errors.

## Investigation Path

### Issue 1: FileSystemWatcher Events Not Triggering ✅ SOLVED
- **Root Cause**: PowerShell `Register-ObjectEvent` with `.GetNewClosure()` doesn't properly capture class instance (`$this`) when used with class methods
- **Solution**: Changed architecture to call `PollForChanges()` and `ProcessQueue()` directly from main loop instead of using timer events
- **Implementation**: Modified `WatchFolderService.ps1` main loop to call methods on 10-second interval for polling, 5-second for queue processing

### Issue 2: GracePeriod Configuration ⚠️ CHECKED
- **Finding**: Config had `GracePeriod: 30` (30 seconds before file considered ready)
- **Action**: Changed to `GracePeriod: 3` to allow faster testing
- **Status**: Not the root cause - tested with 20+ second waits still shows no files processed

### Issue 3: File Processing Chain Not Complete ❌ STILL UNRESOLVED
- **Code Flow**:
  1. `PollForChanges()` - Detects files, adds to queue
  2. `ProcessQueue()` - Gets file from queue
  3. `IsFileReady()` - Checks if file is ready (grace period, not locked, size stable)
  4. `ProcessFile()` - Calls `OnFileReady()`
  5. `OnFileReady()` - Invokes `FileReadyCallback` → `RoutingEngine.RouteFile()`
  6. `RoutingEngine.RouteFile()` - Should move file to destination

- **Current Behavior**: No errors reported, but files never appear in Night folder
- **Likely Issues**:
  - `ProcessQueue()` not being called (despite error handling showing no exceptions)
  - `IsFileReady()` always returning false (but no errors logged)
  - Files moved but not to correct destination
  - RoutingEngine.RouteFile() failing silently

## Terminal Issues
- Multiple PowerShell Terminal IDs getting "stuck" with old processes
- Terminal output buffering causes old output to appear instead of new test results
- Created separate batch file (test-watch.bat) as workaround but shell output still shows old data

## Next Steps (BLOCKED)
1. Add explicit error logging to ProcessQueue() loop
2. Check if RoutingEngine.RouteFile() is working correctly
3. Verify that files are actually being moved (might be to wrong location)
4. Check if Routing Rules in config match test file formats

## Key Code Locations
- WatchFolderService.ps1: Lines 161-209 (main loop with polling)
- WatchEngine.ps1: Lines 215-250 (PollForChanges), Lines 325-350 (ProcessQueue), Lines 362-410 (IsFileReady), Lines 536-572 (ProcessFile/OnFileReady)
- Config: `GracePeriod` changed from 30 to 3 seconds
