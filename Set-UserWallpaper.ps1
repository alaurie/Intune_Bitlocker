<#
    .SYNOPSIS
    Downloads wallpaper from URI and enables it on the users profile

    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
    RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.

    .DESCRIPTION
    Script Features
    * Download wallpaper and set
 

    .NOTES
    Author: Alex Laurie alex.r.laurie@gmail.com

    Version: 0.01

    .INPUTS
    URI of wallpaper to downloaded (lock down to IP range)

    .EXAMPLE
    .\Set-UserWallpaper.ps1 -uri 'https://i.imgur.com/mywallpaper.jpeg

#>

[CmdletBinding()]
# Parameter help description
param(
    [Parameter(Mandatory)]
    [uri]
    $uri
)


#====================================================================================================
#                                             Functions
#====================================================================================================
#region Functions

function Set-Wallpaper {
    [cmdletbinding()]
    param(
    # Wallpaper file to be set
    [Parameter()]
    [string]
    $wallpaper
    )
    
    try {
        
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaper
        
        # Sleep required to reliably refresh the desktop to the new wallpaper
        Start-Sleep -Seconds 5
        RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters ,1 ,True
    }

    catch {
        throw Write-Verbose -Message "Error setting wallpaper. Check script"
    }
}

#endregion Functions

#====================================================================================================
#                                             Main-Code
#====================================================================================================
#region MainCode

try {
    
    #Download the Wallpaper to the users roaming data directory
    Write-Verbose -Message "Downloading wallpaper from specified parameter URI"
    $username = $env:USERNAME
    $wallpaper_path = "C:\Users\$username\appdata\Roaming\wallpaper.jpeg"
    Invoke-WebRequest -Uri $uri -OutFile $wallpaper_path
    Write-Verbose -Message "Wallpaper downloaded to $wallpaper_path"

    #Set the wallpaper to the desktop
    Write-Verbose -Message "Setting wallpaper"
    Set-Wallpaper -wallpaper $wallpaper_path
    Write-Verbose -Message "Wallpaper has been downloaded and set on the device"
}

Catch {
    Write-Verbose -Message "Error downloading and setting wallpaper to the desktop"
    throw $_
}

#endregion MainCode