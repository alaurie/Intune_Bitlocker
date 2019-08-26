# About

[![License] [license-badge]] [license]

Various scripts to help deploy Microsoft Intune projects.

## Enable_Bitlocker_with_Logging
* Encrypts OS Drive with specified encryption method
* If drive is already encrypted but not with specified encryption method, drive will be decrypted and re-ecrypted with correct encryption method
* Checks for TPM Protector and adds if not present
* Checks for Recovery Password Protector and adds if not present
* Backs up Recovery Password to Azure AD
* Logs written to Event Viewer 'Application' log under source 'Intune Bitlocker Encryption Script'


## Set-UserWallpaper
* Downloads wallpaper from URI and set's it on the user profile


[license]: https://github.com/alaurie/intune/blob/master/LICENSE