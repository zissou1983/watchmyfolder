# Code Style & Conventions

## JavaScript (ES6)
- Class-based architecture
- camelCase for methods and variables
- Descriptive method names (renderCustomTabs, updateCustomDestination, etc.)
- Arrow functions for callbacks
- Async/await for asynchronous operations
- Error handling with try-catch blocks
- Console logging for debugging

## HTML/CSS
- CSS variables for theming (--primary-color, --bg-color, etc.)
- data-* attributes for element identification and state
- Semantic HTML structure
- BEM-like naming for classes (e.g., destination-card, tab-button)

## PowerShell
- Function-based organization
- Descriptive function names (TryRouteCustomTab, CheckFormatMatch)
- Comment documentation for complex logic
- Proper error handling with Write-Host/Write-Error

## Configuration
- JSON format for config storage
- UTF-8 encoding with BOM handling
- Nested object structure for destinations and formats
- Clear property naming

## IPC Communication Pattern
- electronAPI exposed via preload.js
- Promise-based async operations
- Error handling with .catch()
- Consistent method naming (openFolder, selectFolder)
