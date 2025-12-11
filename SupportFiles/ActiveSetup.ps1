<#
.SYNOPSIS
    Konfiguriert Active Setup für VeraCrypt Benutzer-Einstellungen.
    
.DESCRIPTION
    Kopiert das VeraCryptUserConfig.ps1 Script nach ProgramData und registriert
    es als Active Setup, sodass jeder Benutzer beim ersten Login automatisch
    die VeraCrypt Standard-Konfiguration erhält.
    
.OUTPUTS
    Hashtable mit Informationen:
    - Success: Boolean, ob Active Setup erfolgreich konfiguriert wurde
    - ScriptPath: Pfad zum kopierten Active Setup Script
    - Version: Active Setup Version (Timestamp)
    
.EXAMPLE
    $activeSetupInfo = .\ActiveSetup.ps1
    
.NOTES
    Author: Ömür Koca
    Datum: 9.11.2025
    
#>

[CmdletBinding()]
param()

$success = $false
$scriptPath = $null
$version = $null

try {
    # Kopiere PowerShell-Script nach ProgramData
    $activeSetupScriptSource = "$PSScriptRoot\VeraCryptUserConfig.ps1"
    $activeSetupScriptDest = "$envProgramData\VeraCrypt\VeraCryptUserConfig.ps1"
    
    # Erstelle Zielverzeichnis
    New-ADTFolder -LiteralPath "$envProgramData\VeraCrypt"
    
    # Kopiere Script
     Copy-ADTFile -Path $activeSetupScriptSource -Destination $activeSetupScriptDest
    
    # Konfiguriere Active Setup mit automatischer Versionierung
    $activeSetupResult = Set-ADTActiveSetup -StubExePath "$envWinDir\System32\WindowsPowerShell\v1.0\powershell.exe" `
                                            -Arguments "-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -File `"$activeSetupScriptDest`"" `
                                            -Description "VeraCrypt Benutzer-Konfiguration" `
                                            -PassThru
    if ($activeSetupResult) {
        $success = $true
        $scriptPath = $activeSetupScriptDest
        $version = $activeSetupResult.Version
        
        Write-ADTLogEntry -Message "  Jeder Benutzer erhält beim ersten Login die Standard-Konfiguration,  Version: $version" -Severity 1
    }
    else {
        Write-ADTLogEntry -Message "  Active Setup Konfiguration fehlgeschlagen" -Severity 3
    }
}
catch {
    Write-ADTLogEntry -Message "  Fehler: $($_.Exception.Message)" -Severity 3
    throw
}

# Rückgabe-Objekt erstellen
return @{
    Success = $success
    ScriptPath = $scriptPath
    Version = $version
}
