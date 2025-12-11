<#
.SYNOPSIS
    Stellt VeraCrypt Benutzer-Konfigurationen nach Uninstall wieder her.
    
.DESCRIPTION
    Kopiert gesicherte Benutzer-Konfigurationen zurück nach AppData\Roaming\VeraCrypt.
    Dies stellt die Einstellungen wieder her, nachdem MSI/EXE Uninstaller sie gelöscht hat.
    
.PARAMETER BackupPath
    Pfad zum Backup-Ordner (von BackupUserConfigs.ps1 erstellt)
    
.PARAMETER CleanupBackup
    Löscht den Backup-Ordner nach erfolgreicher Wiederherstellung (Standard: $true)
    
.OUTPUTS
    Hashtable mit Restore-Informationen:
    - Success: Boolean, ob Wiederherstellung erfolgreich war
    - UserCount: Anzahl der wiederhergestellten Benutzer
    
.EXAMPLE
    $backupInfo = .\BackupUserConfigs.ps1
    .\RestoreUserConfigs.ps1 -BackupPath $backupInfo.BackupPath
    
.NOTES
    Author: Ömür Koca
    Datum: 12.11.2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,
    
    [Parameter(Mandatory = $false)]
    [bool]$CleanupBackup = $true
)

# Prüfen ob Backup existiert
if (-not (Test-Path $BackupPath)) {
    Write-ADTLogEntry -Message "WARNUNG: Backup-Ordner nicht gefunden" -Severity 2
    
    return @{
        Success = $false
        UserCount = 0
    }
}

$userCount = 0
$success = $true

try {
     # Alle Benutzerprofile abrufen
    $userProfiles = Get-ADTUserProfiles -ExcludeDefaultUser
    
    foreach ($profile in $userProfiles) {
        $userBackupPath = "$BackupPath\$($profile.NTAccount)"
        $userConfigPath = "$($profile.ProfilePath)\AppData\Roaming\VeraCrypt"
        
        if (Test-Path $userBackupPath) {
            
            # Ziel-Ordner erstellen
            New-ADTFolder -LiteralPath $userConfigPath
            
            # Dateien zurückkopieren
            Copy-ADTFile -Path "$userBackupPath\*" -Destination $userConfigPath -Recurse -ErrorAction Stop
            $userCount++
        }
        else {
            Write-ADTLogEntry -Message "  Benutzer: $($profile.NTAccount) - Kein Backup gefunden" -Severity 2
        }
    }
    Write-ADTLogEntry -Message "  Wiederhergestellte Benutzer: $userCount" -Severity 1
   
    # Backup-Ordner aufräumen
    if ($CleanupBackup) {
        Remove-ADTFile -Path $BackupPath -Recurse -ErrorAction SilentlyContinue
    }
}
catch {
    Write-ADTLogEntry -Message "  Fehler: $($_.Exception.Message)" -Severity 3
    $success = $false
}

# Rückgabe-Objekt erstellen
return @{
    Success = $success
    UserCount = $userCount
}
