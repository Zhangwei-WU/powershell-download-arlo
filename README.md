# ps-download-arlo
powershell scripts to download arlo library to local

how to run: ps> .\downloadarlo.ps1 -UserName "<email address of arlo account>" -Password "<password of arlo account>" -BaseDir "<local disk root dir, eg. d:\arlo>" -TraceBackDays "<trace back days, from 0 to 6>"

or in cmd: > powershell.exe -Command ".\downloadarlo.ps1" -UserName "<email address of arlo account>" -Password "<password of arlo account>" -BaseDir "<local disk root dir, eg. d:\arlo>" -TraceBackDays "<trace back days, from 0 to 6>"

how to sign your ps script: https://community.spiceworks.com/how_to/153255-windows-10-signing-a-powershell-script-with-a-self-signed-certificate