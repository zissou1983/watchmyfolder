# WatchMyFolder Project Overview

## Purpose
WatchMyFolder is an Electron-based application for monitoring watch folders and intelligently routing files to destinations based on configurable rules. It provides a dashboard UI for managing watch folders, file format filters, text-based filtering, and destination folders.

## Tech Stack
- **Frontend**: Electron + Vanilla JavaScript (ES6 class-based)
- **Backend**: PowerShell (RoutingEngine.ps1) for file routing logic
- **API Server**: Node.js HTTP server integrated in main.js (port 8082)
- **Configuration**: JSON-based storage at `config/config.json`
- **UI Framework**: CSS variables with Dark/Light mode support

## Project Structure
```
src/
  dashboard/
    dashboard-enhanced.js    # Main dashboard controller (1000+ lines)
    index.html              # Dashboard UI template
    styles.css              # Theme and styling
  PowerShell/
    RoutingEngine.ps1       # File routing logic with CustomTabs support
main.js                     # Electron main process with API server
preload.js                  # IPC bridge for secure communication
package.json
config/config.json          # Application configuration
```

## Key Features
- Custom watch folder tabs
- Per-destination format filtering
- Text-based file filtering with case-sensitivity option
- "Ignorieren" (delete) functionality
- "Restliche Dateien" (handle remaining) checkbox
- Dark/Light mode toggle
- "Open Folder" in Explorer functionality
- Configuration persistence via HTTP API

## Important Code Components
1. **dashboard-enhanced.js**: Main UI controller with rendering functions and event handling
2. **RoutingEngine.ps1**: PowerShell routing with CustomTab support
3. **main.js**: HTTP API server endpoints and IPC handlers
4. **preload.js**: Electron IPC bridge exposing openFolder() and selectFolder()

## Known Issues & Solutions
- Event listener duplication fixed using Event Delegation pattern
- setupFormatHandlers() replaced with setupGlobalEventDelegation()
- Port 8082 conflicts resolved with process cleanup
