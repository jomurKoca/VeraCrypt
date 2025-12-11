
[CmdletBinding()]
param
(
    # Default is 'Install'.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType,

    # Default is 'Auto'. Don't hard-code this unless required.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


#region: Variablen

$adtSession = @{
    # App variables.
    AppVendor = 'IDRIX'
    AppName = 'VeraCrypt'
    AppVersion = '1.26.7'
    AppArch = 'x64'
    AppLang = 'DE'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @('VeraCrypt', 'VeraCryptExpander')
    AppScriptVersion = '1.0.0'
    AppScriptDate = '03.11.2025'
    AppScriptAuthor = 'Ömür Koca'
    RequireAdmin = $true

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = 'VeraCrypt 1.26.7 Installation'
    InstallTitle = 'VeraCrypt Verschlüsselungssoftware'

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.7'
}

# DSM-MSIParams Äquivalent in PSADT
$msiArguments = @(
    "ALLUSERS=1"
    "REBOOT=ReallySuppress"
    "ACCEPTLICENSE=YES"
    "INSTALLSTARTMENUSHORTCUT=0"
    "INSTALLDESKTOPSHORTCUT=0"
    "ROOTDRIVE=C:\"
    "MSIRESTARTMANAGERCONTROL=Disable"
    "MSIDISABLERMRESTART=1"
    "/qn"
)
#=========================================================================================================================================================================================================


#region Helper-Funktion 
function Entferne-VorhandeneVeraCryptInstallationen {
    <#
        .SYNOPSIS
        Entfernt alle vorhandenen VeraCrypt-Installationen (MSI und EXE).

        .DESCRIPTION
        Sucht nach installierten VeraCrypt-Versionen und deinstalliert diese vollständig.
        
        Führt zunächst die Standard-Deinstallation durch (MSI oder EXE), anschließend
        wird das Bereinigungsskript "SupportFiles\Bereinigung.ps1" aufgerufen, um
        verbleibende Komponenten (Services, Drivers, Registry-Einträge) zu entfernen.
    #>

    [CmdletBinding()]
    param()


    foreach ($app in (Get-ADTApplication -Name 'VeraCrypt'))
    {
        if ($app.WindowsInstaller)
        {
            # MSI-Installation erkannt
            Start-ADTMsiProcess -Action 'Uninstall' -ProductCode $app.ProductCode -ArgumentList $msiArguments
        }
        else
        {
            # EXE-Installation erkannt
            Write-ADTLogEntry -Message "QuietUninstallString: $($app.QuietUninstallString)"
            
            if ($app.QuietUninstallString) {
                # QuietUninstallString vorhanden - verwende Uninstall-ADTApplication
                Uninstall-ADTApplication -InstalledApplication $app
                Start-Sleep -Seconds 10
            }
            else {  
                # Keine QuietUninstallString, Führe Bereinigung aus
                & "$PSScriptRoot\SupportFiles\Bereinigung.ps1"
                Start-Sleep -Seconds 10
            }
        }
    }
}    
#===========================================================================================================================================================




#region Install-Funktion
function Install-ADTDeployment
{
    [CmdletBinding()]
    param()

    #region Pre-Installation    
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"
    
    # Prozesse schließen über PSADT Welcome Dialog 
    # Countdown für das Schließen offener Prozesse aktivieren
    $saiwParams = @{
        AllowDefer = $true
        DeferTimes = 3  
        CheckDiskSpace = $true
        PersistPrompt = $true
        CloseProcessesCountdown = 3600
    }
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        $saiwParams.Add('CloseProcesses', $adtSession.AppProcessesToClose)
    }

    Show-ADTInstallationWelcome @saiwParams

    #Benutzer-Konfigurationen sichern
    $backupResult = & "$($adtSession.DirSupportFiles)\BackupUserConfigs.ps1"

    #Alte VeraCrypt-Versionen deinstallieren
    Entferne-VorhandeneVeraCryptInstallationen
    Start-Sleep -Seconds 5
    #========================================================================================
    
    #region Installation
    $adtSession.InstallPhase = $adtSession.DeploymentType
    Start-ADTMsiProcess -Action 'Install' -FilePath "$($adtSession.DirFiles)\VeraCrypt_Setup_x64_1.26.7.msi" -ArgumentList $msiArguments
    #========================================================================================
    
    #region Post-Installation
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    # Benutzer-Konfigurationen wiederherstellen
    if ($backupResult.ConfigsSaved) {
        & "$($adtSession.DirSupportFiles)\RestoreUserConfigs.ps1" -BackupPath $backupResult.BackupPath
    }

    # Active Setup: Benutzer-Konfiguration für alle User vorbereiten (erstellt nur wenn nicht vorhanden)
    & "$($adtSession.DirSupportFiles)\ActiveSetup.ps1"

    # Abschlussmeldung
    Show-ADTBalloonTip -BalloonTipText "VeraCrypt wurde erfolgreich installiert." -BalloonTipTitle "Installation Abgeschlossen"
    Write-ADTLogEntry -Message "VeraCrypt Installation erfolgreich abgeschlossen " -Severity 1
    #========================================================================================
}
#====================================================================================================================================================================================================


#region Uninstall-Funktion
function Uninstall-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    #region Pre-Uninstall    
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Willkommensnachricht für Deinstallation anzeigen, Prozesse schließen falls angegeben
    $saiwParams = 
    @{
        AllowDefer = $true
        DeferTimes = 3
        PersistPrompt = $true 
    }

    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        $saiwParams.Add('CloseProcesses', $adtSession.AppProcessesToClose)
    }
    Show-ADTInstallationWelcome @saiwParams
    ## Fortschrittsnachricht anzeigen
    Show-ADTInstallationProgress -StatusMessage "VeraCrypt wird deinstalliert..."
    #========================================================================================
    
    
    #region: Uninstall
    $adtSession.InstallPhase = $adtSession.DeploymentType

    # Alte VeraCrypt-Versionen deinstallieren
    Entferne-VorhandeneVeraCryptInstallationen
    #========================================================================================
    
    #region : Post-Uninstall
    Write-ADTLogEntry -Message "VeraCrypt MSI Deinstallation abgeschlossen." -Severity 1
    #Deinstallationsabschluss-Nachricht anzeigen
    Show-ADTInstallationPrompt -Message 'VeraCrypt wurde erfolgreich deinstalliert.' -ButtonRightText 'OK' -Icon Information -NoWait
    #========================================================================================
}
#=====================================================================================================================================================================================================







##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    # Import the module locally if available, otherwise try to find it from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf)
    {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.7' } -Force
    }
    else
    {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.7' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

# Commence the actual deployment operation.
try
{
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process
        {
            if ($_.Name -match 'PSAppDeployToolkit\..+$')
            {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3

    ## Error details hidden from the user by default. Show a simple dialog with full stack trace:
    # Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop -NoWait

    ## Or, a themed dialog with basic error message:
    # Show-ADTInstallationPrompt -Message "$($adtSession.DeploymentType) failed at line $($_.InvocationInfo.ScriptLineNumber), char $($_.InvocationInfo.OffsetInLine):`n$($_.InvocationInfo.Line.Trim())`n`nMessage:`n$($_.Exception.Message)" -ButtonRightText OK -Icon Error -NoWait

    Close-ADTSession -ExitCode 60001
}

