const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const http = require('http');
const fs = require('fs');
const url = require('url');
const { spawn } = require('child_process');

let mainWindow;
let watcherProcess = null;
let isWatcherRunning = false;

// Helper function to get resource path (works for both dev and packaged)
function getResourcePath(relativePath) {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, relativePath);
  }
  return path.join(__dirname, relativePath);
}

// Simple API Server for config management
function startApiServer() {
  const server = http.createServer((req, res) => {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.setHeader('Content-Type', 'application/json');

    // Handle OPTIONS requests
    if (req.method === 'OPTIONS') {
      res.writeHead(200);
      res.end();
      return;
    }

    // Parse URL
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;

    try {
      if (pathname === '/api/config' && req.method === 'GET') {
        // Load config
        const configPath = getResourcePath(path.join('config', 'config.json'));
        if (fs.existsSync(configPath)) {
          let configContent = fs.readFileSync(configPath, 'utf8');
          // Remove BOM if present
          if (configContent.charCodeAt(0) === 0xFEFF) {
            configContent = configContent.slice(1);
          }
          const config = JSON.parse(configContent);
          res.writeHead(200);
          res.end(JSON.stringify(config));
        } else {
          res.writeHead(404);
          res.end(JSON.stringify({ error: 'Config not found' }));
        }
      } else if (pathname === '/api/config' && req.method === 'POST') {
        // Save config
        let body = '';
        req.on('data', chunk => {
          body += chunk.toString();
        });
        req.on('end', () => {
          try {
            const config = JSON.parse(body);
            const configPath = getResourcePath(path.join('config', 'config.json'));
            // Write without BOM
            fs.writeFileSync(configPath, JSON.stringify(config, null, 2), { encoding: 'utf8', flag: 'w' });
            res.writeHead(200);
            res.end(JSON.stringify({ success: true, message: 'Config saved' }));
          } catch (error) {
            res.writeHead(400);
            res.end(JSON.stringify({ success: false, error: error.message }));
          }
        });
      } else if (pathname === '/api/status' && req.method === 'GET') {
        res.writeHead(200);
        res.end(JSON.stringify({ 
          isRunning: true,
          status: 'Dashboard API running'
        }));
      } else {
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Endpoint not found' }));
      }
    } catch (error) {
      console.error('API Error:', error);
      res.writeHead(500);
      res.end(JSON.stringify({ error: error.message }));
    }
  });

  server.listen(8082, '127.0.0.1', () => {
    console.log('API Server running on http://127.0.0.1:8082');
  });

  server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
      console.error('Port 8082 is already in use');
    } else {
      console.error('Server error:', error);
    }
  });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      sandbox: true,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  // Set Content Security Policy
  mainWindow.webContents.session.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [
          "default-src 'self'; " +
          "script-src 'self'; " +
          "style-src 'self' 'unsafe-inline'; " +
          "img-src 'self' data:; " +
          "font-src 'self'; " +
          "connect-src 'self' http://127.0.0.1:8082"
        ]
      }
    });
  });

  // Load the dashboard
  mainWindow.loadFile('src/dashboard/index.html');

  // Open DevTools in development
  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  startApiServer();
  createWindow();
  
  // Auto-start the watcher service after window is created
  setTimeout(() => {
    console.log('Auto-starting watcher service...');
    startWatcherProcess();
  }, 2000);
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

// Handle folder selection
ipcMain.handle('select-folder', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory']
  });

  if (!result.canceled) {
    return result.filePaths[0];
  }
  return null;
});

// Handle opening folder in explorer
ipcMain.handle('open-folder', async (event, folderPath) => {
  try {
    const fs = require('fs');
    const path = require('path');
    const { shell } = require('electron');
    
    // Prüfe ob Ordner existiert
    if (!fs.existsSync(folderPath)) {
      console.log(`Folder does not exist, creating: ${folderPath}`);
      // Erstelle Ordner rekursiv
      fs.mkdirSync(folderPath, { recursive: true });
    }
    
    await shell.openPath(folderPath);
    return { success: true };
  } catch (error) {
    console.error('Error opening folder:', error);
    return { success: false, error: error.message };
  }
});

// Watcher control functions
function startWatcherProcess() {
  if (watcherProcess) {
    console.log('Watcher already running');
    return { success: false, error: 'Watcher already running' };
  }

  const configPath = getResourcePath(path.join('config', 'config.json'));
  const servicePath = getResourcePath(path.join('src', 'WatchFolderService.ps1'));
  const workingDir = getResourcePath('');

  console.log('Starting watcher process...');
  console.log('Config:', configPath);
  console.log('Service:', servicePath);
  console.log('Working Dir:', workingDir);

  watcherProcess = spawn('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', servicePath,
    '-ConfigPath', configPath
  ], {
    cwd: workingDir,
    windowsHide: false
  });

  watcherProcess.stdout.on('data', (data) => {
    const message = data.toString().trim();
    console.log('Watcher:', message);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('watcher-output', message);
    }
  });

  watcherProcess.stderr.on('data', (data) => {
    const errorMsg = data.toString().trim();
    console.error('Watcher Error:', errorMsg);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('watcher-error', errorMsg);
    }
  });

  watcherProcess.on('close', (code) => {
    console.log('Watcher process exited with code:', code);
    watcherProcess = null;
    isWatcherRunning = false;
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('watcher-status', { running: false, exitCode: code });
    }
  });

  watcherProcess.on('error', (error) => {
    console.error('Failed to start watcher:', error);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('watcher-error', `Start fehlgeschlagen: ${error.message}`);
    }
    watcherProcess = null;
    isWatcherRunning = false;
  });

  isWatcherRunning = true;
  return { success: true };
}

function stopWatcherProcess() {
  if (!watcherProcess) {
    console.log('No watcher process to stop');
    return { success: false, error: 'Watcher not running' };
  }

  console.log('Stopping watcher process...');
  
  // Send Ctrl+C signal to gracefully stop
  watcherProcess.kill('SIGINT');
  
  // Force kill after timeout
  setTimeout(() => {
    if (watcherProcess) {
      watcherProcess.kill('SIGKILL');
      watcherProcess = null;
    }
  }, 3000);

  isWatcherRunning = false;
  return { success: true };
}

// IPC handlers for watcher control
ipcMain.handle('start-watcher', async () => {
  const result = startWatcherProcess();
  if (result.success) {
    setTimeout(() => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('watcher-status', { running: true });
      }
    }, 1000);
  }
  return result;
});

ipcMain.handle('stop-watcher', async () => {
  const result = stopWatcherProcess();
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('watcher-status', { running: false });
  }
  return result;
});

ipcMain.handle('get-watcher-status', async () => {
  return { running: isWatcherRunning };
});

// Cleanup on app quit
app.on('before-quit', () => {
  if (watcherProcess) {
    watcherProcess.kill();
  }
});