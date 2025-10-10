class OperationTracker {
    [Logger]$Logger
    [System.Collections.Generic.Dictionary[string, hashtable]]$ActiveOperations
    [int]$MaxHistorySize

    OperationTracker([Logger]$Logger) {
        $this.Logger = $Logger
        $this.ActiveOperations = [System.Collections.Generic.Dictionary[string, hashtable]]::new()
        $this.MaxHistorySize = 100
    }

    [void] StartOperation([string]$FilePath, [string]$OperationType) {
        $operationId = [Guid]::NewGuid().ToString()

        $operation = @{
            Id = $operationId
            FilePath = $FilePath
            FileName = [System.IO.Path]::GetFileName($FilePath)
            OperationType = $OperationType
            Status = "analyzing"
            StartTime = Get-Date
            LastUpdate = Get-Date
            Progress = 0
            CanCancel = $true
            Error = $null
        }

        $this.ActiveOperations[$operationId] = $operation
        $this.Logger.Info("Operation gestartet: $($operation.FileName)", @{ "OperationId" = $operationId; "Type" = $OperationType })

        # Alte Operationen aufräumen
        $this.CleanupOldOperations()
    }

    [void] UpdateOperation([string]$OperationId, [string]$Status, [int]$Progress = -1, [string]$Error = $null) {
        if ($this.ActiveOperations.ContainsKey($OperationId)) {
            $operation = $this.ActiveOperations[$OperationId]
            $operation.Status = $Status
            $operation.LastUpdate = Get-Date

            if ($Progress -ge 0) {
                $operation.Progress = $Progress
            }

            if ($Error) {
                $operation.Error = $Error
                $operation.Status = "error"
            }

            # Bestimmte Status erlauben kein Cancel mehr
            if ($Status -eq "completed" -or $Status -eq "error") {
                $operation.CanCancel = $false
            }

            $this.Logger.Debug("Operation aktualisiert: $($operation.FileName) -> $Status", @{ "OperationId" = $OperationId; "Progress" = $Progress })
        }
    }

    [void] CompleteOperation([string]$OperationId, [string]$Result = "success") {
        if ($this.ActiveOperations.ContainsKey($OperationId)) {
            $operation = $this.ActiveOperations[$OperationId]
            $operation.Status = "completed"
            $operation.LastUpdate = Get-Date
            $operation.Progress = 100
            $operation.CanCancel = $false
            $operation.Result = $Result

            $duration = ($operation.LastUpdate - $operation.StartTime).TotalSeconds
            $this.Logger.Info("Operation abgeschlossen: $($operation.FileName) (${duration}s)", @{ "OperationId" = $OperationId; "Result" = $Result })
        }
    }

    [void] CancelOperation([string]$OperationId) {
        if ($this.ActiveOperations.ContainsKey($OperationId)) {
            $operation = $this.ActiveOperations[$OperationId]
            if ($operation.CanCancel) {
                $operation.Status = "cancelled"
                $operation.LastUpdate = Get-Date
                $operation.CanCancel = $false
                $operation.Cancelled = $true

                $this.Logger.Info("Operation abgebrochen: $($operation.FileName)", @{ "OperationId" = $OperationId })
            }
        }
    }

    [array] GetActiveOperations() {
        $operations = @()
        foreach ($operation in $this.ActiveOperations.Values) {
            # Nur aktive Operationen zurückgeben (nicht completed/cancelled/error länger als 5 Minuten)
            $isRecent = ($operation.Status -notin @("completed", "cancelled", "error")) -or
                       ((Get-Date) - $operation.LastUpdate).TotalMinutes -lt 5

            if ($isRecent) {
                $operations += $operation
            }
        }

        # Nach Startzeit sortieren (neueste zuerst)
        return $operations | Sort-Object StartTime -Descending
    }

    [hashtable] GetOperation([string]$OperationId) {
        if ($this.ActiveOperations.ContainsKey($OperationId)) {
            return $this.ActiveOperations[$OperationId]
        }
        return $null
    }

    [void] CleanupOldOperations() {
        $cutoffTime = (Get-Date).AddMinutes(-30)  # Operationen älter als 30 Minuten entfernen
        $toRemove = @()

        foreach ($key in $this.ActiveOperations.Keys) {
            $operation = $this.ActiveOperations[$key]
            if ($operation.LastUpdate -lt $cutoffTime) {
                $toRemove += $key
            }
        }

        foreach ($key in $toRemove) {
            $this.ActiveOperations.Remove($key)
        }

        # Dictionary-Größe begrenzen
        if ($this.ActiveOperations.Count -gt $this.MaxHistorySize) {
            $keysToRemove = $this.ActiveOperations.Keys | Select-Object -First ($this.ActiveOperations.Count - $this.MaxHistorySize)
            foreach ($key in $keysToRemove) {
                $this.ActiveOperations.Remove($key)
            }
        }
    }
}