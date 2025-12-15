# Commands & Development Workflow

## Running the Application
```powershell
npm start                           # Start Electron app
npm run build                       # Build application
npm test                            # Run tests if available
```

## Development Commands
```powershell
# Clear processes and restart
taskkill /F /IM "electron.exe" 2>$null
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

# Start fresh
cd e:\GitHub\watchmyfolder
npm start
```

## System Commands (Windows PowerShell)
```powershell
Get-Process                         # List running processes
Stop-Process -Name electron -Force  # Kill electron process
Get-Content file.json               # Read file
Set-Content, Add-Content            # Write files
New-Item -Type Directory            # Create directories
```

## File Editing Workflow
1. Use symbolic tools (find_symbol, get_symbols_overview) to locate code
2. Use replace_string_in_file or multi_replace_string_in_file for edits
3. Reload app or restart with npm start to test changes
4. Verify in browser DevTools if needed

## Post-Task Verification
- Restart application: `npm start`
- Test in dashboard UI
- Check for console errors
- Verify config changes persist in config/config.json

## Important Ports
- 8082: HTTP API server (Node.js)
- 3000-3999: Available for testing/debugging
