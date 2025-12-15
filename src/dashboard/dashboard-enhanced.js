// Enhanced Watch Folder Dashboard
class WatchFolderDashboardEnhanced {
    constructor() {
        this.apiBaseUrl = this.getApiBaseUrl();
        this.config = {};
        this.workingConfig = {};
        this.originalConfig = {};
        this.dialogActive = false;  // Track if dialog is open
        this.init();
    }

    getApiBaseUrl() {
        if (window.location.protocol === 'file:') {
            // Electron app - use 127.0.0.1 which is more reliable than localhost
            return 'http://127.0.0.1:8082/api';
        }
        return window.location.origin + '/api';
    }

    async init() {
        // Load theme preference
        this.loadThemePreference();
        
        // Load configuration
        await this.loadConfig();
        
        // Initialize UI
        this.initializeTabs();
        this.renderStandardTab();
        this.renderCustomTabs();
        this.renderOptionsTab();
        
        // Always show Standard tab on startup
        this.switchTab('standard');
        
        // Setup global event delegation (nur einmal!)
        this.setupGlobalEventDelegation();
        
        // Setup static button event listeners (CSP-compliant)
        this.setupStaticEventListeners();
    }
    
    setupStaticEventListeners() {
        // Browse Watch Path Button
        const browseBtn = document.getElementById('browseWatchPathBtn');
        if (browseBtn) {
            browseBtn.addEventListener('click', () => this.browseFolder('watchPath'));
        }
        
        // Open Standard Watch Folder Button
        const openFolderBtn = document.getElementById('openStandardWatchFolderBtn');
        if (openFolderBtn) {
            openFolderBtn.addEventListener('click', () => this.openStandardWatchFolder());
        }
        
        // Night Batch Toggle
        const nightBatchToggle = document.getElementById('nightBatchEnabled');
        if (nightBatchToggle) {
            nightBatchToggle.addEventListener('change', () => this.toggleNightBatchUI());
        }
        
        // Save Standard Config Button
        const saveStandardBtn = document.getElementById('saveStandardConfigBtn');
        if (saveStandardBtn) {
            saveStandardBtn.addEventListener('click', () => this.saveStandardConfig());
        }
        
        // Reset Standard Config Button
        const resetStandardBtn = document.getElementById('resetStandardConfigBtn');
        if (resetStandardBtn) {
            resetStandardBtn.addEventListener('click', () => this.resetStandardConfig());
        }
        
        // Dark Mode Toggle
        const darkModeToggle = document.getElementById('darkModeOption');
        if (darkModeToggle) {
            darkModeToggle.addEventListener('change', () => this.saveDarkModePreference());
        }
        
        // Autostart Toggle
        const autostartToggle = document.getElementById('autostartOption');
        if (autostartToggle) {
            autostartToggle.addEventListener('change', () => this.saveAutostartOption());
        }
        
        // Save All Options Button
        const saveAllBtn = document.getElementById('saveAllOptionsBtn');
        if (saveAllBtn) {
            saveAllBtn.addEventListener('click', () => this.saveAllOptions());
        }
        
        // Toggle Watch Button
        const toggleWatchBtn = document.getElementById('toggleWatchBtn');
        if (toggleWatchBtn) {
            toggleWatchBtn.addEventListener('click', () => this.toggleWatcher());
        }
        
        // Listen for watcher status updates from main process
        if (window.electronAPI && window.electronAPI.onWatcherStatus) {
            window.electronAPI.onWatcherStatus((status) => {
                this.updateWatcherUI(status.running);
                if (status.exitCode !== undefined && status.exitCode !== 0) {
                    this.showErrorLog(`Service beendet mit Exit-Code: ${status.exitCode}`);
                }
            });
        }
        
        // Listen for watcher errors
        if (window.electronAPI && window.electronAPI.onWatcherError) {
            window.electronAPI.onWatcherError((error) => {
                this.showErrorLog(error);
            });
        }
        
        // Listen for watcher output
        if (window.electronAPI && window.electronAPI.onWatcherOutput) {
            window.electronAPI.onWatcherOutput((output) => {
                this.appendToLog(output);
            });
        }
        
        // Check initial watcher status
        this.checkWatcherStatus();
    }
    
    async checkWatcherStatus() {
        if (window.electronAPI && window.electronAPI.getWatcherStatus) {
            try {
                const status = await window.electronAPI.getWatcherStatus();
                this.updateWatcherUI(status.running);
            } catch (error) {
                this.updateWatcherUI(false);
            }
        }
    }
    
    async toggleWatcher() {
        const btn = document.getElementById('toggleWatchBtn');
        if (!btn) return;
        
        const isRunning = btn.classList.contains('running');
        btn.disabled = true;
        btn.textContent = isRunning ? '⏳ Stoppe...' : '⏳ Starte...';
        
        try {
            if (window.electronAPI) {
                if (isRunning) {
                    await window.electronAPI.stopWatcher();
                } else {
                    this.clearLog();
                    this.appendToLog('Starte Watcher-Service...');
                    await window.electronAPI.startWatcher();
                }
            } else {
                // Fallback: Simuliere Status-Wechsel
                this.updateWatcherUI(!isRunning);
            }
        } catch (error) {
            this.showErrorLog('Fehler: ' + error.message);
        } finally {
            btn.disabled = false;
        }
    }
    
    // Error-Log Funktionen
    showErrorLog(message) {
        const logArea = this.getOrCreateLogArea();
        const timestamp = new Date().toLocaleTimeString('de-DE');
        logArea.innerHTML += `<div style="color: #ff6b6b;">[${timestamp}] ❌ ${message}</div>`;
        logArea.scrollTop = logArea.scrollHeight;
    }
    
    appendToLog(message) {
        const logArea = this.getOrCreateLogArea();
        const timestamp = new Date().toLocaleTimeString('de-DE');
        logArea.innerHTML += `<div>[${timestamp}] ${message}</div>`;
        logArea.scrollTop = logArea.scrollHeight;
        // Limit log entries
        while (logArea.children.length > 100) {
            logArea.removeChild(logArea.firstChild);
        }
    }
    
    clearLog() {
        const logArea = document.getElementById('serviceLogArea');
        if (logArea) logArea.innerHTML = '';
    }
    
    getOrCreateLogArea() {
        let logArea = document.getElementById('serviceLogArea');
        if (!logArea) {
            // Create log area in the status section
            const statusSection = document.querySelector('.status-section') || document.querySelector('.card');
            if (statusSection) {
                const logContainer = document.createElement('div');
                logContainer.innerHTML = `
                    <h4 style="margin-top: 15px; color: #888;">Service Log</h4>
                    <div id="serviceLogArea" style="
                        background: #1a1a1a;
                        border: 1px solid #333;
                        border-radius: 4px;
                        padding: 10px;
                        max-height: 200px;
                        overflow-y: auto;
                        font-family: monospace;
                        font-size: 12px;
                        color: #aaa;
                    "></div>
                `;
                statusSection.appendChild(logContainer);
                logArea = document.getElementById('serviceLogArea');
            }
        }
        return logArea;
    }
    
    updateWatcherUI(isRunning) {
        const btn = document.getElementById('toggleWatchBtn');
        
        if (btn) {
            btn.classList.toggle('running', isRunning);
            btn.textContent = isRunning ? '⏹ Überwachung stoppen' : '▶ Überwachung starten';
        }
    }
    
    async browseFolder(inputId) {
        const input = document.getElementById(inputId);
        if (!input) return;

        if (window.electronAPI && window.electronAPI.selectFolder) {
            const path = await window.electronAPI.selectFolder();
            if (path) {
                input.value = path;
                input.dispatchEvent(new Event('change'));
            }
        } else {
            const newPath = prompt('Ordner-Pfad eingeben:', input.value || 'C:\\Temp');
            if (newPath && newPath.trim()) {
                input.value = newPath.trim();
                input.dispatchEvent(new Event('change'));
            }
        }
    }
    
    saveDarkModePreference() {
        const darkMode = document.getElementById('darkModeOption')?.checked || false;
        localStorage.setItem('darkMode', darkMode);
        document.body.classList.toggle('dark-mode', darkMode);
    }
    
    saveAutostartOption() {
        const autostart = document.getElementById('autostartOption')?.checked || false;
        if (this.config.Options) {
            this.config.Options.Autostart = autostart;
            this.saveConfig();
        }
    }
    
    saveAllOptions() {
        this.saveDarkModePreference();
        this.saveAutostartOption();
        alert('Optionen gespeichert!');
    }

    setupGlobalEventDelegation() {
        // Event delegation für alle dynamisch erstellten Elemente
        document.addEventListener('click', (e) => {
            const target = e.target;
            
            // SKIP events from dialogs
            if (target.closest('[data-dialog-id]')) {
                return;
            }
            
            const action = target.getAttribute('data-action');
            if (!action) return;
            
            e.preventDefault();
            
            switch (action) {
                case 'openFolder': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    const destName = target.getAttribute('data-dest-name');
                    const pathInput = document.getElementById(`customPath_${tabIndex}_${destName}`);
                    if (pathInput && pathInput.value) {
                        window.electronAPI?.openFolder(pathInput.value);
                    }
                    break;
                }
                
                case 'openStandardFolder': {
                    const destName = target.getAttribute('data-dest-name');
                    const pathInput = document.getElementById(`path_${destName}`);
                    if (pathInput && pathInput.value) {
                        window.electronAPI?.openFolder(pathInput.value);
                    }
                    break;
                }
                
                case 'openWatchFolder': {
                    const watchIndex = parseInt(target.getAttribute('data-watch-index'));
                    this.openWatchFolder(watchIndex);
                    break;
                }
                
                case 'browseStandardFolder':
                case 'browseCustomWatchFolder':
                case 'browseCustomPath': {
                    const inputId = target.getAttribute('data-input-id');
                    this.browseFolder(inputId);
                    break;
                }
                
                case 'removeStandardFormat': {
                    const destName = target.getAttribute('data-dest-name');
                    const format = target.getAttribute('data-format');
                    this.removeFormat(destName, format);
                    break;
                }
                
                case 'addStandardFormat': {
                    const destName = target.getAttribute('data-dest-name');
                    this.addFormat(destName);
                    break;
                }
                
                case 'removeFormat': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    const destName = target.getAttribute('data-dest-name');
                    const format = target.getAttribute('data-format');
                    this.removeCustomFormat(tabIndex, destName, format);
                    break;
                }
                
                case 'addFormat': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    const destName = target.getAttribute('data-dest-name');
                    this.addCustomFormat(tabIndex, destName);
                    break;
                }
                
                case 'removeDestination': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    const destName = target.getAttribute('data-dest-name');
                    this.removeDestinationFromCustomTab(tabIndex, destName);
                    break;
                }
                
                case 'removeCustomTab': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    this.removeCustomTab(tabIndex);
                    break;
                }
                
                case 'saveCustomTab': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    this.saveCustomTab(tabIndex);
                    break;
                }
                
                case 'resetCustomTab': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    this.resetCustomTab(tabIndex);
                    break;
                }
                
                case 'addDestinationToCustomTab': {
                    const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                    this.addDestinationToCustomTab(tabIndex);
                    break;
                }
                
                case 'refreshHistory': {
                    this.loadHistory();
                    break;
                }
                
                case 'clearHistory': {
                    this.clearHistory();
                    break;
                }
                
                case 'toggleWatch': {
                    this.toggleWatcher();
                    break;
                }
            }
        });

        // Event delegation für change events
        document.addEventListener('change', (e) => {
            const target = e.target;
            
            // SKIP events from dialogs
            if (target.closest('[data-dialog-id]')) {
                return;
            }
            
            // Standard path inputs
            if (target.classList.contains('standard-path-input')) {
                const destName = target.getAttribute('data-dest-name');
                this.updateDestination(destName, 'Path', target.value);
            }

            // Path input changes (custom destinations)
            if (target.classList.contains('path-input')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                const destName = target.getAttribute('data-dest-name');
                if (!isNaN(tabIndex) && destName) {
                    this.updateCustomDestination(tabIndex, destName, 'Path', target.value);
                }
            }
            
            // Custom watch folder inputs
            if (target.classList.contains('custom-watch-folder-input')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                this.updateCustomTab(tabIndex, 'WatchFolder', target.value);
            }
            
            // Custom recursive checkbox
            if (target.classList.contains('custom-recursive-checkbox')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                this.updateCustomTab(tabIndex, 'RecursiveWatch', target.checked);
            }
            
            // Custom grace period input
            if (target.classList.contains('custom-grace-period-input')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                this.updateCustomTab(tabIndex, 'GracePeriod', parseInt(target.value));
            }
            
            // Custom night batch checkbox
            if (target.classList.contains('custom-night-batch-checkbox')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                this.updateCustomTabAndRerender(tabIndex, 'NightBatchEnabled', target.checked);
            }
            
            // Custom night start input
            if (target.classList.contains('custom-night-start-input')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                this.updateCustomTab(tabIndex, 'NightBatchStartTime', target.value);
            }
            
            // Custom night end input
            if (target.classList.contains('custom-night-end-input')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                this.updateCustomTab(tabIndex, 'NightBatchEndTime', target.value);
            }

            // Ignore checkboxes
            if (target.classList.contains('ignore-checkbox')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                const destName = target.getAttribute('data-dest-name');
                this.updateCustomDestination(tabIndex, destName, 'IsIgnore', target.checked);
            }

            // Rest checkboxes
            if (target.classList.contains('rest-checkbox')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                const destName = target.getAttribute('data-dest-name');
                this.updateCustomDestination(tabIndex, destName, 'HandleRest', target.checked);
            }

            // Text filter inputs
            if (target.classList.contains('text-filter-input')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                const destName = target.getAttribute('data-dest-name');
                this.updateCustomDestination(tabIndex, destName, 'TextFilter', target.value);
            }

            // Case sensitivity checkboxes
            if (target.classList.contains('case-checkbox')) {
                const tabIndex = parseInt(target.getAttribute('data-tab-index'));
                const destName = target.getAttribute('data-dest-name');
                this.updateCustomDestination(tabIndex, destName, 'CaseSensitive', target.checked);
            }
        });

        // Keypress event delegation für Enter-Taste
        document.addEventListener('keypress', (e) => {
            // SKIP events from dialogs
            if (e.target.closest('[data-dialog-id]')) {
                return;
            }
            
            if (e.key === 'Enter') {
                // Standard format inputs
                if (e.target.id && e.target.id.startsWith('newformat_')) {
                    const destName = e.target.id.replace('newformat_', '');
                    this.addFormat(destName);
                }

                // Custom format inputs
                if (e.target.id && e.target.id.startsWith('customNewformat_')) {
                    const parts = e.target.id.replace('customNewformat_', '').split('_');
                    const tabIndex = parseInt(parts[0]);
                    const destName = parts.slice(1).join('_');
                    this.addCustomFormat(tabIndex, destName);
                }
            }
        });
        
        // Keydown event delegation - auch Dialog ausschließen
        document.addEventListener('keydown', (e) => {
            // SKIP events from dialogs
            if (e.target.closest('[data-dialog-id]')) {
                return;
            }
            
            // Rest of keydown handling if needed
        });
    }

    // Theme Management
    loadThemePreference() {
        const isDarkMode = localStorage.getItem('wf_darkMode') === 'true';
        if (isDarkMode) {
            document.body.classList.add('dark-mode');
        }
        const darkModeCheckbox = document.getElementById('darkModeOption');
        if (darkModeCheckbox) {
            darkModeCheckbox.checked = isDarkMode;
        }
    }

    saveDarkModePreference() {
        const checkbox = document.getElementById('darkModeOption');
        document.body.classList.toggle('dark-mode', checkbox.checked);
        localStorage.setItem('wf_darkMode', checkbox.checked);
        const btn = document.getElementById('themeToggle');
        btn.textContent = checkbox.checked ? '☀️ Light Mode' : '🌙 Dark Mode';
    }

    // Configuration Management
    async loadConfig() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/config`);
            if (!response.ok) throw new Error(`Failed to load config: ${response.status}`);
            
            this.originalConfig = await response.json();
            
            // Stelle sicher, dass Formate geladen werden
            if (!this.originalConfig.Formats) {
                this.originalConfig.Formats = {
                    "MAM": [".mxf", ".mp4", ".mov", ".mts", ".m2ts", ".ts", ".m4v", ".mkv", ".webm", ".mpg", ".mpeg", ".avi", ".3gp", ".divx", ".dv", ".flv", ".m2t", ".vob", ".wmv"],
                    "BOX": [".wav", ".aif", ".aiff", ".mp3", ".flac", ".m4a", ".ogg", ".pdf", ".doc", ".docx", ".txt", ".xlsx", ".pptx", ".jpg", ".jpeg", ".png", ".tiff", ".psd", ".raw", ".dng", ".aep", ".prproj", ".drp", ".edl", ".aaf", ".omf"],
                    "SYSTEM": [".tmp", ".log", ".cache", ".db", ".ini", ".sys", ".bim", ".cpi", ".pek", ".xmp", ".xml"]
                };
            }
            
            // Stelle sicher, dass CustomTabs existiert
            if (!this.originalConfig.CustomTabs) {
                this.originalConfig.CustomTabs = [];
            }
            
            // Stelle sicher, dass Options existiert
            if (!this.originalConfig.Options) {
                this.originalConfig.Options = {
                    "Autostart": false,
                    "Theme": "light",
                    "NightBatchStartTime": "20:00",
                    "NightBatchEndTime": "06:00"
                };
            }
            
            this.config = JSON.parse(JSON.stringify(this.originalConfig));
            this.workingConfig = JSON.parse(JSON.stringify(this.originalConfig));
            
            
            return true;
        } catch (error) {
            console.error('Error loading configuration:', error);
            this.showMessage('Fehler beim Laden der Konfiguration', 'error');
            return false;
        }
    }

    async saveConfig() {
        try {
            
            const response = await fetch(`${this.apiBaseUrl}/config`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.workingConfig)
            });

            if (!response.ok) {
                console.warn(`API returned status ${response.status}, attempting fallback...`);
                // Fallback: speichere in localStorage
                localStorage.setItem('wf_config', JSON.stringify(this.workingConfig));
                
            } else {
                const result = await response.json();
                
                if (!result.success) {
                    throw new Error(result.error || 'Unknown error');
                }
            }
            
            this.originalConfig = JSON.parse(JSON.stringify(this.workingConfig));
            this.config = JSON.parse(JSON.stringify(this.workingConfig));
            this.showMessage('Konfiguration erfolgreich gespeichert', 'success');
            return true;
        } catch (error) {
            console.error('Error saving configuration:', error);
            // Fallback: speichere in localStorage auch bei Fehler
            try {
                localStorage.setItem('wf_config', JSON.stringify(this.workingConfig));
                this.originalConfig = JSON.parse(JSON.stringify(this.workingConfig));
                this.config = JSON.parse(JSON.stringify(this.workingConfig));
                this.showMessage('Konfiguration lokal gespeichert', 'success');
                return true;
            } catch (localError) {
                this.showMessage('Fehler beim Speichern: ' + error.message, 'error');
                return false;
            }
        }
    }

    // Tab Management
    initializeTabs() {
        const tabSystem = document.getElementById('tabSystem');
        tabSystem.innerHTML = '';

        // Standard Tab
        const standardTabBtn = document.createElement('button');
        standardTabBtn.className = 'tab-button active';
        standardTabBtn.textContent = '📂 Standard';
        standardTabBtn.id = 'tabBtn_standard';
        standardTabBtn.onclick = () => this.switchTab('standard');
        tabSystem.appendChild(standardTabBtn);

        // Custom Tabs
        if (this.config.CustomTabs && this.config.CustomTabs.length > 0) {
            this.config.CustomTabs.forEach((tab, index) => {
                const tabBtn = document.createElement('button');
                tabBtn.className = 'tab-button custom';
                tabBtn.id = `tabBtn_custom_${index}`;
                tabBtn.textContent = tab.Name;
                tabBtn.onclick = () => this.switchTab(`custom_${index}`);
                tabSystem.appendChild(tabBtn);
            });
        }

        // Add New Tab Button
        const addTabBtn = document.createElement('button');
        addTabBtn.className = 'tab-button tab-add-btn';
        // Create SVG plus icon instead of text
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('width', '20');
        svg.setAttribute('height', '20');
        svg.setAttribute('viewBox', '0 0 20 20');
        svg.setAttribute('fill', 'none');
        svg.style.display = 'block';
        
        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        circle.setAttribute('cx', '10');
        circle.setAttribute('cy', '10');
        circle.setAttribute('r', '9');
        circle.setAttribute('fill', '#3498db');
        
        const lineH = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        lineH.setAttribute('x1', '10');
        lineH.setAttribute('y1', '5');
        lineH.setAttribute('x2', '10');
        lineH.setAttribute('y2', '15');
        lineH.setAttribute('stroke', 'white');
        lineH.setAttribute('stroke-width', '2');
        lineH.setAttribute('stroke-linecap', 'round');
        
        const lineV = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        lineV.setAttribute('x1', '5');
        lineV.setAttribute('y1', '10');
        lineV.setAttribute('x2', '15');
        lineV.setAttribute('y2', '10');
        lineV.setAttribute('stroke', 'white');
        lineV.setAttribute('stroke-width', '2');
        lineV.setAttribute('stroke-linecap', 'round');
        
        svg.appendChild(circle);
        svg.appendChild(lineH);
        svg.appendChild(lineV);
        addTabBtn.appendChild(svg);
        
        addTabBtn.title = 'Neuen Tab hinzufügen';
        addTabBtn.onclick = () => this.addCustomTab();
        tabSystem.appendChild(addTabBtn);

        // History Tab
        const historyTabBtn = document.createElement('button');
        historyTabBtn.className = 'tab-button';
        historyTabBtn.id = 'tabBtn_history';
        historyTabBtn.textContent = '📋 Verlauf';
        historyTabBtn.onclick = () => this.switchTab('history');
        tabSystem.appendChild(historyTabBtn);

        // Options Tab (always last, aligned right)
        const optionsTabBtn = document.createElement('button');
        optionsTabBtn.className = 'tab-button tab-options-btn';
        optionsTabBtn.id = 'tabBtn_options';
        optionsTabBtn.textContent = '⚙️';
        optionsTabBtn.title = 'Optionen';
        optionsTabBtn.onclick = () => this.switchTab('options');
        tabSystem.appendChild(optionsTabBtn);
    }

    switchTab(tabId) {
        // Hide all tabs
        document.querySelectorAll('.tab-content').forEach(tab => {
            tab.classList.remove('active');
        });

        // Remove active class from all buttons
        document.querySelectorAll('.tab-button').forEach(btn => {
            btn.classList.remove('active');
        });

        // Show selected tab and activate button
        let targetButton = null;
        
        if (tabId === 'standard') {
            const tab = document.getElementById('standardTab');
            if (tab) tab.classList.add('active');
            targetButton = document.getElementById('tabBtn_standard');
        } else if (tabId === 'options') {
            const tab = document.getElementById('optionsTab');
            if (tab) tab.classList.add('active');
            targetButton = document.getElementById('tabBtn_options');
        } else if (tabId === 'history') {
            const tab = document.getElementById('historyTab');
            if (tab) tab.classList.add('active');
            targetButton = document.getElementById('tabBtn_history');
            // Auto-refresh history when tab is opened
            this.loadHistory();
        } else if (tabId.startsWith('custom_')) {
            const index = parseInt(tabId.split('_')[1]);
            const tabContent = document.getElementById(`customTab_${index}`);
            if (tabContent) {
                tabContent.classList.add('active');
                targetButton = document.getElementById(`tabBtn_custom_${index}`);
            }
        }
        
        if (targetButton) {
            targetButton.classList.add('active');
        }
    }

    addCustomTab() {
        // Prevent multiple dialogs
        if (this.dialogActive) {
            return;
        }
        
        this.dialogActive = true;
        
        // Remove ALL previous dialogs
        const oldOverlays = document.querySelectorAll('[data-dialog-id]');
        oldOverlays.forEach(el => {
            el.remove();
        });
        
        // Create a unique dialog ID to prevent interference
        const dialogId = 'dialog_' + Date.now();
        
        // Create dialog container with full isolation
        const container = document.createElement('div');
        container.setAttribute('data-dialog-id', dialogId);
        container.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 99999;
            pointer-events: auto;
            font-family: inherit;
        `;
        
        // Create dialog box
        const dialogBox = document.createElement('div');
        dialogBox.style.cssText = `
            background: var(--bg-primary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            width: 90%;
            max-width: 400px;
            pointer-events: auto;
            font-family: inherit;
        `;
        
        // Header
        const header = document.createElement('div');
        header.style.cssText = `
            padding: 20px;
            border-bottom: 1px solid var(--border-color);
            font-size: 18px;
            font-weight: bold;
            color: var(--text-primary);
            pointer-events: auto;
        `;
        header.textContent = 'Neuen Tab hinzufügen';
        
        // Body
        const body = document.createElement('div');
        body.style.cssText = `
            padding: 20px;
            pointer-events: auto;
        `;
        
        const label = document.createElement('label');
        label.style.cssText = `
            display: block;
            margin-bottom: 10px;
            color: var(--text-primary);
            font-weight: 500;
            pointer-events: auto;
        `;
        label.textContent = 'Name des neuen Tabs:';
        
        // INPUT - with maximal clarity
        const input = document.createElement('input');
        input.type = 'text';
        input.placeholder = 'z.B. Archive, Backup, etc.';
        input.autocomplete = 'off';
        input.spellcheck = 'false';
        input.style.cssText = `
            display: block;
            width: calc(100% - 22px);
            box-sizing: border-box;
            padding: 10px 11px;
            margin: 0;
            border: 1px solid var(--border-color);
            border-radius: 4px;
            background: var(--bg-secondary);
            color: var(--text-primary);
            font-size: 14px;
            font-family: inherit;
            pointer-events: auto !important;
            cursor: text !important;
            user-select: text !important;
            -webkit-user-select: text !important;
            -moz-user-select: text !important;
            -ms-user-select: text !important;
        `;
        
        // Remove all appearance overrides
        input.style.webkitAppearance = 'none';
        input.style.MozAppearance = 'none';
        input.style.appearance = 'none';
        
        const hint = document.createElement('small');
        hint.style.cssText = `
            display: block;
            margin-top: 8px;
            color: var(--text-secondary);
            pointer-events: auto;
        `;
        hint.textContent = 'Buchstaben, Zahlen und Unterstriche erlaubt';
        
        body.appendChild(label);
        body.appendChild(input);
        body.appendChild(hint);
        
        // Footer
        const footer = document.createElement('div');
        footer.style.cssText = `
            padding: 15px 20px;
            border-top: 1px solid var(--border-color);
            display: flex;
            gap: 10px;
            justify-content: flex-end;
            pointer-events: auto;
        `;
        
        const cancelBtn = document.createElement('button');
        cancelBtn.type = 'button';
        cancelBtn.className = 'btn btn-warning';
        cancelBtn.textContent = 'Abbrechen';
        cancelBtn.style.cssText = 'cursor: pointer; pointer-events: auto !important;';
        
        const confirmBtn = document.createElement('button');
        confirmBtn.type = 'button';
        confirmBtn.className = 'btn btn-success';
        confirmBtn.textContent = 'Erstellen';
        confirmBtn.style.cssText = 'cursor: pointer; pointer-events: auto !important;';
        
        footer.appendChild(cancelBtn);
        footer.appendChild(confirmBtn);
        
        dialogBox.appendChild(header);
        dialogBox.appendChild(body);
        dialogBox.appendChild(footer);
        container.appendChild(dialogBox);
        
        // Add to DOM FIRST
        document.body.appendChild(container);
        
        // Verify input is in DOM
        const inputInDOM = body.querySelector('input[type="text"]');
        
        // THEN set up handlers
        const closeDialog = () => {
            if (container.parentNode) {
                container.remove();
            }
            this.dialogActive = false;
        };
        
        const handleConfirm = () => {
            const name = input.value.trim();
            
            if (!name) {
                this.showMessage('Bitte geben Sie einen Namen ein', 'error');
                input.focus();
                return;
            }
            
            const cleanName = name.replace(/[^A-Za-z0-9_]/g, '_');
            
            if (!this.config.CustomTabs) {
                this.config.CustomTabs = [];
            }
            
            if (this.config.CustomTabs.some(tab => tab.Name.toLowerCase() === cleanName.toLowerCase())) {
                this.showMessage('Tab mit diesem Namen existiert bereits', 'error');
                input.focus();
                return;
            }
            
            const newTab = {
                Name: cleanName,
                WatchFolder: 'C:\\Temp\\' + cleanName,
                GracePeriod: 30,
                Destinations: {},
                Formats: {}
            };
            
            this.config.CustomTabs.push(newTab);
            this.workingConfig.CustomTabs = JSON.parse(JSON.stringify(this.config.CustomTabs));
            
            closeDialog();
            
            this.initializeTabs();
            this.renderCustomTabs();
            this.renderOptionsTab();
            this.switchTab(`custom_${this.config.CustomTabs.length - 1}`);
            
            this.saveConfig();
            this.showMessage(`Tab "${cleanName}" erstellt`, 'success');
        };
        
        
        
        cancelBtn.addEventListener('click', (e) => {
            
            e.preventDefault();
            e.stopPropagation();
            closeDialog();
        }, false);  // bubbling phase
        
        confirmBtn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            handleConfirm();
        }, false);  // bubbling phase
        
        // WICHTIG: Nur preventDefault auf Enter/Escape, NICHT stopPropagation!
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                // NICHT stopPropagation() - das blockiert die Texteingabe!
                handleConfirm();
            } else if (e.key === 'Escape') {
                e.preventDefault();
                closeDialog();
            }
            // Alle anderen Keys: nichts machen - Browser macht seinen Job!
        }, false);  // WICHTIG: false = bubbling phase, nicht capture!
        
        // INPUT event - wird NACH keydown abgefeuert wenn Text geändert wird
        input.addEventListener('input', (e) => {
        }, false);
        
        container.addEventListener('click', (e) => {
            if (e.target === container) {
                e.preventDefault();
                e.stopPropagation();
                closeDialog();
            }
        }, false);  // bubbling phase
        
        // Focus IMMEDIATELY
        input.focus();
        input.select();
    }

    removeCustomTab(index) {
        if (!confirm('Diesen Tab wirklich entfernen?')) return;

        this.config.CustomTabs.splice(index, 1);
        this.workingConfig.CustomTabs = JSON.parse(JSON.stringify(this.config.CustomTabs));

        this.initializeTabs();
        this.renderCustomTabs();
        this.switchTab('standard');
        this.saveConfig();
    }

    // Rendering Methods
    renderStandardTab() {
        const container = document.getElementById('standardDestinations');
        if (!container) return;
        
        // Stelle sicher, dass Formate vorhanden sind
        if (!this.config.Formats) {
            this.config.Formats = {
                "MAM": [".mxf", ".mp4", ".mov", ".mts", ".m2ts", ".ts", ".m4v", ".mkv", ".webm", ".mpg", ".mpeg", ".avi", ".3gp", ".divx", ".dv", ".flv", ".m2t", ".vob", ".wmv"],
                "BOX": [".wav", ".aif", ".aiff", ".mp3", ".flac", ".m4a", ".ogg", ".pdf", ".doc", ".docx", ".txt", ".xlsx", ".pptx", ".jpg", ".jpeg", ".png", ".tiff", ".psd", ".raw", ".dng", ".aep", ".prproj", ".drp", ".edl", ".aaf", ".omf"],
                "SYSTEM": [".tmp", ".log", ".cache", ".db", ".ini", ".sys", ".bim", ".cpi", ".pek", ".xmp", ".xml"]
            };
        }
        
        // Load Nachtverarbeitung settings
        const options = this.config.Options || {};
        const nightBatchCheckbox = document.getElementById('nightBatchEnabled');
        const nightBatchStartInput = document.getElementById('nightBatchStartTime');
        const nightBatchEndInput = document.getElementById('nightBatchEndTime');
        const nightBatchTimeInputs = document.getElementById('nightBatchTimeInputs');
        const nightBatchStatus = document.getElementById('nightBatchStatus');
        
        if (nightBatchCheckbox) {
            nightBatchCheckbox.checked = options.NightBatchEnabled || false;
        }
        if (nightBatchStartInput) {
            nightBatchStartInput.value = options.NightBatchStartTime || '20:00';
        }
        if (nightBatchEndInput) {
            nightBatchEndInput.value = options.NightBatchEndTime || '06:00';
        }
        if (nightBatchTimeInputs && nightBatchStatus) {
            if (options.NightBatchEnabled) {
                nightBatchTimeInputs.style.display = 'block';
                nightBatchStatus.textContent = 'Aktiviert';
            } else {
                nightBatchTimeInputs.style.display = 'none';
                nightBatchStatus.textContent = 'Deaktiviert';
            }
        }
        
        // MAM Destination
        let html = '<div class="destination-grid">';
        html += this.renderDestinationCard('MAM', 'MAM (Medien-Archive)', '#e74c3c', '#fdf2f2');
        html += this.renderDestinationCard('BOX', 'BOX (Dokumente)', '#f39c12', '#fefbf3');
        html += '</div>';
        html += '<div class="destination-grid">';
        html += this.renderDestinationCard('SYSTEM', 'SYSTEM (werden ignoriert)', '#95a5a6', '#f8f9fa', true);
        html += this.renderDestinationCard('Quarantine', 'Quarantäne', '#e67e22', '#fdf4e3');
        html += '</div>';

        container.innerHTML = html;
    }

    renderDestinationCard(name, displayName, color, bgColor, isSystem = false) {
        const dest = this.config.destinations?.[name] || {};
        const formats = this.config.Formats?.[name] || [];

        

        let html = `<div class="destination-card" style="border-color: ${color};">`;
        html += `<div class="destination-card-title">`;
        html += `<h3 style="color: ${color};">${displayName}</h3>`;
        html += `</div>`;

        if (!isSystem && name !== 'SYSTEM') {
            html += `<div class="config-item">`;
            html += `<div style="display: flex; align-items: center; gap: 6px;">`;
            html += `<strong>Zielordner:</strong>`;
            const tooltip = name === 'Quarantine' 
                ? 'Der Ordner, in dem verdächtige oder infizierte Dateien isoliert werden (automatisch befüllt)'
                : 'Der Ordner, in den die unten angegebenen Dateien verschoben werden';
            html += `<span class="tooltip-icon" data-tooltip="${tooltip}">?</span>`;
            html += `</div>`;
            const path = dest.Path || `C:\\Temp\\${name}`;
            html += `<div class="form-row">`;
            html += `<input type="text" value="${path}" id="path_${name}" class="standard-path-input" data-dest-name="${name}">`;
            html += `<button class="btn btn-small" data-action="browseStandardFolder" data-input-id="path_${name}">Wählen</button>`;
            html += `<button class="btn btn-small" data-action="openStandardFolder" data-dest-name="${name}" title="Ordner im Explorer öffnen">📁 Öffnen</button>`;
            html += `</div>`;
            html += `</div>`;
        }

        if (name !== 'Quarantine') {
            html += `<div class="config-item">`;
            html += `<div style="display: flex; align-items: center; gap: 6px;">`;
            html += `<strong>${name === 'SYSTEM' ? 'Ignorierte Dateiformate:' : 'Dateiformate:'}</strong>`;
            html += `<span class="tooltip-icon" data-tooltip="Dateiendungen (z.B. .doc, .pdf) die in diesen Ordner verschoben werden sollen. Mehrere durch Komma getrennt.">?</span>`;
            html += `</div>`;
            html += `<div id="formats_${name}" style="display: flex; flex-wrap: wrap; gap: 5px; margin: 10px 0;">`;
            
            if (formats && formats.length > 0) {
                formats.forEach(format => {
                    html += `<span class="format-tag" data-category="${name}" data-format="${format}">`;
                    html += `${format} <span class="remove-format" data-action="removeStandardFormat" data-dest-name="${name}" data-format="${format}">×</span>`;
                    html += `</span>`;
                });
            } else {
                html += `<span style="color: var(--text-secondary); font-size: 12px;">Keine Formate konfiguriert</span>`;
            }
            
            html += `</div>`;
            html += `<div class="form-row">`;
            html += `<input type="text" id="newformat_${name}" placeholder="Format eingeben" style="width: 150px;">`;
            html += `<button class="btn btn-small" data-action="addStandardFormat" data-dest-name="${name}">Hinzufügen</button>`;
            html += `</div>`;
            html += `</div>`;
        }

        html += `</div>`;
        return html;
    }

    renderCustomTabs() {
        try {
            // Remember current active tab
            const currentActiveTab = document.querySelector('.tab-content.active');
            let currentTabId = currentActiveTab?.id || null;
            
            const container = document.getElementById('customTabsContainer');
            if (!container) {
                console.error('customTabsContainer not found');
                return;
            }
            
            container.innerHTML = '';

            if (!this.config.CustomTabs || this.config.CustomTabs.length === 0) {
                
                return;
            }

            this.config.CustomTabs.forEach((tab, index) => {
                
                
                try {
                    const tabContent = document.createElement('div');
                    tabContent.className = 'tab-content';
                    tabContent.id = `customTab_${index}`;

                    let html = `<div class="card">`;
                    html += `<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">`;
                    html += `<h2 style="margin: 0;">⚙️ ${tab.Name} - Konfiguration</h2>`;
                    html += `<button class="btn-close-tab" data-action="removeCustomTab" data-tab-index="${index}" title="Tab löschen">✕</button>`;
                    html += `</div>`;
                    
                    html += `<div class="config-item">`;
                    html += `<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">`;
                    html += `<div>`;
                    html += `<div style="display: flex; align-items: center; gap: 6px;">`;
                    html += `<strong>Watch Folder:</strong>`;
                    html += `<span class="tooltip-icon" data-tooltip="Der Ordner, der überwacht werden soll. Neue Dateien hier werden automatisch weitergeleitet.">?</span>`;
                    html += `</div>`;
                    html += `<div class="form-row" style="margin-top: 8px;">`;
                    html += `<input type="text" value="${tab.WatchFolder || 'C:\\\\Temp\\\\' + tab.Name}" id="watchFolder_${index}" class="custom-watch-folder-input" data-tab-index="${index}">`;
                    html += `<button class="btn btn-small" data-action="browseCustomWatchFolder" data-input-id="watchFolder_${index}">Wählen</button>`;
                    html += `<button class="btn btn-small" style="background-color: #3498db;" data-action="openWatchFolder" data-watch-index="${index}">📁 Öffnen</button>`;
                    html += `</div>`;
                    html += `</div>`;
                    html += `<div>`;
                    html += `<div style="display: flex; align-items: center; gap: 6px;">`;
                    html += `<strong>Rekursive Überwachung:</strong>`;
                    html += `<span class="tooltip-icon" data-tooltip="Wenn aktiviert, werden auch Dateien in Unterordnern des Watch Folders überwacht.">?</span>`;
                    html += `</div>`;
                    html += `<label style="display: flex; align-items: center; gap: 8px; margin-top: 8px;">`;
                    html += `<input type="checkbox" id="recursiveWatch_${index}" ${tab.RecursiveWatch !== false ? 'checked' : ''} class="custom-recursive-checkbox" data-tab-index="${index}">`;
                    html += `<span>Unterordner überwachen</span>`;
                    html += `</label>`;
                    html += `</div>`;
                    html += `</div>`;
                    html += `</div>`;

                    html += `<div class="config-item">`;
                    html += `<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">`;
                    html += `<div>`;
                    html += `<div style="display: flex; align-items: center; gap: 6px;">`;
                    html += `<strong>Karenzzeit (Sekunden):</strong>`;
                    html += `<span class="tooltip-icon" data-tooltip="Wartezeit nach Datei-Änderung, bevor die Datei weitergeleitet wird. Verhindert, dass unvollständig kopierte Dateien verschoben werden.">?</span>`;
                    html += `</div>`;
                    html += `<input type="number" value="${tab.GracePeriod || 30}" id="gracePeriod_${index}" class="custom-grace-period-input" data-tab-index="${index}" style="width: 100%; margin-top: 8px;">`;
                    html += `</div>`;
                    html += `<div>`;
                    html += `<div style="display: flex; align-items: center; gap: 6px;">`;
                    html += `<strong>Nachtverarbeitung:</strong>`;
                    html += `<span class="tooltip-icon" data-tooltip="Wenn aktiviert, werden Dateien nur in den angegebenen Zeitfenstern weitergeleitet. Dies ist nützlich für große Datenmengen.">?</span>`;
                    html += `</div>`;
                    html += `<div class="form-row" style="align-items: center; gap: 10px; margin-top: 8px;">`;
                    html += `<label class="switch">`;
                    html += `<input type="checkbox" id="nightBatch_${index}" ${tab.NightBatchEnabled ? 'checked' : ''} class="custom-night-batch-checkbox" data-tab-index="${index}">`;
                    html += `<span class="slider"></span>`;
                    html += `</label>`;
                    html += `<span>${tab.NightBatchEnabled ? 'Aktiviert' : 'Deaktiviert'}</span>`;
                    html += `</div>`;
                    html += `</div>`;
                    html += `</div>`;
                    html += `<div id="nightBatchTimeInputs_${index}" style="display: ${tab.NightBatchEnabled ? 'block' : 'none'}; margin-top: 15px; padding-top: 15px; border-top: 1px solid var(--border-color);">`;
                    html += `<div class="form-row" style="gap: 10px; align-items: flex-end;">`;
                    html += `<div>`;
                    html += `<label style="display: block; font-size: 0.9em; margin-bottom: 4px; font-weight: bold;">Von:</label>`;
                    html += `<input type="time" value="${tab.NightBatchStartTime || '20:00'}" id="nightStart_${index}" class="custom-night-start-input" data-tab-index="${index}" style="width: 120px; padding: 5px; border-radius: 4px;">`;
                    html += `</div>`;
                    html += `<div>`;
                    html += `<label style="display: block; font-size: 0.9em; margin-bottom: 4px; font-weight: bold;">Bis:</label>`;
                    html += `<input type="time" value="${tab.NightBatchEndTime || '06:00'}" id="nightEnd_${index}" class="custom-night-end-input" data-tab-index="${index}" style="width: 120px; padding: 5px; border-radius: 4px;">`;
                    html += `</div>`;
                    html += `</div>`;
                    html += `</div>`;
                    html += `</div>`;
                    html += `</div>`;

                    html += `<div class="card">`;
                    html += `<h2>Zielordner & Dateiformate</h2>`;
                    html += `<div id="customDestinations_${index}"></div>`;
                    html += `</div>`;

                    html += `<div class="button-group">`;
                    html += `<button class="btn btn-success" data-action="saveCustomTab" data-tab-index="${index}" style="cursor: pointer;">✅ Speichern</button>`;
                    html += `<button class="btn btn-warning" data-action="resetCustomTab" data-tab-index="${index}" style="cursor: pointer;">🔄 Zurücksetzen</button>`;
                    html += `</div>`;

                    tabContent.innerHTML = html;
                    container.appendChild(tabContent);

                    // Render destinations for this custom tab
                    this.renderCustomTabDestinations(index);
                } catch (error) {
                    console.error(`Error rendering tab ${index}:`, error);
                }
            });

            // Restore tab navigation and switch to previously active tab
            this.initializeTabs();
            
            // Try to restore previously active tab, otherwise show first custom tab
            if (currentTabId && document.getElementById(currentTabId)) {
                this.switchTab(currentTabId.replace('customTab_', 'custom_'));
            } else if (this.config.CustomTabs && this.config.CustomTabs.length > 0) {
                this.switchTab('custom_0');
            }
        } catch (error) {
            console.error('Error in renderCustomTabs:', error, error.stack);
        }
    }

    renderCustomTabDestinations(tabIndex) {
        try {
            const tab = this.config.CustomTabs[tabIndex];
            const container = document.getElementById(`customDestinations_${tabIndex}`);
            if (!container) {
                console.error(`Container customDestinations_${tabIndex} not found`);
                return;
            }

            if (!tab) {
                console.error(`Tab at index ${tabIndex} not found`);
                return;
            }

            let html = '<div class="destination-grid">';
            
            // Add existing destinations
            if (tab.Formats && Object.keys(tab.Formats).length > 0) {
                Object.keys(tab.Formats).forEach(destName => {
                    try {
                        
                        html += this.renderCustomDestinationCard(tabIndex, destName);
                    } catch (error) {
                        console.error(`Error rendering destination ${destName}:`, error);
                    }
                });
            } else {
                
            }

            html += '</div>';
            html += `<div style="text-align: center; margin: 20px 0; padding: 15px; border: 2px dashed #3498db; border-radius: 8px;">`;
            html += `<button class="btn" data-action="addDestinationToCustomTab" data-tab-index="${tabIndex}" style="cursor: pointer;">➕ Zielordner hinzufügen</button>`;
            html += `</div>`;

            
            container.innerHTML = html;
            
        } catch (error) {
            console.error('Error in renderCustomTabDestinations:', error, error.stack);
        }
    }

    renderCustomDestinationCard(tabIndex, destName) {
        try {
            const tab = this.config.CustomTabs[tabIndex];
            const dest = tab.Destinations?.[destName] || {};
            const formats = tab.Formats?.[destName] || [];

            const colors = ['#9b59b6', '#1abc9c', '#34495e', '#e67e22', '#2ecc71', '#c0392b'];
            const colorIndex = (tabIndex + destName.length) % colors.length;
            const color = colors[colorIndex];

            let html = `<div class="destination-card" style="border-color: ${color}; position: relative;">`;
            
            html += `<div class="destination-card-title" style="display: flex; justify-content: space-between; align-items: center;">`;
            html += `<h3 style="color: ${color}; margin: 0;">${this.escapeHtml(destName)}</h3>`;
            html += `<button class="btn-close-dest" data-action="removeDestination" data-tab-index="${tabIndex}" data-dest-name="${destName}" title="Zielordner löschen">✕</button>`;
            html += `</div>`;

            html += `<div class="config-item">`;
            html += `<div style="display: flex; align-items: center; gap: 6px;">`;
            html += `<strong>Zielordner:</strong>`;
            html += `<span class="tooltip-icon" data-tooltip="Der Ordner, in den die unten angegebenen Dateien verschoben werden">?</span>`;
            html += `</div>`;
            const path = dest.Path || `C:\\Temp\\${destName}`;
            html += `<div class="form-row">`;
            html += `<input type="text" value="${this.escapeHtml(path)}" id="customPath_${tabIndex}_${destName}" class="path-input" data-tab-index="${tabIndex}" data-dest-name="${destName}">`;
            html += `<button class="btn btn-small" data-action="browseCustomPath" data-input-id="customPath_${tabIndex}_${destName}">Wählen</button>`;
            html += `<button class="btn btn-small" data-action="openFolder" data-tab-index="${tabIndex}" data-dest-name="${destName}" title="Ordner im Explorer öffnen">📁 Öffnen</button>`;
            html += `</div>`;
            html += `</div>`;

            html += `<div class="config-item">`;
            html += `<div style="display: flex; align-items: center; gap: 6px;">`;
            html += `<strong>Dateiformate:</strong>`;
            html += `<span class="tooltip-icon" data-tooltip="Dateiendungen (z.B. .doc, .pdf) die in diesen Ordner verschoben werden sollen. Mehrere durch Komma getrennt.">?</span>`;
            html += `</div>`;
            html += `<div id="customFormats_${tabIndex}_${destName}" style="display: flex; flex-wrap: wrap; gap: 5px; margin: 10px 0;">`;
            formats.forEach(format => {
                html += `<span class="format-tag" data-category="${this.escapeHtml(destName)}">`;
                html += `${this.escapeHtml(format)} <span class="remove-format" data-action="removeFormat" data-tab-index="${tabIndex}" data-dest-name="${destName}" data-format="${format}">×</span>`;
                html += `</span>`;
            });
            html += `</div>`;
            html += `<div class="form-row">`;
            html += `<input type="text" id="customNewformat_${tabIndex}_${destName}" placeholder="z.B. .doc, .pdf" class="format-input" data-tab-index="${tabIndex}" data-dest-name="${destName}" style="flex: 1;">`;
            html += `<button class="btn btn-small" data-action="addFormat" data-tab-index="${tabIndex}" data-dest-name="${destName}">Format hinzufügen</button>`;
            html += `</div>`;
            html += `</div>`;

            // Text Filter
            html += `<div class="config-item">`;
            html += `<div style="display: flex; align-items: center; gap: 6px;">`;
            html += `<strong>Text-Filter (optional):</strong>`;
            html += `<span class="tooltip-icon" data-tooltip="Dateien mit diesem Text im Namen werden automatisch in diesen Ordner verschoben. Regexmuster werden unterstützt.">?</span>`;
            html += `</div>`;
            html += `<div class="form-row">`;
            html += `<input type="text" id="customTextFilter_${tabIndex}_${destName}" placeholder="z.B. 'Rechnung', 'Quittung'" class="text-filter-input" data-tab-index="${tabIndex}" data-dest-name="${destName}" style="flex: 1;">`;
            html += `<label style="display: flex; align-items: center; gap: 5px; margin-left: 10px; white-space: nowrap;">`;
            html += `<input type="checkbox" id="customTextFilterCase_${tabIndex}_${destName}" class="case-checkbox" data-tab-index="${tabIndex}" data-dest-name="${destName}">`;
            html += `<span>Groß-/Kleinschreibung beachten</span>`;
            html += `<span class="tooltip-icon" data-tooltip="Wenn aktiviert, wird bei der Textsuche zwischen Großbuchstaben und Kleinbuchstaben unterschieden">?</span>`;
            html += `</label>`;
            html += `</div>`;
            html += `</div>`;

            html += `<div class="config-item">`;
            html += `<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">`;
            html += `<div>`;
            html += `<label style="display: flex; align-items: center; gap: 8px;">`;
            const isIgnore = destName === '__IGNORE__';
            html += `<input type="checkbox" ${isIgnore ? 'checked disabled' : ''} id="customIgnore_${tabIndex}_${destName}" class="ignore-checkbox" data-tab-index="${tabIndex}" data-dest-name="${destName}">`;
            html += `<span>Ignorieren</span>`;
            html += `<span class="tooltip-icon" data-tooltip="Dateien, die diese Kriterien erfüllen, werden NICHT verschoben, sondern gelöscht/ignoriert">?</span>`;
            html += `</label>`;
            html += `</div>`;
            if (destName !== '__IGNORE__') {
                html += `<div>`;
                html += `<label style="display: flex; align-items: center; gap: 8px;">`;
                const hasRestHandler = dest.HandleRest !== false;
                html += `<input type="checkbox" ${hasRestHandler ? 'checked' : ''} id="customRest_${tabIndex}_${destName}" class="rest-checkbox" data-tab-index="${tabIndex}" data-dest-name="${destName}">`;
                html += `<span>Restliche Dateien</span>`;
                html += `<span class="tooltip-icon" data-tooltip="Dateien, die in KEINEM anderen Filter (Format/Text) dieses Ordners passen, werden hier als Fallback verschoben">?</span>`;
                html += `</label>`;
                html += `</div>`;
            }
            html += `</div>`;
            html += `</div>`;

            html += `</div>`;
            return html;
        } catch (error) {
            console.error(`Error rendering destination card for ${destName}:`, error);
            return `<div class="destination-card" style="border: 2px solid #e74c3c;"><p>Fehler beim Rendern</p></div>`;
        }
    }

    escapeHtml(text) {
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        return text.replace(/[&<>"']/g, m => map[m]);
    }

    renderOptionsTab() {
        const container = document.getElementById('optionsTab');
        if (!container) return;

        // Load current options
        const options = this.config.Options || {
            Autostart: false,
            Theme: 'light'
        };

        document.getElementById('autostartOption').checked = options.Autostart || false;
    }

    // Format Management
    addFormat(destName) {
        const input = document.getElementById(`newformat_${destName}`);
        if (!input) return;

        let format = input.value.trim();
        if (!format) return;

        if (!format.startsWith('.')) format = '.' + format;

        if (!this.config.Formats) this.config.Formats = {};
        if (!this.config.Formats[destName]) this.config.Formats[destName] = [];

        if (this.config.Formats[destName].includes(format)) {
            this.showMessage('Format existiert bereits', 'error');
            return;
        }

        this.config.Formats[destName].push(format);
        this.workingConfig.Formats = JSON.parse(JSON.stringify(this.config.Formats));

        input.value = '';
        this.renderStandardTab();
    }

    removeFormat(destName, format) {
        if (!confirm(`Format "${format}" wirklich entfernen?`)) return;

        if (this.config.Formats && this.config.Formats[destName]) {
            this.config.Formats[destName] = this.config.Formats[destName].filter(f => f !== format);
            this.workingConfig.Formats = JSON.parse(JSON.stringify(this.config.Formats));
        }

        this.renderStandardTab();
    }

    addCustomFormat(tabIndex, destName) {
        const input = document.getElementById(`customNewformat_${tabIndex}_${destName}`);
        if (!input) return;

        let format = input.value.trim();
        if (!format) return;

        if (!format.startsWith('.')) format = '.' + format;

        const tab = this.config.CustomTabs[tabIndex];
        if (!tab.Formats) tab.Formats = {};
        if (!tab.Formats[destName]) tab.Formats[destName] = [];

        if (tab.Formats[destName].includes(format)) {
            this.showMessage('Format existiert bereits', 'error');
            return;
        }

        tab.Formats[destName].push(format);
        input.value = '';
        this.renderCustomTabs();
    }

    removeCustomFormat(tabIndex, destName, format) {
        if (!confirm(`Format "${format}" wirklich entfernen?`)) return;

        const tab = this.config.CustomTabs[tabIndex];
        if (tab.Formats && tab.Formats[destName]) {
            tab.Formats[destName] = tab.Formats[destName].filter(f => f !== format);
        }

        this.renderCustomTabs();
    }

    // Destination Management
    addDestinationToCustomTab(tabIndex) {
        
        
        // Validate tab exists
        if (!this.config.CustomTabs || !this.config.CustomTabs[tabIndex]) {
            console.error(`Tab not found at index ${tabIndex}`);
            this.showMessage('Tab nicht gefunden', 'error');
            return;
        }

        const dialogOverlay = document.createElement('div');
        dialogOverlay.className = 'dialog-overlay';
        
        const dialog = document.createElement('div');
        dialog.className = 'dialog';
        dialog.innerHTML = `
            <div class="dialog-header">Neuen Zielordner hinzufügen</div>
            <div class="dialog-body">
                <label style="display: block; margin-bottom: 10px; color: var(--text-primary);">
                    <strong>Name des Zielordners:</strong>
                </label>
                <input type="text" id="newDestName" placeholder="z.B. ARCHIVE, BACKUP, etc." style="width: 100%; padding: 10px; border: 1px solid var(--border-color); border-radius: 4px; background: var(--bg-secondary); color: var(--text-primary); font-size: 14px; box-sizing: border-box;">
                <small style="color: var(--text-secondary); display: block; margin-top: 8px;">Nur Buchstaben, Zahlen und Unterstriche erlaubt</small>
            </div>
            <div class="dialog-footer">
                <button class="btn btn-warning" id="cancelBtn" style="cursor: pointer;">Abbrechen</button>
                <button class="btn btn-success" id="confirmBtn" style="cursor: pointer;">Erstellen</button>
            </div>
        `;
        
        dialogOverlay.appendChild(dialog);
        document.body.appendChild(dialogOverlay);
        
        const input = document.getElementById('newDestName');
        const cancelBtn = document.getElementById('cancelBtn');
        const confirmBtn = document.getElementById('confirmBtn');
        
        // Focus on input with small delay to ensure DOM is ready
        setTimeout(() => {
            
            
            
            input.focus();
            input.select();
            
            
            
        }, 100);
        
        // Cancel handler
        const handleCancel = () => {
            if (dialogOverlay.parentNode) {
                dialogOverlay.remove();
            }
        };
        cancelBtn.onclick = handleCancel;
        
        // Escape key to cancel
        const handleEscape = (e) => {
            if (e.key === 'Escape') {
                handleCancel();
                document.removeEventListener('keydown', handleEscape);
            }
        };
        document.addEventListener('keydown', handleEscape);
        
        // Confirm handler
        const handleConfirm = () => {
            const destName = input.value.trim();
            
            
            if (!destName) {
                console.warn('Empty destination name');
                this.showMessage('Bitte geben Sie einen Namen ein', 'error');
                input.focus();
                return;
            }
            
            const cleanName = destName.toUpperCase().replace(/[^A-Z0-9_]/g, '_');
            
            
            try {
                const tab = this.config.CustomTabs[tabIndex];
                if (!tab) {
                    throw new Error(`Tab at index ${tabIndex} not found`);
                }
                
                
                
                if (!tab.Formats) {
                    tab.Formats = {};
                    
                }
                if (!tab.Destinations) {
                    tab.Destinations = {};
                    
                }
                
                // Check if name already exists
                if (tab.Formats[cleanName]) {
                    console.warn(`Destination ${cleanName} already exists`);
                    this.showMessage('Zielordner mit diesem Namen existiert bereits', 'error');
                    input.focus();
                    input.select();
                    return;
                }
                
                // Add new destination
                tab.Formats[cleanName] = [];
                tab.Destinations[cleanName] = {
                    Path: `C:\\Temp\\${cleanName}`,
                    HandleRest: false
                };
                
                
                
                this.workingConfig.CustomTabs = JSON.parse(JSON.stringify(this.config.CustomTabs));
                
                
                // Close dialog BEFORE rendering
                if (dialogOverlay.parentNode) {
                    dialogOverlay.remove();
                }
                
                // Update UI
                
                this.renderCustomTabs();
                
                // THEN save config
                
                this.saveConfig();
                this.showMessage(`Zielordner "${cleanName}" erstellt`, 'success');
                
            } catch (error) {
                console.error('Error in handleConfirm:', error);
                this.showMessage('Fehler: ' + error.message, 'error');
            }
        };
        
        confirmBtn.onclick = handleConfirm;
        
        // Enter key to confirm
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                handleConfirm();
            } else if (e.key === 'Escape') {
                e.preventDefault();
                handleCancel();
            }
        });
        
        // Close on overlay click (outside dialog)
        dialogOverlay.addEventListener('click', (e) => {
            if (e.target === dialogOverlay) {
                handleCancel();
            }
        });
    }

    removeDestinationFromCustomTab(tabIndex, destName) {
        if (!confirm(`Zielordner "${destName}" wirklich entfernen?`)) return;

        const tab = this.config.CustomTabs[tabIndex];
        if (tab.Formats) delete tab.Formats[destName];
        if (tab.Destinations) delete tab.Destinations[destName];

        this.renderCustomTabs();
    }

    // Update Methods
    updateDestination(name, field, value) {
        if (!this.config.destinations) this.config.destinations = {};
        if (!this.config.destinations[name]) this.config.destinations[name] = {};
        this.config.destinations[name][field] = value;
        this.workingConfig.destinations = JSON.parse(JSON.stringify(this.config.destinations));
    }

    updateDestinationAndRerender(name, field, value) {
        this.updateDestination(name, field, value);
        // Re-render Standard Tab wenn sich Nachtverarbeitung ändert
        this.renderStandardTab();
    }

    updateCustomTabAndRerender(tabIndex, field, value) {
        this.updateCustomTab(tabIndex, field, value);
        // Re-render Custom Tabs wenn sich Nachtverarbeitung ändert
        this.renderCustomTabs();
    }

    updateCustomTab(tabIndex, field, value) {
        if (this.config.CustomTabs && this.config.CustomTabs[tabIndex]) {
            this.config.CustomTabs[tabIndex][field] = value;
            this.workingConfig.CustomTabs = JSON.parse(JSON.stringify(this.config.CustomTabs));
        }
    }

    openWatchFolder(tabIndex) {
        try {
            if (!this.config.CustomTabs || !this.config.CustomTabs[tabIndex]) {
                this.showMessage('Tab nicht gefunden', 'error');
                return;
            }
            
            const watchFolder = this.config.CustomTabs[tabIndex].WatchFolder;
            if (!watchFolder) {
                this.showMessage('Bitte geben Sie zuerst einen Watch Folder Pfad ein', 'error');
                return;
            }
            
            window.electronAPI.openFolder(watchFolder)
                .catch(error => {
                    console.error('Error opening watch folder:', error);
                    this.showMessage('Fehler beim Öffnen des Watch Folders', 'error');
                });
        } catch (error) {
            console.error('Error in openWatchFolder:', error);
            this.showMessage('Fehler beim Öffnen des Watch Folders', 'error');
        }
    }

    openStandardWatchFolder() {
        try {
            const watchPath = document.getElementById('watchPath');
            if (!watchPath || !watchPath.value) {
                this.showMessage('Bitte geben Sie zuerst einen Watch Folder Pfad ein', 'error');
                return;
            }
            
            window.electronAPI.openFolder(watchPath.value)
                .catch(error => {
                    console.error('Error opening watch folder:', error);
                    this.showMessage('Fehler beim Öffnen des Watch Folders', 'error');
                });
        } catch (error) {
            console.error('Error in openStandardWatchFolder:', error);
            this.showMessage('Fehler beim Öffnen des Watch Folders', 'error');
        }
    }

    updateCustomDestination(tabIndex, destName, field, value) {
        const tab = this.config.CustomTabs[tabIndex];
        if (!tab.Destinations) tab.Destinations = {};
        if (!tab.Destinations[destName]) tab.Destinations[destName] = {};
        tab.Destinations[destName][field] = value;
    }

    // Save Methods
    async saveStandardConfig() {
        // Lese alle Werte aus dem Standard-Tab-Formular
        const watchPath = document.getElementById('watchPath');
        const recursiveWatch = document.getElementById('recursiveWatch');
        const gracePeriod = document.getElementById('gracePeriod');
        const nightBatchEnabled = document.getElementById('nightBatchEnabled');
        const nightBatchStartTime = document.getElementById('nightBatchStartTime');
        const nightBatchEndTime = document.getElementById('nightBatchEndTime');
        
        // Aktualisiere die config mit den Formular-Werten
        if (watchPath) this.config.WatchPath = watchPath.value;
        if (recursiveWatch) this.config.RecursiveWatch = recursiveWatch.checked;
        if (gracePeriod) this.config.GracePeriod = parseInt(gracePeriod.value) || 30;
        
        // Lese Destination-Pfade
        if (!this.config.destinations) this.config.destinations = {};
        const destNames = ['MAM', 'BOX', 'Quarantine'];
        destNames.forEach(name => {
            const pathInput = document.getElementById(`path_${name}`);
            if (pathInput) {
                if (!this.config.destinations[name]) this.config.destinations[name] = {};
                this.config.destinations[name].Path = pathInput.value;
            }
        });
        
        // Nachtverarbeitung
        if (!this.config.Options) this.config.Options = {};
        if (nightBatchEnabled) this.config.Options.NightBatchEnabled = nightBatchEnabled.checked;
        if (nightBatchStartTime) this.config.Options.NightBatchStartTime = nightBatchStartTime.value;
        if (nightBatchEndTime) this.config.Options.NightBatchEndTime = nightBatchEndTime.value;
        
        // Überführe in workingConfig
        this.workingConfig = JSON.parse(JSON.stringify(this.config));
        
        // Speichere jetzt
        if (await this.saveConfig()) {
            this.renderStandardTab();
        }
    }

    toggleNightBatchUI() {
        const checkbox = document.getElementById('nightBatchEnabled');
        const timeInputs = document.getElementById('nightBatchTimeInputs');
        const status = document.getElementById('nightBatchStatus');
        
        if (checkbox && timeInputs && status) {
            if (checkbox.checked) {
                timeInputs.style.display = 'block';
                status.textContent = 'Aktiviert';
                // Speichern in config
                if (!this.config.Options) this.config.Options = {};
                this.config.Options.NightBatchEnabled = true;
                this.config.Options.NightBatchStartTime = document.getElementById('nightBatchStartTime')?.value || '20:00';
                this.config.Options.NightBatchEndTime = document.getElementById('nightBatchEndTime')?.value || '06:00';
            } else {
                timeInputs.style.display = 'none';
                status.textContent = 'Deaktiviert';
                // Speichern in config
                if (!this.config.Options) this.config.Options = {};
                this.config.Options.NightBatchEnabled = false;
            }
        }
    }

    saveStandardConfigWithNightBatch() {
        // Nachtverarbeitung-Werte speichern
        const enabled = document.getElementById('nightBatchEnabled')?.checked || false;
        const startTime = document.getElementById('nightBatchStartTime')?.value || '20:00';
        const endTime = document.getElementById('nightBatchEndTime')?.value || '06:00';
        
        if (!this.config.Options) this.config.Options = {};
        this.config.Options.NightBatchEnabled = enabled;
        this.config.Options.NightBatchStartTime = startTime;
        this.config.Options.NightBatchEndTime = endTime;
        
        this.workingConfig.Options = JSON.parse(JSON.stringify(this.config.Options));
        
        // Standard Config speichern
        this.saveStandardConfig();
    }

    async saveCustomTab(tabIndex) {
        // Stelle sicher, dass CustomTabs existiert
        if (!this.config.CustomTabs) {
            this.config.CustomTabs = [];
        }
        
        const tab = this.config.CustomTabs[tabIndex];
        if (!tab) {
            this.showMessage('Tab nicht gefunden', 'error');
            return;
        }
        
        // Lese alle Werte aus dem Formular
        const watchFolderInput = document.getElementById(`watchFolder_${tabIndex}`);
        const recursiveInput = document.getElementById(`recursiveWatch_${tabIndex}`);
        const gracePeriodInput = document.getElementById(`gracePeriod_${tabIndex}`);
        const nightBatchInput = document.getElementById(`nightBatch_${tabIndex}`);
        const nightStartInput = document.getElementById(`nightStart_${tabIndex}`);
        const nightEndInput = document.getElementById(`nightEnd_${tabIndex}`);
        
        // Aktualisiere den Tab mit den Formular-Werten
        if (watchFolderInput) tab.WatchFolder = watchFolderInput.value;
        if (recursiveInput) tab.RecursiveWatch = recursiveInput.checked;
        if (gracePeriodInput) tab.GracePeriod = parseInt(gracePeriodInput.value) || 30;
        if (nightBatchInput) tab.NightBatchEnabled = nightBatchInput.checked;
        if (nightStartInput) tab.NightBatchStartTime = nightStartInput.value;
        if (nightEndInput) tab.NightBatchEndTime = nightEndInput.value;
        
        // Überführe in workingConfig
        this.workingConfig.CustomTabs = JSON.parse(JSON.stringify(this.config.CustomTabs));
        
        // Speichere jetzt
        if (await this.saveConfig()) {
            this.renderCustomTabs();
        }
    }

    async resetStandardConfig() {
        if (!confirm('Alle Änderungen verwerfen?')) return;
        this.config = JSON.parse(JSON.stringify(this.originalConfig));
        this.workingConfig = JSON.parse(JSON.stringify(this.originalConfig));
        this.renderStandardTab();
    }

    async resetCustomTab(tabIndex) {
        if (!confirm('Alle Änderungen verwerfen?')) return;
        this.config = JSON.parse(JSON.stringify(this.originalConfig));
        this.workingConfig = JSON.parse(JSON.stringify(this.originalConfig));
        this.renderCustomTabs();
    }

    async loadHistory() {
        const historyContainer = document.getElementById('historyContainer');
        if (!historyContainer) return;
        
        historyContainer.innerHTML = '<p style="color: var(--text-secondary);">Lade Verlauf...</p>';
        
        try {
            const response = await fetch(`${this.apiBaseUrl}/history`);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            
            // Check if success is false or no history data
            if (!data.success) {
                historyContainer.innerHTML = '<p style="color: var(--text-secondary);">Keine Einträge im Verlauf</p>';
                return;
            }
            
            if (!data.history || data.history.length === 0) {
                historyContainer.innerHTML = '<p style="color: var(--text-secondary);">Keine Einträge im Verlauf</p>';
                return;
            }

            let html = '<div style="border: 1px solid var(--border-color); border-radius: 8px; overflow: hidden;">';
            html += '<table style="width: 100%; border-collapse: collapse;">';
            html += '<thead>';
            html += '<tr style="background: var(--bg-tertiary); border-bottom: 2px solid var(--border-color);">';
            html += '<th style="padding: 12px; text-align: left; border-right: 1px solid var(--border-color);">Zeit</th>';
            html += '<th style="padding: 12px; text-align: left; border-right: 1px solid var(--border-color);">Dateiname</th>';
            html += '<th style="padding: 12px; text-align: left;">Ziel</th>';
            html += '</tr>';
            html += '</thead>';
            html += '<tbody>';

            data.history.forEach((entry, index) => {
                const bgColor = index % 2 === 0 ? 'transparent' : 'var(--bg-tertiary)';
                html += `<tr style="background: ${bgColor}; border-bottom: 1px solid var(--border-color);">`;
                html += `<td style="padding: 10px; border-right: 1px solid var(--border-color); white-space: nowrap; font-size: 0.9em;">${entry.timestamp}</td>`;
                html += `<td style="padding: 10px; border-right: 1px solid var(--border-color); word-break: break-all;"><strong>${this.escapeHtml(entry.filename)}</strong></td>`;
                html += `<td style="padding: 10px; color: var(--accent-success);">➜ ${this.escapeHtml(entry.destination)}</td>`;
                html += `</tr>`;
            });

            html += '</tbody>';
            html += '</table>';
            html += '</div>';
            html += `<p style="color: var(--text-secondary); margin-top: 10px; font-size: 0.85em;">${data.history.length} Einträge</p>`;

            historyContainer.innerHTML = html;
        } catch (error) {
            historyContainer.innerHTML = `<p style="color: var(--accent-danger);">Fehler beim Laden: ${error.message}</p>`;
        }
    }
    
    async clearHistory() {
        if (!confirm('Möchtest du den gesamten Verlauf löschen?')) return;
        
        try {
            const response = await fetch(`${this.apiBaseUrl}/history`, {
                method: 'DELETE'
            });
            
            if (response.ok) {
                this.showMessage('Verlauf gelöscht', 'success');
                this.loadHistory();
            } else {
                throw new Error('Fehler beim Löschen');
            }
        } catch (error) {
            this.showMessage('Fehler: ' + error.message, 'error');
        }
    }

    async showHistory() {
        // Redirect to loadHistory for backwards compatibility
        this.loadHistory();
    }

    async saveAllOptions() {
        const autostartCheckbox = document.getElementById('autostartOption');
        
        const options = {
            Autostart: autostartCheckbox ? autostartCheckbox.checked : false,
            Theme: document.body.classList.contains('dark-mode') ? 'dark' : 'light'
        };

        this.config.Options = options;
        this.workingConfig.Options = options;

        if (await this.saveConfig()) {
            this.showMessage('Optionen gespeichert', 'success');
        }
    }

    // Utility Methods
    showMessage(text, type = 'info') {
        const msg = document.createElement('div');
        msg.className = `message ${type}`;
        msg.textContent = text;
        msg.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 5000; max-width: 300px;';
        document.body.appendChild(msg);

        setTimeout(() => msg.remove(), 3000);
    }
}

// Global functions for onclick handlers
window.dashboard = null;

function toggleTheme() {
}

function browseFolder(elementId) {
    const input = document.getElementById(elementId);
    if (!input) return;

    if (window.electronAPI && window.electronAPI.selectFolder) {
        window.electronAPI.selectFolder().then(path => {
            if (path) {
                input.value = path;
                input.dispatchEvent(new Event('change'));
            }
        });
    } else {
        const newPath = prompt('Ordner-Pfad eingeben:', input.value || 'C:\\Temp');
        if (newPath && newPath.trim()) {
            input.value = newPath.trim();
            input.dispatchEvent(new Event('change'));
        }
    }
}

function saveAutostartOption() {
    if (window.dashboard) {
        window.dashboard.saveAllOptions();
    }
}

function saveDarkModePreference() {
    if (window.dashboard) {
        window.dashboard.saveDarkModePreference();
    }
}

function saveAllOptions() {
    if (window.dashboard) {
        window.dashboard.saveAllOptions();
    }
}

// Initialize dashboard when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new WatchFolderDashboardEnhanced();
});
