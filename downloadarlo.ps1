param([string]$UserName, [string]$Password, [string]$BaseDir, [int]$TraceBackDays)

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

function GetSaveFileName
{
    param([string]$baseLocation, [string]$createdDate, [string]$deviceId, [string]$name, [string]$reason, [string]$contentType)

    $ext = "unknown"
    if($contentType -eq "video/mp4")
    {
        $ext = "mp4"
    }

    return "$baseLocation\$($createdDate)\$($reason.ToUpperInvariant())_$($deviceId)_$($name).$ext"
}

function DownloadArloRecords
{
    param([string]$userName, [string]$password, [string]$baseLocation, [int]$traceBackDays)

    $token = GetArloAccessToken $userName $password

    if($token -eq $null)
    {
        Write-Error "Failed to Get AccessToken"
        return
    }

    if($traceBackDays -ge 6)
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

        $dir = [System.IO.Path]::GetDirectoryName($fileName)
        if(-not (Test-Path $dir)) 
        {
            New-Item $dir -ItemType Directory -Force
        }

        Write-Host $record.presignedContentUrl
        Invoke-WebRequest $record.presignedContentUrl -OutFile $fileName
    }
}

DownloadArloRecords $UserName $Password $BaseDir $TraceBackDays
