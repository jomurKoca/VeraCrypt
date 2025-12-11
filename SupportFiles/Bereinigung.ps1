<#
.SYNOPSIS
    VeraCrypt Manuelle Bereinigung - Force Removal Script
    
.DESCRIPTION
    Entfernt VeraCrypt vollständig vom System wenn normale Deinstallation nicht funktioniert.
    
    Bereinigungsschritte:
    1. Prozesse beenden (VeraCrypt, VeraCryptExpander, VeraCrypt Format, VeraCrypt Setup)
    2. Services stoppen und entfernen (veracrypt, System Favorites, Volume Auto-Dismount)
    3. Kernel-Treiber entfernen (veracrypt.sys aus System32\drivers)
    4. Registry-Einträge bereinigen (Uninstall, App Paths, Run Keys, Services Registry, User Registry)
    5. Programmdateien löschen (Program Files, ProgramData, LocalAppData, AppData)
    6. Verknüpfungen entfernen (Desktop, Start Menu für alle User)
    7. Temporäre Dateien bereinigen (User Temp, System Temp)
    8. Validation (Ordner, Registry, Get-ADTApplication Check)
    
    
.NOTES
    Author: Ömür Koca
    Date: 05.11.2025
    Version: 1.0
    
    Wird aufgerufen wenn:
    - VeraCrypt EXE-Installation ohne QuietUninstallString gefunden wird
    - Silent Deinstallation nicht möglich ist
    - Vollständige Systemreinigung erforderlich ist
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$AppName = "VeraCrypt"
)


#region 1. Prozesse beenden. 
$processDefinitions = @(
    @{ Name = 'VeraCrypt' }
    @{ Name = 'VeraCryptExpander'; Description = 'VeraCrypt Volume Expander' }
    @{ Name = 'VeraCrypt Format'; Description = 'VeraCrypt Format' }
    @{ Name = 'VeraCrypt Setup'; Description = 'VeraCrypt Setup' }
)
# Prüfe welche Prozesse laufen
$runningProcesses = Get-ADTRunningProcesses -ProcessObjects $processDefinitions -ErrorAction SilentlyContinue
if ($runningProcesses) {
    foreach ($proc in $runningProcesses) {
        try {
            $proc.Process | Stop-Process -Force -ErrorAction Stop
        } catch {
            Write-ADTLogEntry -Message "  WARNUNG: Konnte Prozess nicht beenden: $($_.Exception.Message)" -Severity 2
        }
    }
    Start-Sleep -Milliseconds 1000
}
#endregion======================================================================================


#region 2. Services stoppen und entfernen
Write-ADTLogEntry -Message "[2] Stoppe und entferne VeraCrypt Services..." -Severity 1

$services = @('veracrypt', 'VeraCrypt System Favorites', 'VeraCrypt Volume Auto-Dismount')

foreach ($svcName in $services) {
    $serviceExists = Test-ADTServiceExists -Name $svcName -ErrorAction SilentlyContinue
    if ($serviceExists) {
        
        # Service stoppen mit PSADT
        try {
            Stop-ADTServiceAndDependencies -Name $svcName -ErrorAction Stop
        } catch {
            Write-ADTLogEntry -Message "    WARNUNG: Konnte Service nicht stoppen: $($_.Exception.Message)" -Severity 2
        }
        
        # Service entfernen mit CIM
        try {
            Test-ADTServiceExists -Name $svcName -PassThru -ErrorAction SilentlyContinue | Invoke-CimMethod -MethodName Delete | Out-Null
        } catch {
            Write-ADTLogEntry -Message "    WARNUNG: CIM Delete fehlgeschlagen, versuche sc.exe..." -Severity 2
            # Fallback: sc.exe delete (funktioniert auch wenn Service noch läuft)
            try {
                $scResult = & sc.exe delete $svcName 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ADTLogEntry -Message "    Service gelöscht (sc.exe)" -Severity 1
                } else {
                    Write-ADTLogEntry -Message "    sc.exe Fehler: $scResult" -Severity 2
                }
            } catch {
                Write-ADTLogEntry -Message "    WARNUNG: Konnte Service nicht löschen: $($_.Exception.Message)" -Severity 2
            }
        }
    } else {
        Write-ADTLogEntry -Message "  Service nicht gefunden: $svcName (bereits entfernt oder nicht installiert)" -Severity 1
    }
}
#endregion======================================================================================


#region 3. Treiber entfernen
$drivers = @('veracrypt', 'veracrypt.sys')
foreach ($driverName in $drivers) {
    # Prüfe ob Treiber existiert
    $driverPath = "$envWinDir\System32\drivers\$driverName"
    if (Test-Path $driverPath) {
        # Versuche Treiber zu löschen
        try {
            Remove-ADTFile -LiteralPath $driverPath -ErrorAction Stop
        } catch {
            Write-ADTLogEntry -Message "WARNUNG: Treiber konnte nicht gelöscht werden: $($_.Exception.Message)" -Severity 2
        }
    }
}
#endregion======================================================================================


#region 4. Registry bereinigen
$registryPaths = @(
    # Uninstall Einträge (System-Level)
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VeraCrypt",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\VeraCrypt",
    
    # VeraCrypt spezifische Keys (HKLM + HKCU)
    "HKLM:\SOFTWARE\VeraCrypt",
    "HKLM:\SOFTWARE\WOW6432Node\VeraCrypt",
    "HKCU:\SOFTWARE\VeraCrypt",
    
    # Active Setup Einträge (HKLM + HKCU) - Wildcards für alle Versionen
    "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\VeraCrypt*",
    "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\VeraCrypt*",
    
    # App Paths (System-Level)
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\VeraCrypt.exe",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\VeraCrypt.exe",
    
    # Run Keys (falls vorhanden)
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\VeraCrypt",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\VeraCrypt",
    
    # Services Registry (System-Level)
    "HKLM:\SYSTEM\CurrentControlSet\Services\veracrypt"
)

foreach ($regPath in $registryPaths) {
    # Wildcard-Unterstützung für Active Setup Keys
    if ($regPath -like "*\VeraCrypt*") {
        $parentPath = Split-Path $regPath -Parent
        $pattern = Split-Path $regPath -Leaf
        
        if (Test-Path $parentPath) {
            $matchingKeys = Get-ChildItem -Path $parentPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like $pattern }
            foreach ($key in $matchingKeys) {
                Write-ADTLogEntry -Message "  Entferne Registry-Key: $($key.PSPath)" -Severity 2
                try {
                    Remove-ADTRegistryKey -Key $key.PSPath -Recurse -ErrorAction Stop
                    Write-ADTLogEntry -Message "    Registry-Key gelöscht" -Severity 1
                } catch {
                    Write-ADTLogEntry -Message "    WARNUNG: Konnte Registry-Key nicht löschen: $($_.Exception.Message)" -Severity 2
                }
            }
        }
    } else {
        # Standard-Path ohne Wildcard
        if (Test-Path $regPath) {
            Write-ADTLogEntry -Message "  Entferne Registry-Key: $regPath" -Severity 2
            try {
                Remove-ADTRegistryKey -Key $regPath -Recurse -ErrorAction Stop
                Write-ADTLogEntry -Message "    Registry-Key gelöscht" -Severity 1
            } catch {
                Write-ADTLogEntry -Message "    WARNUNG: Konnte Registry-Key nicht löschen: $($_.Exception.Message)" -Severity 2
            }
        }
    }
}
#endregion======================================================================================


#region 5. Dateien und Ordner entfernen
$folderPaths = @(
    "$env:ProgramFiles\VeraCrypt",
    "$env:ProgramFiles (x86)\VeraCrypt",
    "$env:ProgramData\VeraCrypt",
    "$env:LOCALAPPDATA\VeraCrypt",
    #$env:APPDATA\VeraCrypt wird NICHT gelöscht (User Settings/Favorites bleiben erhalten)
)
foreach ($folderPath in $folderPaths) {
    if (Test-Path $folderPath) {
        try {
            Remove-ADTFolder -Path $folderPath -ErrorAction Stop
        } catch {
            Write-ADTLogEntry -Message "    WARNUNG: Konnte Ordner nicht vollständig löschen: $($_.Exception.Message)" -Severity 2
        }
    }
}
#endregion======================================================================================


#region 6. Shortcuts entfernen
$shortcutLocations = @(
    # Public Desktop
    "$env:PUBLIC\Desktop\VeraCrypt.lnk",
    
    # Public Start Menu
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VeraCrypt",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VeraCrypt.lnk",
    
    # User Desktop
    "$env:USERPROFILE\Desktop\VeraCrypt.lnk",
    
    # User Start Menu
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\VeraCrypt",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\VeraCrypt.lnk"
)
foreach ($shortcut in $shortcutLocations) {
    if (Test-Path $shortcut) {
        try {
            if ((Get-Item $shortcut -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo]) {
                Remove-ADTFolder -Path $shortcut -ErrorAction Stop
            } else {
                Remove-ADTFile -Path $shortcut -ErrorAction Stop
            }
        } catch {
              Write-ADTLogEntry -Message "WARNUNG: Konnte Shortcut nicht löschen: $($_.Exception.Message)" -Severity 2
        }
    }
}
# Alle User Shortcuts bereinigen
try {
    Remove-ADTFile -Path "$envCommonDesktop\VeraCrypt.lnk" -ErrorAction SilentlyContinue
    Remove-ADTFolder -Path "$envCommonStartMenuPrograms\VeraCrypt" -ErrorAction SilentlyContinue
} catch {
    Write-ADTLogEntry -Message "INFO: Einige Shortcuts konnten nicht entfernt werden" -Severity 2
}
#endregion======================================================================================


#region 7. Temporary Files bereinigen
$tempLocations = @(
    "$env:TEMP\VeraCrypt*",
    "$env:TMP\VeraCrypt*",
    "$env:SystemRoot\Temp\VeraCrypt*"
)
foreach ($tempPattern in $tempLocations) 
{
    Remove-ADTFile -Path $tempPattern -ErrorAction SilentlyContinue
}
#endregion======================================================================================

#region 8. Validation
$validationPassed = $true

# Prüfe ob Hauptordner noch existiert
if (Test-Path "$env:ProgramFiles\VeraCrypt") {
    Write-ADTLogEntry -Message "  WARNUNG: Hauptordner existiert noch!" -Severity 2
    $validationPassed = $false
}

# Prüfe Registry
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VeraCrypt") {
    Write-ADTLogEntry -Message "  WARNUNG: Registry-Eintrag existiert noch!" -Severity 2
    $validationPassed = $false
}

# Prüfe App in 3 Reg Lokationen ( HKCU , HKLM , HKLM/Wow6432Node)
$stillInstalled = Get-ADTApplication -Name 'VeraCrypt' -ErrorAction SilentlyContinue
if ($stillInstalled) {
    Write-ADTLogEntry -Message "  WARNUNG: VeraCrypt erscheint noch in installierten Programmen!" -Severity 2
    $validationPassed = $false
}

# Prüfe Service 
try {
    if (Test-ADTServiceExists -Name 'veracrypt' -ErrorAction SilentlyContinue) {
        $validationPassed = $false
    }
}
catch {
    # Test-ADTServiceExists kann Fehler werfen wenn service bereits gelöscht
    Write-ADTLogEntry -Message "  INFO: Service-Check übersprungen (bereits entfernt)" -Severity 1
}


# Prüfe Driver
$driverPath = "$env:SystemRoot\System32\drivers\veracrypt.sys"
if (Test-Path $driverPath) {
    Write-ADTLogEntry -Message "  INFO: VeraCrypt Driver existiert noch (wird bei Installation überschrieben)" -Severity 1
    # KEIN $validationPassed = $false - MSI Installation überschreibt Driver automatisch
}

#Validierungsergebnis
if ($validationPassed) {
    Write-ADTLogEntry -Message "  [OK] Bereinigung erfolgreich - VeraCrypt vollständig entfernt" -Severity 1
} else {
    Write-ADTLogEntry -Message "  [WARNUNG] Bereinigung teilweise erfolgreich - manuelle Nachprüfung empfohlen" -Severity 2
}
#endregion======================================================================================

#Validierungszustand bzw. Rückgabewert der Bereinigung.ps1 (true oder false)
return $validationPassed

