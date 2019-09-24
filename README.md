# powershell-download-arlo
powershell script to download arlo library to local, also add running timestamp to the video clip! 


## how to use
how to run: ps> .\downloadarlo.ps1 
-UserName "<email address of arlo account>" -Password "<password of arlo account>" 
-BaseDir "<local disk root dir, eg. d:\arlo>" -TraceBackDays "<trace back days, from 0 to 6>" \[-AddTimeStamp\]

or in cmd: > powershell.exe -Command ".\downloadarlo.ps1" 
-UserName "<email address of arlo account>" -Password "<password of arlo account>" 
-BaseDir "<local disk root dir, eg. d:\arlo>" -TraceBackDays "<trace back days, from 0 to 6>" \[-AddTimeStamp\]

## (optional) how to sign your powershell script (for security purpose)
how to sign your ps script: https://community.spiceworks.com/how_to/153255-windows-10-signing-a-powershell-script-with-a-self-signed-certificate

or, you can skip sign check by: powershell.exe -ExecutionPolicy ByPass

## download your arlo library to cloud storage services
setup a schedule job to run script for every 30 mins (or any interval as you like), download to local disk, setup onedrive/dropbox or any other cloud storage solutions to sync your local disk to cloud


## customize
feel free to customize whatever you want :) 

## how to use -AddTimeStamp
download ffmpeg.exe from https://ffmpeg.org unzip it, put ffmpeg.exe to the same directory of this powershell script

modify function GetFfmpegDrawText if you want to customize running timestamp text format


example:
![video with timestamp](https://github.com/Zhangwei-WU/powershell-download-arlo/raw/master/screenshoot.jpg "video with timestamp")

issues:
* ffmpeg will output larger file size videos