<#
.SYNOPSIS
    Sichert VeraCrypt Benutzer-Konfigurationen vor Uninstall.
    
.DESCRIPTION
    Erstellt ein Backup aller Benutzer-Konfigurationen (AppData\Roaming\VeraCrypt)
    in einem temporären Ordner. Dies schützt die Einstellungen vor MSI/EXE Uninstaller,
    die standardmäßig Benutzer-Ordner löschen.
    
.PARAMETER BackupPath
    Optionaler Pfad für das Backup. Standard: $env:TEMP\VeraCryptConfigBackup_<Timestamp>
    
.OUTPUTS
    Hashtable mit Backup-Informationen:
    - BackupPath: Pfad zum Backup-Ordner
    - ConfigsSaved: Boolean, ob Configs gesichert wurden
    - UserCount: Anzahl der gesicherten Benutzer
    
.EXAMPLE
    $backupInfo = .\BackupUserConfigs.ps1
    
.NOTES
    Author: Ömür Koca
    Datum: 12.11.2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BackupPath = "$env:TEMP\PSADT_UserConfigBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

$configsSaved = $false
$userCount = 0

try {
    # Alle Benutzerprofile abrufen (außer Default)
    $userProfiles = Get-ADTUserProfiles -ExcludeDefaultUser
    Write-ADTLogEntry -Message "Gefundene Benutzerprofile: $($userProfiles.Count)" -Severity 1
    
    foreach ($profile in $userProfiles) {
        $userConfigPath = "$($profile.ProfilePath)\AppData\Roaming\VeraCrypt"
        
        if (Test-Path $userConfigPath) {
            
            # Backup-Pfad für diesen Benutzer erstellen
            $userBackupPath = "$BackupPath\$($profile.NTAccount)"
            Write-ADTLogEntry -Message "    Ziel: $userBackupPath" -Severity 1
            
            # Backup-Ordner erstellen
            New-ADTFolder -LiteralPath $userBackupPath
            
            # Dateien kopieren
            Copy-ADTFile -Path "$userConfigPath\*" -Destination $userBackupPath -Recurse -ErrorAction Stop
            
            $configsSaved = $true
            $userCount++
        }
        else {
            Write-ADTLogEntry -Message "  Benutzer: $($profile.NTAccount) - Keine Konfiguration gefunden" -Severity 2
        }
    }
    
    if ($configsSaved) {
        Write-ADTLogEntry -Message "  Gesicherte Benutzer: $userCount" -Severity 1
    }
    else {
        Write-ADTLogEntry -Message "  Grund: Keine Benutzer-Konfigurationen gefunden" -Severity 2
    }
}
catch {
    Write-ADTLogEntry -Message "  Fehler: $($_.Exception.Message)" -Severity 3
    throw
}

# Rückgabe-Objekt erstellen
return @{
    BackupPath = $BackupPath
    ConfigsSaved = $configsSaved
    UserCount = $userCount
}
