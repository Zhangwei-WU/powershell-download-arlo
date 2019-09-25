param([string]$UserName, [string]$Password, [string]$BaseDir, [int]$TraceBackDays, [switch]$AddTimeStamp)

function GetArloAccessToken
{
    param ([string]$userName, [string]$password)

    $request = "{`"email`":`"$userName`",`"password`":`"$([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($password)))`",`"language`":`"en`",`"EnvSource`":`"prod`"}"
    
    $response = Invoke-RestMethod -Method Post -Uri "https://ocapi-app.arlo.com/api/auth" -Body $request -ContentType "application/json"

    if($? -and $response.meta.code -eq 200)
    {
        return $response.data.token
    }

    $response | ConvertTo-Json | Write-Error
    return $null
}

function GetArloLibrary
{
    param([string]$token, [string]$datefrom, [string]$dateto)

    $headers = @{
        "authorization" = $token
        "auth-version" = "2"
    }

    $request = "{`"dateFrom`":`"$datefrom`",`"dateTo`":`"$dateto`"}"

    $response = Invoke-RestMethod -Method Post -Uri "https://my.arlo.com/hmsweb/users/library" -Body $request -ContentType "application/json" -Headers $headers

    if($? -and $response.success -eq $true)
    {
        return $response.data
    }

    $response | ConvertTo-Json | Write-Error
    return $null
}

function GetArloDeviceInfo
{
    param([string]$token)

    $headers = @{
        "authorization" = $token
        "auth-version" = "2"
    }

    $response = Invoke-RestMethod -Method Get -Uri "https://my.arlo.com/hmsweb/users/serviceLevel/v4" -Headers $headers

    if($? -and $response.success -eq $true)
    {
        $devices = @{};
        foreach($device in $response.data.planDetails.devicesEnabled)
        {
            $devices.Add($device.deviceId, $device)
        }

        return $devices
    }

    $response | ConvertTo-Json | Write-Error
    return $null
}


function GetLocalTime
{
    param([long]$epochMilliseconds)

    $timeZone = Get-TimeZone
    $adjustMilliseconds = $timeZone.BaseUtcOffset.TotalMilliseconds
    if($timeZone.SupportsDaylightSavingTime)
    {
        $adjustMilliseconds += 3600000
    }

    return (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0).AddMilliseconds($epochMilliseconds + $adjustMilliseconds)
}

function GetSaveFileName
{
    param([string]$baseLocation, [long]$createdTime, [string]$deviceId, [string]$deviceName, [string]$reason, [string]$contentType)

    $deviceName = $deviceName.Trim().Replace(' ', '_')

    $ext = "unknown"
    if($contentType -eq "video/mp4")
    {
        $ext = "mp4"
    }
	elseif($contentType -eq "image/jpg")
    {
        $ext = "jpg"
    }
	else
	{
		Write-Error "Unknown ContentType: $contentType"
	}
    
    if(-not [System.String]::IsNullOrEmpty($reason) -and $reason.ToUpperInvariant().EndsWith("RECORD"))
    {
        $reason = $reason.Substring(0, $reason.Length - 6)
        if([System.String]::IsNullOrEmpty($reason))
        {
            $reason = "Manual"
        }
    }

    $hms = GetLocalTime $createdTime

    $datepart = $hms.ToString("yyyyMMdd")
    $timepart = $hms.ToString("HHmmss")

    return "$baseLocation\$datepart\$($reason.ToUpperInvariant())_$($deviceName)_$($timepart).$ext"
}

function GetFfmpegDrawText
{
    param([long]$createdTime, [string]$deviceId, [string]$deviceName)
	
	# https://ffmpeg.org/ffmpeg-filters.html#drawtext-1
	return "drawtext=font=Lucida Console:fontcolor=white:fontsize=32:x=8:y=8:box=1:boxcolor=black@0.7:boxborderw=8:text='%{pts\:localtime\:$($createdTime / 1000)} | $deviceId | $($deviceName.ToUpperInvariant())'"
}

function DownloadArloRecords
{
    param([string]$userName, [string]$password, [string]$baseLocation, [int]$traceBackDays, [bool]$addTimeStamp)

    $token = GetArloAccessToken $userName $password

    if($token -eq $null)
    {
        Write-Error "Failed to Get AccessToken"
        return
    }

    $devices = GetArloDeviceInfo $token
    
    if($devices -eq $null)
    {
        Write-Error "Failed to Get Devices"
        return
    }

    if($traceBackDays -gt 6)
    {
        $traceBackDays = 6
    }

    $toDate = Get-Date
    $fromDate = $toDate.AddDays(-$traceBackDays)
    
    $library = GetArloLibrary $token ($fromDate.ToString("yyyyMMdd")) ($toDate.ToString("yyyyMMdd"))

    if($library -eq $null)
    {
        Write-Error "Failed to Get Library"
        return
    }

    foreach($record in $library)
    {
        $deviceName = $devices[$record.deviceId].deviceName

        Write-Host $deviceName
        $fileName = GetSaveFileName $baseLocation $record.localCreatedDate $record.deviceId $deviceName $record.reason $record.contentType

        if(Test-Path $fileName)
        {
            Write-Host "$fileName already downloaded"
            continue
        }
        else
        {
            Write-Host "$fileName downloading"
        }

		$ext = [System.IO.Path]::GetExtension($fileName)
		
		$tempFileName = "$($env:temp)\$(New-Guid)$ext"
		Write-Host "Download $($record.presignedContentUrl) to $tempFileName"
        Invoke-WebRequest $record.presignedContentUrl -OutFile $tempFileName
		
		if($addTimeStamp -and $ext -eq ".mp4" -and (Test-Path "ffmpeg.exe"))
		{
			$tempOutFileName = "$($env:temp)\$(New-Guid)$ext"
			$vfParams = GetFfmpegDrawText $record.localCreatedDate $record.deviceId $deviceName
			Start-Process ".\ffmpeg.exe" -ArgumentList @("-i", $tempFileName, "-vf", "`"$vfParams`"", $tempOutFileName) -NoNewWindow -Wait
			if(Test-Path $tempOutFileName)
			{
				Remove-Item -LiteralPath $tempFileName
				$tempFileName = $tempOutFileName
			}
			else
			{
				Write-Error "cannot find ffmpeg output"
			}
		}
		
        $dir = [System.IO.Path]::GetDirectoryName($fileName)
        if(-not (Test-Path $dir)) 
        {
            New-Item $dir -ItemType Directory -Force
        }

		Move-Item -Path $tempFileName -Destination $fileName
    }
}

DownloadArloRecords $UserName $Password $BaseDir $TraceBackDays $($AddTimeStamp.IsPresent)
