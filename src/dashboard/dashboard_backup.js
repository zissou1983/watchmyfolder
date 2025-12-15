class WatchFolderDashboard {
    constructor() {
        this.apiBaseUrl = this.getApiBaseUrl();
        this.refreshInterval = 5000; // 5 Sekunden
        this.chart = null;
        this.isConnected = false;
        this.refreshIntervalId = null;
        
        // Performance thresholds
        this.thresholds = {
            cpu: { warning: 50, error: 80 },
            memory: { warning: 500, error: 100 },
            errorRate: { warning: 5, error: 10 }
        };
        
        this.init();
    }
    
    getApiBaseUrl() {
        return window.location.origin + '/api';
    }
    
    init() {
        this.setupEventListeners();
        this.initChart();
        this.startAutoRefresh();
        this.loadData();
        this.loadFormatConfig(); // Format-Konfiguration laden
    }
    
    async fetchStatus(signal) {
        const response = await fetch(`${this.apiBaseUrl}/status`, { signal });
        if (!response.ok) throw new Error(`Status API failed: ${response.status} ${response.statusText}`);
        return await response.json();
    }
    
    async fetchStats(signal) {
        const response = await fetch(`${this.apiBaseUrl}/stats`, { signal });
        if (!response.ok) throw new Error(`Stats API failed: ${response.status} ${response.statusText}`);
        return await response.json();
    }
    
    async fetchActivities(signal) {
        const response = await fetch(`${this.apiBaseUrl}/activities`, { signal });
        if (!response.ok) throw new Error(`Activities API failed: ${response.status} ${response.statusText}`);
        return await response.json();
    }
    
    async fetchErrors(signal) {
        const response = await fetch(`${this.apiBaseUrl}/errors`, { signal });
        if (!response.ok) throw new Error(`Errors API failed: ${response.status} ${response.statusText}`);
        return await response.json();
    }

    async fetchPerformance(signal) {
        const response = await fetch(`${this.apiBaseUrl}/performance`, { signal });
        if (!response.ok) throw new Error(`Performance API failed: ${response.status} ${response.statusText}`);
        return await response.json();
    }
    
    updateConnectionStatus(connected) {
        this.isConnected = connected;
        const statusElement = document.getElementById('serviceStatus');
        if (!statusElement) return;
        
        const dot = statusElement.querySelector('.status-dot');
        const text = statusElement.querySelector('.status-text');
        
        if (dot && text) {
            if (connected) {
                dot.className = 'status-dot online';
                text.textContent = 'Verbunden';
            } else {
                dot.className = 'status-dot offline';
                text.textContent = 'Verbindung unterbrochen';
            }
        }
    }
    
    updateServiceStatus(status) {
        document.getElementById('isRunning').textContent = status.isRunning ? 'Aktiv' : 'Gestoppt';
        document.getElementById('queueSize').textContent = status.queueSize || '0';
        document.getElementById('uptime').textContent = this.formatUptime(status.uptime);
        
        // Status-Styling
        const runningElement = document.getElementById('isRunning');
        runningElement.className = `metric-value ${status.isRunning ? 'success' : 'error'}`;
    }
    
    updateStats(stats) {
        document.getElementById('mamCount').textContent = stats.mamCount || '0';
        document.getElementById('boxCount').textContent = stats.boxCount || '0';
        document.getElementById('nightCount').textContent = stats.nightCount || '0';
        document.getElementById('errorCount').textContent = stats.errorCount || '0';
    }
    
    createFolderElement(folder) {
        const folderElement = document.createElement('div');
        folderElement.className = 'folder-item';
        
        const pathSpan = document.createElement('span');
        pathSpan.className = 'folder-path';
        pathSpan.textContent = folder.path;
        
        const statusSpan = document.createElement('span');
        statusSpan.className = `folder-status ${folder.active ? 'active' : 'inactive'}`;
        statusSpan.textContent = folder.active ? 'Aktiv' : 'Inaktiv';
        
        folderElement.appendChild(pathSpan);
        folderElement.appendChild(statusSpan);
        return folderElement;
    }
    
    updateWatchFolders(folders) {
        const container = document.getElementById('watchFolders');
        container.replaceChildren();
        
        if (!folders || folders.length === 0) {
            container.innerHTML = '<p class="no-data">Keine überwachten Ordner konfiguriert</p>';
            return;
        }
        
        folders.forEach(folder => {
            container.appendChild(this.createFolderElement(folder));
        });
    }
    
    updateActivities(activities) {
        const container = document.getElementById('recentActivities');
        container.innerHTML = '';
        
        if (!activities || activities.length === 0) {
            container.innerHTML = '<p class="no-data">Keine aktuellen Aktivitäten</p>';
            return;
        }
        
        const fragment = document.createDocumentFragment();
        activities.slice(0, 10).forEach(activity => {
            const activityElement = document.createElement('div');
            activityElement.className = 'activity-item';
            
            const contentDiv = document.createElement('div');
            contentDiv.className = 'activity-content';
            
            const titleDiv = document.createElement('div');
            titleDiv.className = 'activity-title';
            titleDiv.textContent = activity.title;
            
            const descDiv = document.createElement('div');
            descDiv.className = 'activity-description';
            descDiv.textContent = activity.description;
            
            const timeDiv = document.createElement('div');
            timeDiv.className = 'activity-time';
            timeDiv.textContent = this.formatTime(activity.timestamp);
            
            contentDiv.appendChild(titleDiv);
            contentDiv.appendChild(descDiv);
            activityElement.appendChild(contentDiv);
            activityElement.appendChild(timeDiv);
            fragment.appendChild(activityElement);
        });
        container.appendChild(fragment);
    }
    
    updateErrors(errors) {
        const container = document.getElementById('errorLog');
        container.innerHTML = '';

        if (!errors || errors.length === 0) {
            container.innerHTML = '<p class="no-data" style="color: #27ae60;">Keine aktuellen Fehler</p>';
            return;
        }

        errors.slice(0, 5).forEach(error => {
            if (!error) return;
            
            const errorElement = document.createElement('div');
            errorElement.className = 'error-item';
            
            const timeDiv = document.createElement('div');
            timeDiv.className = 'error-time';
            timeDiv.textContent = error.timestamp ? this.formatTime(error.timestamp) : 'Unknown time';
            
            const messageDiv = document.createElement('div');
            messageDiv.className = 'error-message';
            messageDiv.textContent = error.message || 'Unknown error';
            
            errorElement.appendChild(timeDiv);
            errorElement.appendChild(messageDiv);
            container.appendChild(errorElement);
        });
    }

    updatePerformance(performance) {
        if (!performance) return;

        // Cache DOM elements
        const elements = {
            cpu: document.getElementById('cpuUsage'),
            memory: document.getElementById('memoryUsage'),
            processing: document.getElementById('processingRate'),
            error: document.getElementById('errorRate'),
            uptime: document.getElementById('uptime'),
            queue: document.getElementById('queueSize')
        };

        // Performance-Metriken aktualisieren
        if (elements.cpu) elements.cpu.textContent = `${performance.CpuUsagePercent}%`;
        if (elements.memory) elements.memory.textContent = `${performance.MemoryAvailableMB} MB`;
        if (elements.processing) elements.processing.textContent = `${performance.ProcessingRatePerMinute}/min`;
        if (elements.error) elements.error.textContent = `${performance.ErrorRatePercent}%`;
        if (elements.uptime) elements.uptime.textContent = performance.Uptime.Formatted;
        if (elements.queue) elements.queue.textContent = performance.QueueSize;

        // Performance-Indikatoren einfärben
        this.updatePerformanceIndicators(performance);
    }

    updatePerformanceIndicators(performance) {
        // Cache DOM elements
        const elements = {
            cpu: document.getElementById('cpuUsage'),
            memory: document.getElementById('memoryUsage'),
            error: document.getElementById('errorRate')
        };

        // CPU Usage
        if (elements.cpu) {
            if (performance.CpuUsagePercent > this.thresholds.cpu.error) {
                elements.cpu.className = 'metric-value error';
            } else if (performance.CpuUsagePercent > this.thresholds.cpu.warning) {
                elements.cpu.className = 'metric-value warning';
            } else {
                elements.cpu.className = 'metric-value success';
            }
        }

        // Memory Available
        if (elements.memory) {
            if (performance.MemoryAvailableMB < this.thresholds.memory.error) {
                elements.memory.className = 'metric-value error';
            } else if (performance.MemoryAvailableMB < this.thresholds.memory.warning) {
                elements.memory.className = 'metric-value warning';
            } else {
                elements.memory.className = 'metric-value success';
            }
        }

        // Error Rate
        if (elements.error) {
            if (performance.ErrorRatePercent > this.thresholds.errorRate.error) {
                elements.error.className = 'metric-value error';
            } else if (performance.ErrorRatePercent > this.thresholds.errorRate.warning) {
                elements.error.className = 'metric-value warning';
            } else {
                elements.error.className = 'metric-value success';
            }
        }
    }
    
    initChart() {
        const chartElement = document.getElementById('performanceChart');
        if (!chartElement) {
            console.warn('Performance chart element not found');
            return;
        }
        
        const ctx = chartElement.getContext('2d');
        if (!ctx) {
            console.warn('Could not get 2D context for chart');
            return;
        }
        
        this.chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Verarbeitete Dateien',
                    data: [],
                    borderColor: '#3498db',
                    backgroundColor: 'rgba(52, 152, 219, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1
                        }
                    },
                    x: {
                        ticks: {
                            maxTicksLimit: 12
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                },
                elements: {
                    point: {
                        radius: 4,
                        hoverRadius: 6
                    }
                }
            }
        });
    }
    
    updateChart(hourlyData) {
        if (!this.chart || !hourlyData) return;
        
        const labels = hourlyData.map(item => this.formatHour(item.hour));
        const data = hourlyData.map(item => item.count);
        
        this.chart.data.labels = labels;
        this.chart.data.datasets[0].data = data;
        this.chart.update('none');
    }
    
    startAutoRefresh() {
        if (this.refreshIntervalId) {
            clearInterval(this.refreshIntervalId);
        }
        
        this.refreshIntervalId = setInterval(() => {
            if (document.visibilityState === 'visible') {
                this.loadData();
            }
        }, this.refreshInterval);
    }
    
    stopAutoRefresh() {
        if (this.refreshIntervalId) {
            clearInterval(this.refreshIntervalId);
            this.refreshIntervalId = null;
        }
    }
    
    updateLastRefresh() {
        const now = new Date();
        document.getElementById('lastUpdate').textContent = now.toLocaleTimeString('de-DE');
    }
    
    formatUptime(seconds) {
        if (!seconds) return '0s';
        
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (days > 0) {
            return `${days}d ${hours}h ${minutes}m`;
        } else if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        } else {
            return `${secs}s`;
        }
    }
    
    formatTime(timestamp) {
        if (!timestamp) return 'Invalid Date';
        
        const date = new Date(timestamp);
        if (isNaN(date.getTime())) return 'Invalid Date';
        
        return date.toLocaleTimeString('de-DE', { 
            hour: '2-digit', 
            minute: '2-digit',
            second: '2-digit'
        });
    }
    
    formatHour(hour) {
        return `${hour.toString().padStart(2, '0')}:00`;
    }
    
    showError(message) {
        // Einfache Fehleranzeige - könnte durch Toast-Notifications ersetzt werden
        console.error(message);
        
        // Temporäre Fehleranzeige im Status
        const statusText = document.querySelector('.status-text');
        if (!statusText) {
            console.warn('Status text element not found');
            return;
        }
        
        const originalText = statusText.textContent;
        statusText.textContent = message;
        statusText.style.color = '#e74c3c';
        
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = '';
        }, 3000);
    }

    // Format-Konfiguration Funktionen
    async loadFormatConfig() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/formats`);
            if (!response.ok) throw new Error(`Formats API failed: ${response.status} ${response.statusText}`);
            
            const data = await response.json();
            if (data.success) {
                this.displayFormatConfig(data.formats);
            } else {
                console.error('Fehler beim Laden der Format-Konfiguration:', data.error);
                this.showFormatConfigError('Fehler beim Laden der Formate');
            }
        } catch (error) {
            console.error('Fehler beim Laden der Format-Konfiguration:', error);
            this.showFormatConfigError('Fehler beim Laden der Formate');
        }
    }

    displayFormatConfig(formats) {
        const container = document.getElementById('formatConfig');
        if (!container) {
            console.warn('Format config container not found');
            return;
        }
        
        let html = '<div style="display: grid; gap: 20px;">';
        
        // MAM Formate
        html += '<div>';
        html += '<h3 style="margin: 0 0 10px 0; color: #e74c3c;">MAM-Formate (Medien-Archive)</h3>';
        html += '<div id="mamFormats" style="display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 10px;">';
        if (formats.MAM) {
            formats.MAM.forEach(format => {
                html += `<span class="format-tag" data-category="MAM" data-format="${format}">${format} <span class="remove-format" onclick="window.dashboard.removeFormat('MAM', '${format}')">×</span></span>`;
            });
        }
        html += '</div>';
        html += '<input type="text" id="newMAMFormat" placeholder="Neues Format (z.B. .avi)" style="width: 150px; margin-right: 5px; padding: 5px; border: 1px solid #ddd; border-radius: 4px;" onkeypress="if(event.key === \'Enter\') window.dashboard.addFormat(\'MAM\')">';
        html += '<button class="btn" onclick="window.dashboard.addFormat(\'MAM\')">Hinzufügen</button>';
        html += '</div>';
        
        // BOX Formate
        html += '<div>';
        html += '<h3 style="margin: 0 0 10px 0; color: #f39c12;">BOX-Formate (Dokumente)</h3>';
        html += '<div id="boxFormats" style="display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 10px;">';
        if (formats.BOX) {
            formats.BOX.forEach(format => {
                html += `<span class="format-tag" data-category="BOX" data-format="${format}">${format} <span class="remove-format" onclick="window.dashboard.removeFormat('BOX', '${format}')">×</span></span>`;
            });
        }
        html += '</div>';
        html += '<input type="text" id="newBOXFormat" placeholder="Neues Format (z.B. .xlsx)" style="width: 150px; margin-right: 5px; padding: 5px; border: 1px solid #ddd; border-radius: 4px;" onkeypress="if(event.key === \'Enter\') window.dashboard.addFormat(\'BOX\')">';
        html += '<button class="btn" onclick="window.dashboard.addFormat(\'BOX\')">Hinzufügen</button>';
        html += '</div>';
        
        // SYSTEM Formate
        html += '<div>';
        html += '<h3 style="margin: 0 0 10px 0; color: #95a5a6;">SYSTEM-Formate (zu ignorieren)</h3>';
        html += '<div id="systemFormats" style="display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 10px;">';
        if (formats.SYSTEM) {
            formats.SYSTEM.forEach(format => {
                html += `<span class="format-tag" data-category="SYSTEM" data-format="${format}">${format} <span class="remove-format" onclick="window.dashboard.removeFormat('SYSTEM', '${format}')">×</span></span>`;
            });
        }
        html += '</div>';
        html += '<input type="text" id="newSYSTEMFormat" placeholder="Neues Format (z.B. .tmp)" style="width: 150px; margin-right: 5px; padding: 5px; border: 1px solid #ddd; border-radius: 4px;" onkeypress="if(event.key === \'Enter\') window.dashboard.addFormat(\'SYSTEM\')">';
        html += '<button class="btn" onclick="window.dashboard.addFormat(\'SYSTEM\')">Hinzufügen</button>';
        html += '</div>';
        
        html += '</div>';
        
        // Speichern-Button
        html += '<div style="margin-top: 20px; text-align: center;">';
        html += '<button class="btn btn-primary" onclick="window.dashboard.saveFormatConfig()">💾 Formate speichern</button>';
        html += '</div>';
        
        container.innerHTML = html;
    }

    showFormatConfigError(message) {
        const container = document.getElementById('formatConfig');
        if (container) {
            container.innerHTML = `<p style="color: #e74c3c;">${message}</p>`;
        }
    }

    addFormat(category) {
        const inputId = `new${category}Format`;
        const input = document.getElementById(inputId);
        if (!input) return;
        
        const format = input.value.trim();
        
        if (!format) {
            alert('Bitte geben Sie ein Format ein');
            return;
        }
        
        // Stelle sicher, dass das Format mit einem Punkt beginnt
        if (!format.startsWith('.')) {
            input.value = '.' + format;
            return;
        }
        
        // Prüfe ob Format bereits existiert
        const container = document.getElementById(`${category.toLowerCase()}Formats`);
        if (!container) return;
        
        const existingTags = container.querySelectorAll('.format-tag');
        for (let tag of existingTags) {
            if (tag.dataset.format === format) {
                alert('Dieses Format existiert bereits');
                return;
            }
        }
        
        // Neues Tag hinzufügen
        const tagHtml = `<span class="format-tag" data-category="${category}" data-format="${format}">${format} <span class="remove-format" onclick="window.dashboard.removeFormat('${category}', '${format}')">×</span></span>`;
        container.insertAdjacentHTML('beforeend', tagHtml);
        
        // Input leeren
        input.value = '';
    }

    removeFormat(category, format) {
        if (!confirm(`Format "${format}" wirklich entfernen?`)) {
            return;
        }
        
        const container = document.getElementById(`${category.toLowerCase()}Formats`);
        if (!container) return;
        
        const tags = container.querySelectorAll('.format-tag');
        
        tags.forEach(tag => {
            if (tag.dataset.format === format) {
                tag.remove();
            }
        });
    }

    async saveFormatConfig() {
        // Prüfe ob Format-Container existieren und gültig sind
        const mamContainer = document.getElementById('mamFormats');
        const boxContainer = document.getElementById('boxFormats');
        const systemContainer = document.getElementById('systemFormats');
        
        console.log('Container Status:', {
            mamContainer: mamContainer ? 'exists' : 'null',
            boxContainer: boxContainer ? 'exists' : 'null',
            systemContainer: systemContainer ? 'exists' : 'null'
        });
        
        if (!mamContainer || !boxContainer || !systemContainer) {
            alert('Format-Konfiguration wurde noch nicht geladen. Bitte warten Sie einen Moment.');
            return;
        }
        
        // Zusätzliche Sicherheit: Prüfe ob die Elemente tatsächlich DOM-Elemente sind
        if (typeof mamContainer.querySelectorAll !== 'function' ||
            typeof boxContainer.querySelectorAll !== 'function' ||
            typeof systemContainer.querySelectorAll !== 'function') {
            alert('Format-Konfiguration ist beschädigt. Bitte laden Sie die Seite neu.');
            return;
        }
        
        // Sammle alle Formate aus der UI
        const formats = {
            MAM: [],
            BOX: [],
            SYSTEM: []
        };
        
        // MAM Formate sammeln
        const mamTags = mamContainer.querySelectorAll('.format-tag');
        mamTags.forEach(tag => {
            formats.MAM.push(tag.dataset.format);
        });
        
        // BOX Formate sammeln
        const boxTags = boxContainer.querySelectorAll('.format-tag');
        boxTags.forEach(tag => {
            formats.BOX.push(tag.dataset.format);
        });
        
        // SYSTEM Formate sammeln
        const systemTags = systemContainer.querySelectorAll('.format-tag');
        systemTags.forEach(tag => {
            formats.SYSTEM.push(tag.dataset.format);
        });
        
        // An API senden
        try {
            const response = await fetch(`${this.apiBaseUrl}/formats`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ formats: formats })
            });
            
            const data = await response.json();
            if (data.success) {
                alert('Format-Konfiguration erfolgreich gespeichert!');
                // Aktivität hinzufügen (falls verfügbar)
                if (window.dashboard && window.dashboard.addActivityToLog) {
                    window.dashboard.addActivityToLog('Format-Konfiguration aktualisiert', `${formats.MAM.length + formats.BOX.length + formats.SYSTEM.length} Formate konfiguriert`, new Date().toISOString());
                }
            } else {
                alert('Fehler beim Speichern: ' + data.error);
            }
        } catch (error) {
            alert('Fehler beim Speichern der Format-Konfiguration: ' + error.message);
        }
    }
}

// Dashboard initialisieren wenn DOM geladen ist
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new WatchFolderDashboard();
    
    // CSS für Format-Tags hinzufügen
    const style = document.createElement('style');
    style.textContent = `
        .format-tag {
            display: inline-flex;
            align-items: center;
            background: #3498db;
            color: white;
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 12px;
            margin: 2px;
        }
        .format-tag[data-category="MAM"] { background: #e74c3c; }
        .format-tag[data-category="BOX"] { background: #f39c12; }
        .format-tag[data-category="SYSTEM"] { background: #95a5a6; }
        .remove-format {
            margin-left: 4px;
            cursor: pointer;
            font-weight: bold;
            color: rgba(255,255,255,0.8);
        }
        .remove-format:hover {
            color: white;
        }
    `;
    document.head.appendChild(style);
});

