<#
.SYNOPSIS
Encrypts OS drive with bitlocker, adds a recovery password and backs up to Azure AD 

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA
OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.

.DESCRIPTION
Script Features
    * Encrypts OS Drive with specified encryption method
    * If drive is already encrypted but not with specified encryption method, drive will be decrypted and re-ecrypted with correct encryption method
    * Checks for TPM Protector and adds if not present
    * Checks for Recovery Password Protector and adds if not present
    * Backs up Recovery Password to Azure AD
    * Logs written to Event Viewer 'Application' log under source 'Intune Bitlocker Encryption Script' 

.NOTES


.INPUTS
Designed to be run from Intune as Administrator. 
Update parameters to change default encryption method XtsAes256

.EXAMPLE
.\Enable_BitLocker_with_Logging.v4.03.ps1

#>

#Requires -Version 4.0
#-- Requires -PSSnapin <PSSnapin-Name> [-Version <N>[.<n>]]
#Requires -Modules TrustedPlatformModule, BitLocker
#-- Requires -ShellId <ShellId>
#Requires -RunAsAdministrator


#====================================================================================================
#                                             Parameters
#====================================================================================================
#region Parameters

[cmdletbinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $OSDrive = $env:SystemDrive,

    [parameter()]
    [string]
    [ValidateSet("XtsAes256", "XtsAes128", "Aes256", "Aes128")]
    $encryption_strength = "XtsAes256"
    )

#endregion Parameters

#====================================================================================================
#                                           Initialize
#====================================================================================================
#region  Initialize

# Provision new source for Event log
New-EventLog -LogName Application -Source "Intune Bitlocker Encryption Script" -ErrorAction SilentlyContinue

#endregion  Initialize

#====================================================================================================
#                                             Functions
#====================================================================================================
#region Functions

function Write-EventLogEntry {
    param (
        [parameter(Mandatory = $true, Position = 0)]
        [String]
        $Message,
        [parameter(Mandatory = $false, Position = 1)]
        [string]
        [ValidateSet("Information", "Error")]
        $type = "Information"
    )

    # Specify Parameters
    $log_params = @{
        Logname   = "Application"
        Source    = "Intune Bitlocker Encryption Script"
        Entrytype = $type
        EventID   = $(
            if ($type -eq "Information") { write-output 500 }
            else { Write-Output 501 }
        )
        Message   = $message
    }
    Write-EventLog @log_params
}


function Get-TPMStatus {
    # Returns true/false if TPM is ready
    $tpm = Get-Tpm
    if ($tpm.TpmReady -and $tpm.TpmPresent -eq $true) {
        return $true
    }
    else {
        return $false
    }
}

function Test-RecoveryPasswordProtector() {
    $AllProtectors = (Get-BitlockerVolume -MountPoint $OSDrive).KeyProtector
    $RecoveryProtector = ($AllProtectors | where-object { $_.KeyProtectorType -eq "RecoveryPassword" })
    if (($RecoveryProtector).KeyProtectorType -eq "RecoveryPassword") {
        Write-EventLogEntry -Message "Recovery password protector detected"
        return $true
    }
    else {
        Write-EventLogEntry "Recovery password protector not detected"
        return $false
    }
}

function Test-TpmProtector() {
    $AllProtectors = (Get-BitlockerVolume -MountPoint $OSDrive).KeyProtector
    $RecoveryProtector = ($AllProtectors | where-object { $_.KeyProtectorType -eq "Tpm" })
    if (($RecoveryProtector).KeyProtectorType -eq "Tpm") {
        Write-EventLogEntry -Message "TPM protector detected"
        return $true
    }
    else {
        Write-EventLogEntry "TPM protector not detected"
        return $false
    }
}

function Set-RecoveryPasswordProtector() {
    try {
        Add-BitLockerKeyProtector -MountPoint $OSDrive -RecoveryPasswordProtector 
        Write-EventLogEntry "Added recovery password protector to bitlocker enabled drive $OSDrive"
    }
    catch {
        throw Write-EventLogEntry "Error adding recovery password protector to bitlocker enabled drive" -type error
    }
}

function Set-TpmProtector() {
    try {
        Add-BitLockerKeyProtector -MountPoint $OSDrive -TpmProtector
        Write-EventLogEntry "Added TPM protector to bitlocker enabled drive $OSDrive"
    }
    catch {
        throw Write-EventLogEntry "Error adding TPM protector to bitlocker enabled drive" -type error
    }
}


function Backup-RecoveryPasswordProtector() {
    $AllProtectors = (Get-BitlockerVolume -MountPoint $OSDrive).KeyProtector
    $RecoveryProtector = ($AllProtectors | where-object { $_.KeyProtectorType -eq "RecoveryPassword" })

    try {
        BackupToAAD-BitLockerKeyProtector $OSDrive -KeyProtectorId $RecoveryProtector.KeyProtectorID
        Write-EventLogEntry "BitLocker recovery password has been successfully backup up to Azure AD"
    }
    catch {
        throw Write-EventLogEntry "Error backing up recovery password to Azure AD." -type error
    }
}

function Invoke-Encryption() {
    # Test that TPM is present and ready
    try {
        Write-EventLogEntry "Checking TPM Status before attempting encryption"
        if (Get-TPMStatus -eq $true) {
            Write-EventLogEntry "TPM Present and Ready. Beginning encryption process"
        }
    }
    catch {
        throw Write-EventLogEntry "Issue with TPM. Exiting script" -type error
    }

    # Encrypting OS drive
    try {
        Write-EventLogEntry "Enabling bitlocker with Recovery Password protector and method $encryption_strength"
        Enable-BitLocker -MountPoint $OSDrive -SkipHardwareTest -UsedSpaceOnly -EncryptionMethod $encryption_strength -RecoveryPasswordProtector
        Write-EventLogEntry "Bitlocker enabled on $OSDrive with $encryption_strength encryption method"
    }
    catch {
        throw Write-EventLogEntry "Error enabling bitlocker on $OSDRive. Exiting script" 
    }
}

function Invoke-UnEncryption() {
    # Call disable-bitlocker command, reboot after unencryption?
    try {
        Write-EventLogEntry "Unencrypting bitlocker enabled drive $OSDrive"
        Disable-BitLocker -MountPoint $OSDrive
    }
    catch {
        throw Write-EventLogEntry "Issue unencrypting bitlocker enabled drive $OSDrive"
    }
}


#endregion Functions




#====================================================================================================
#                                             Main-Code
#====================================================================================================
#region MainCode

# Start
Write-EventLogEntry -Message "Running bitlocker intune encryption script"

# Check if OS drive is ecrpyted with parameter $encryption_strength
if ((Get-BitLockerVolume -MountPoint $OSDrive).VolumeStatus -eq 'FullyEncrypted' -and (Get-BitLockerVolume -MountPoint $OSDrive).EncryptionMethod -eq $encryption_strength) {
    Write-EventLogEntry "BitLocker is already enabled on $OSDrive and the encryption method is correct"
}

# Drive is encrypted but does not meet set encryption method
elseif ((Get-BitLockerVolume -MountPoint $OSDrive).VolumeStatus -eq 'FullyEncrypted' -and (Get-BitLockerVolume -MountPoint $OSDrive).EncryptionMethod -ne $encryption_strength) {
    Write-EventLogEntry -Message "Bitlocker is enabled on $OSDrive but the encryption method does not meet set requirements"
    try {
        # Decrypt OS drive
        Invoke-UnEncryption
        # Wait for decryption to finish 
        Do {
            Start-Sleep -Seconds 30
        } until ((Get-BitLockerVolume).VolumeStatus -eq 'FullyDecrypted')
        Write-EventLogEntry -Message "$OSDrive has been fully decrypted"

        # Trigger encryption with specified encryption method 
        Invoke-Encryption
        Start-Sleep -Seconds 5
    }
    catch {
        throw Write-EventLogEntry -Message "Failed on encrypting $OSDrive after decryption" -type error
    }
}

# Drive is not FullyDecrypted
elseif ((Get-BitLockerVolume).VolumeStatus -eq 'FullyDecrypted') {
    Write-EventLogEntry "BitLocker is not enabled on $OSDrive"
    try {
        # Encrypt OS Drive with parameter $encryption_strength
        Invoke-Encryption
    }
    catch {
        throw Write-EventLogEntry -Message "Error thrown encrypting $OSDrive"
    }
}

# Test for Recovery Password Protector. If not found, add Recovery Password Protector
if (-not(Test-RecoveryPasswordProtector)) {
    try {
        Set-RecoveryPasswordProtector
    }
    catch {
        throw $_
    }
}

# Test for TPM Protector. If not found, add TPM Protector
if (-not(Test-TpmProtector)) {
    try {
        Set-TpmProtector
    }
    catch {
        throw $_
    }
    Write-EventLogEntry -Message "TPM and Recovery Password protectors are present"
}

# Finally backup the Recovery Password to Azure AD
try {
    Backup-RecoveryPasswordProtector
    }
catch {
    throw $_
    }

Write-EventLogEntry -Message "Script complete"

#endregion MainCode