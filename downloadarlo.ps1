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

    $response | ConvertTo-Json | Write-Host
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

    $response | ConvertTo-Json | Write-Host
    return $null
}

function GetDeviceName
{
	param([string]$deviceId)
	
    $deviceName = $deviceId
    #if($deviceId -eq "some device id...")
    #{
    #    $deviceName = "some devie name..."
    #}
	
	return $deviceName
}

function GetSaveFileName
{
    param([string]$baseLocation, [string]$createdDate, [string]$deviceId, [string]$name, [string]$reason, [string]$contentType)

	$deviceName = GetDeviceName $deviceId
	
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

    return "$baseLocation\$($createdDate)\$($reason.ToUpperInvariant())_$($deviceName)_$($name).$ext"
}

function GetFfmpegDrawText
{
    param([long]$createdTime, [string]$deviceId)
	
	$deviceName = (GetDeviceName $deviceId).ToUpperInvariant()

	# https://ffmpeg.org/ffmpeg-filters.html#drawtext-1
	return "drawtext=font=Lucida Console:fontcolor=white:fontsize=32:x=8:y=8:box=1:boxcolor=black@0.7:boxborderw=8:text='%{pts\:localtime\:$($createdTime / 1000)} LOCATION\: $deviceName'"
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
        $fileName = GetSaveFileName $baseLocation $record.createdDate $record.deviceId $record.name $record.reason $record.contentType
        Write-Host $fileName

        if(Test-Path $fileName)
        {
            continue
        }

		$ext = [System.IO.Path]::GetExtension($fileName)
		
		$tempFileName = "$($env:temp)\$(New-Guid)$ext"
		Write-Host "Download $($record.presignedContentUrl) to $tempFileName"
        Invoke-WebRequest $record.presignedContentUrl -OutFile $tempFileName

        $dir = [System.IO.Path]::GetDirectoryName($fileName)
        if(-not (Test-Path $dir)) 
        {
            New-Item $dir -ItemType Directory -Force
        }
		
		if($addTimeStamp -and $ext -eq ".mp4" -and (Test-Path "ffmpeg.exe"))
		{
			$tempOutFileName = "$($env:temp)\$(New-Guid)$ext"
			$vfParams = GetFfmpegDrawText $record.localCreatedDate $record.deviceId
			Write-Host $vfParams
			Start-Process "ffmpeg.exe" -ArgumentList @("-i", $tempFileName, "-vf", "`"$vfParams`"", $tempOutFileName) -NoNewWindow -Wait
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
		
		Move-Item -Path $tempFileName -Destination $fileName
    }
}

DownloadArloRecords $UserName $Password $BaseDir $TraceBackDays $($AddTimeStamp.IsPresent)
