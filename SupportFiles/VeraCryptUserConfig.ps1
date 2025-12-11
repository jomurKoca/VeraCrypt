<#
.SYNOPSIS
    VeraCrypt User Configuration Script - Active Setup
    
.DESCRIPTION
    Dieses Skript wird bei jedem ersten Login eines Benutzers durch Active Setup ausgeführt.
    Es konfiguriert benutzerspezifische VeraCrypt-Einstellungen.
    
    Das Skript erstellt die Standard-Konfiguration nur wenn noch keine existiert (Guard Clause).
    Bestehende Benutzer-Einstellungen werden NICHT überschrieben.
    
.OUTPUTS
    Exit Code:
    - 0: Erfolgreich (neue Config erstellt oder existierende übersprungen)
    - 1: Fehler aufgetreten (siehe Log-Datei)
    
    Log-Datei: $env:TEMP\VeraCryptUserSetup.log
    
.EXAMPLE
    # Manuell ausführen (nur für Tests)
    .\VeraCryptUserConfig.ps1
    
    # Exit Code prüfen
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Setup erfolgreich"
    }
    
.EXAMPLE
    # Log-Datei anzeigen
    notepad "$env:TEMP\VeraCryptUserSetup.log"
    
.EXAMPLE
    # Help anzeigen
    Get-Help .\VeraCryptUserConfig.ps1 -Full
    Get-Help .\VeraCryptUserConfig.ps1 -Examples
    
.NOTES
    Datei: VeraCryptUserConfig.ps1
    Autor: Ömür Koca
    Datum: 10.11.2025
    
    WICHTIG: Dieses Script wird normalerweise durch Active Setup automatisch
    aufgerufen. Manuelle Ausführung nur für Testing!
    
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$logPath = "$env:TEMP\VeraCryptUserSetup.log"

try {
    # log starten
    "=====================================================================" | Out-File $logPath -Append
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - VeraCrypt User Setup gestartet" | Out-File $logPath -Append
    "Benutzer: $env:USERNAME" | Out-File $logPath -Append
    "Computer: $env:COMPUTERNAME" | Out-File $logPath -Append
    "=====================================================================" | Out-File $logPath -Append
    
    # VeraCrypt Configuration Verzeichnis
    $configDir = "$env:APPDATA\VeraCrypt"
    
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        "  [OK] Verzeichnis erstellt: $configDir" | Out-File $logPath -Append
    }
    else {
        "  [INFO] Verzeichnis existiert bereits: $configDir" | Out-File $logPath -Append
    }
    
    # Configuration.xml Datei
    $configFile = "$configDir\Configuration.xml"
    


    # PRÜFUNG: Existiert bereits eine Konfiguration?
    if (Test-Path $configFile) {
        "  [INFO] Configuration.xml existiert bereits - WIRD NICHT ÜBERSCHRIEBEN" | Out-File $logPath -Append
        "  [INFO] Benutzer-Einstellungen bleiben erhalten" | Out-File $logPath -Append
        "  [INFO] Pfad: $configFile" | Out-File $logPath -Append
        "=====================================================================" | Out-File $logPath -Append
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - VeraCrypt User Setup ÜBERSPRUNGEN (Config existiert)" | Out-File $logPath -Append
        "=====================================================================" | Out-File $logPath -Append
        exit 0
    }
    


    
    # Dynamische Werte für XML-Kommentar
    $deploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $currentUser = $env:USERNAME
    $computerName = $env:COMPUTERNAME
    
    # Standard-XML-Konfiguration für dpma
    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- ========================================================================== -->
<!-- VeraCrypt Dpma Configuration - Deployed via PSADT Active Setup       -->
<!-- Diese Datei wurde automatisch erstellt von: VeraCryptUserConfig.ps1        -->
<!-- Erstellt am: $deploymentDate                                               -->
<!-- Benutzer: $currentUser @ $computerName                                     -->
<!-- ========================================================================== -->
<VeraCrypt>
    <configuration>
        <config key="OpenExplorerWindowAfterMount">0</config>
        <config key="UseDifferentTrayIconIfVolumesMounted">1</config>
        <config key="SaveVolumeHistory">0</config>
        <config key="CachePasswords">0</config>
        <config key="CachePasswordDuringMultipleMount">0</config>
        <config key="WipePasswordCacheOnExit">0</config>
        <config key="WipeCacheOnAutoDismount">1</config>
        <config key="IncludePimInCache">0</config>
        <config key="TryEmptyPasswordWhenKeyfileUsed">0</config>
        <config key="StartOnLogon">0</config>
        <config key="MountDevicesOnLogon">0</config>
        <config key="MountFavoritesOnLogon">0</config>
        <config key="MountVolumesReadOnly">0</config>
        <config key="MountVolumesRemovable">0</config>
        <config key="PreserveTimestamps">1</config>
        <config key="ShowDisconnectedNetworkDrives">0</config>
        <config key="HideWaitingDialog">0</config>
        <config key="UseSecureDesktop">1</config>
        <config key="UseLegacyMaxPasswordLength">0</config>
        <config key="EnableBackgroundTask">0</config>
        <config key="CloseBackgroundTaskOnNoVolumes">0</config>
        <config key="DismountOnLogOff">1</config>
        <config key="DismountOnSessionLocked">0</config>
        <config key="DismountOnPowerSaving">0</config>
        <config key="DismountOnScreenSaver">0</config>
        <config key="ForceAutoDismount">1</config>
        <config key="MaxVolumeIdleTime">-60</config>
        <config key="HiddenSectorDetectionStatus">0</config>
        <config key="UseKeyfiles">0</config>
        <config key="CloseSecurityTokenSessionsAfterMount">0</config>
        <config key="EMVSupportEnabled">0</config>
        <config key="HotkeyModAutoMountDevices">0</config>
        <config key="HotkeyCodeAutoMountDevices">0</config>
        <config key="HotkeyModDismountAll">0</config>
        <config key="HotkeyCodeDismountAll">0</config>
        <config key="HotkeyModWipeCache">0</config>
        <config key="HotkeyCodeWipeCache">0</config>
        <config key="HotkeyModDismountAllWipe">0</config>
        <config key="HotkeyCodeDismountAllWipe">0</config>
        <config key="HotkeyModForceDismountAllWipe">0</config>
        <config key="HotkeyCodeForceDismountAllWipe">0</config>
        <config key="HotkeyModForceDismountAllWipeExit">0</config>
        <config key="HotkeyCodeForceDismountAllWipeExit">0</config>
        <config key="HotkeyModMountFavoriteVolumes">0</config>
        <config key="HotkeyCodeMountFavoriteVolumes">0</config>
        <config key="HotkeyModShowHideMainWindow">0</config>
        <config key="HotkeyCodeShowHideMainWindow">0</config>
        <config key="HotkeyModCloseSecurityTokenSessions">0</config>
        <config key="HotkeyCodeCloseSecurityTokenSessions">0</config>
        <config key="PlaySoundOnHotkeyMountDismount">1</config>
        <config key="DisplayMsgBoxOnHotkeyDismount">1</config>
        <config key="Language">de</config>
        <config key="SecurityTokenLibrary"></config>
        <config key="DefaultPRF">0</config>
    </configuration>
</VeraCrypt>
"@
    
    # Configuration.xml schreiben
    $xmlContent | Out-File -FilePath $configFile -Encoding UTF8 -Force
    "Configuration.xml erstellt: $configFile" | Out-File $logPath -Append
    exit 0
}
catch {
    "StackTrace: $($_.ScriptStackTrace)" | Out-File $logPath -Append
    exit 1
}
