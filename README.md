# ps-download-arlo
powershell scripts to download arlo library to local


## how to use
how to run: ps> .\downloadarlo.ps1 -UserName "<email address of arlo account>" -Password "<password of arlo account>" -BaseDir "<local disk root dir, eg. d:\arlo>" -TraceBackDays "<trace back days, from 0 to 6>"

or in cmd: > powershell.exe -Command ".\downloadarlo.ps1" -UserName "<email address of arlo account>" -Password "<password of arlo account>" -BaseDir "<local disk root dir, eg. d:\arlo>" -TraceBackDays "<trace back days, from 0 to 6>"

## (optional) how to sign your powershell script (for security puropse)
how to sign your ps script: https://community.spiceworks.com/how_to/153255-windows-10-signing-a-powershell-script-with-a-self-signed-certificate


## download your arlo library to cloud storage services
setup a schedule job to run script for every 30 mins (or any interval as you like), download to local directory, setup onedrive/dropbox or any other cloud storage solutions to sync your local disk to cloud


## customize
feel free to customize whatever you want :) 