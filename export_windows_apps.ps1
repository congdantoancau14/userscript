$DesktopPath = "$env:USERPROFILE\Desktop"
$Path = "$DesktopPath\AppList"
if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }

Add-Type -AssemblyName System.Drawing
$AppsList = New-Object System.Collections.Generic.List[Object]

function Format-Size {
    param ([double]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -gt 0) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "N/A"
}

# 1. SCAN REGISTRY (Desktop Apps)
$RegistryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$RegApps = Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and $_.ParentKeyName -eq $null }

$i = 0
$totalReg = $RegApps.Count

foreach ($App in $RegApps) {
    $i++
    $percent = [math]::Round(($i / $totalReg) * 100)
    Write-Progress -Activity "Scanning Desktop Apps" -Status "Processing ($i/$totalReg): $($App.DisplayName)" -PercentComplete $percent

    $IconPath = ""
    if ($App.DisplayIcon) { 
        $CleanIcon = $App.DisplayIcon -replace '",.*$', '' -replace ',.*$', '' -replace '"', ''
        if (Test-Path $CleanIcon) { $IconPath = $CleanIcon }
    }
    
    if (!$IconPath -and $App.InstallLocation -and (Test-Path $App.InstallLocation)) { 
        $ExeFiles = Get-ChildItem -Path $App.InstallLocation -Filter *.exe -Recurse -ErrorAction SilentlyContinue
        if ($ExeFiles) { $IconPath = $ExeFiles[0].FullName }
    }

    $Publisher = $App.Publisher
    if (!$Publisher) { $Publisher = "Unknown Publisher" }

    $SizeBytes = 0
    if ($App.EstimatedSize) {
        $SizeBytes = [double]$App.EstimatedSize * 1KB
    } elseif ($App.InstallLocation -and (Test-Path $App.InstallLocation)) {
        $SizeBytes = (Get-ChildItem -Path $App.InstallLocation -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    }

    $AppsList.Add([PSCustomObject]@{
        Name        = $App.DisplayName
        Publisher   = $Publisher
        Version     = $App.DisplayVersion
        SizeBytes   = $SizeBytes
        DisplaySize = (Format-Size -Bytes $SizeBytes)
        Type        = "Desktop App"
        Icon        = $IconPath
    })
}

# 2. SCAN MICROSOFT STORE APPS (UWP)
$StoreApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { !$_.IsFramework -and $_.NonRemovable -ne $true }
$j = 0
$totalStore = $StoreApps.Count

foreach ($App in $StoreApps) {
    $j++
    $percent = [math]::Round(($j / $totalStore) * 100)
    Write-Progress -Activity "Scanning Microsoft Store Apps" -Status "Processing ($j/$totalStore): $($App.Name)" -PercentComplete $percent

    $Manifest = Get-AppxPackageManifest $App -ErrorAction SilentlyContinue
    $Name = $Manifest.Package.Properties.DisplayName
    if ($Name -like "ms-resource:*") { $Name = $App.Name }
    if (!$Name) { $Name = $App.Name }
    
    $Publisher = $App.PublisherId
    if ($Manifest.Package.Properties.PublisherDisplayName) {
        $Publisher = $Manifest.Package.Properties.PublisherDisplayName
    }
    if (!$Publisher) { $Publisher = "Microsoft Corporation" }
    
    $AppFolder = $App.InstallLocation
    $LogoPath = ""
    $SizeBytes = 0

    if ($AppFolder -and (Test-Path $AppFolder)) {
        $LogoFiles = Get-ChildItem -Path $AppFolder -Include *Square44x44Logo*.png, *StoreLogo*.png, *SmallTile*.png, *logo*.png, *icon*.png -Recurse -ErrorAction SilentlyContinue
        if ($LogoFiles) { $LogoPath = $LogoFiles[0].FullName }
        $SizeBytes = (Get-ChildItem -Path $AppFolder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    }

    $AppsList.Add([PSCustomObject]@{
        Name        = $Name
        Publisher   = $Publisher
        Version     = $App.Version
        SizeBytes   = $SizeBytes
        DisplaySize = (Format-Size -Bytes $SizeBytes)
        Type        = "Microsoft Store"
        Icon        = $LogoPath
    })
}

# 3. DEDUPLICATE & SORT
$UniqueApps = $AppsList | Group-Object Name | ForEach-Object { $_.Group[0] } | Sort-Object Name

# 4. EXPORT TO CSV
$CsvPath = "$DesktopPath\AppList.csv"
$UniqueApps | Select-Object @{N='Application Name';E={$_.Name}}, 
                            @{N='Publisher';E={$_.Publisher}}, 
                            @{N='Version';E={$_.Version}}, 
                            @{N='Size';E={$_.DisplaySize}}, 
                            @{N='Type';E={$_.Type}}, 
                            @{N='Icon Path';E={$_.Icon}} | 
    Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

# 5. GENERATE HTML
$DefaultSvgBase64 = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iIzAwNzhkNCI+PHBhdGggZD0iTTE5LjE0IDEyLjk0Yy4wNC0uMy4wNi0uNjEuMDYtLjk0IDAtLjMyLS4wMi0uNjQtLjA3LS45NGwyLjAzLTEuNThjLjE4LS4xNC4yMy0uNDEuMTItLjYxbC0xLjkyLTMuMzJjLS4xMi0uMjItLjM3LS4yOS0uNTktLjIybC0yLjM5Ljk2Yy0uNS0uMzgtMS4wMy0uNy0xLjYyLS45NGwtLjM2LTIuNTRjLS4wNC0uMjQtLjI0LS40MS0uNDgtLjQxaC0zLjg0Yy0uMjQgMC0uNDMuMTctLjQ3LjQxbC0uMzYgMi41NGMtLjU5LjI0LTEuMTMuNTctMS42Mi45NGwtMi4zOS0uOTZjLS4yMi0uMDgtLjQ3IDAtLjU5LjIybC0xLjkyIDMuMzJjLS4xMi4yMS0uMDguNDcuMTIuNjFsMi4wMyAxLjU4Yy0uMDUuMy0uMDkuNjMtLjA5Ljk0cy4wMi42NC4wNy45NGwtMi4wMyAxLjU4Yy0uMTguMTQtLjIzLjQxLS4xMi42MWwxLjkyIDMuMzJjLjEyLjIyLjM3LjI5LjU5LjIybDIuMzktLjk2Yy41LjM4IDEuMDMuNyAxLjYyLjk0bC4zNiAyLjU4Yy4wNS4yNC4yNC40MS40OC40MWgzLjg0Yy4yNCAwIC40NC0uMTcuNDctLjQxbC4zNi0yLjU4Yy41OS0uMjQgMS4xMy0uNTYgMS42Mi0uOTRsMi4zOS45NmMuMjIuMDguNDcgMC41OS0uMjJsMS45Mi0zLjMyYy4xMi0uMjIuMDctLjQ3LS4xMi0uNjFsLTIuMDEtMS41OHpNMTIgMTUuNmMtMS45OCAwLTMuNi0xLjYyLTMuNi0zLjZzMS42Mi0zLjYgMy42LTMuNiAzLjYgMS42MiAzLjYgMy42LTEuNjIgMy42LTMuNiAzLjZ6Ii8+PC9zdmc+"

$k = 0
$totalRender = $UniqueApps.Count

$HtmlRows = foreach ($App in $UniqueApps) {
    $k++
    $percent = [math]::Round(($k / $totalRender) * 100)
    Write-Progress -Activity "Rendering HTML & Icons" -Status "Processing ($k/$totalRender): $($App.Name)" -PercentComplete $percent

    $Name = $App.Name
    $SafeName = [regex]::Replace($Name, '[^a-zA-Z0-9]', '')
    if (!$SafeName) { $SafeName = [Guid]::NewGuid().ToString() }
    $ImgPath = "$Path\$SafeName.png"
    $ImgSrc = "./AppList/$SafeName.png"
    
    $Success = $false
    if ($App.Icon -and (Test-Path $App.Icon)) {
        try {
            if ($App.Icon -match '\.png$|\.jpg$|\.jpeg$') {
                Copy-Item -Path $App.Icon -Destination $ImgPath -Force -ErrorAction SilentlyContinue
            } else {
                $Bmp = [System.Drawing.Icon]::ExtractAssociatedIcon($App.Icon).ToBitmap()
                $Bmp.Save($ImgPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $Bmp.Dispose()
            }
            if ((Test-Path $ImgPath) -and (Get-Item $ImgPath).Length -gt 0) {
                $Success = $true
            }
        } catch {}
    }
    
    if ($Success) {
        "<tr><td class='icon-cell'><img src=""$ImgSrc"" width=""32"" height=""32"" onerror=""this.onerror=null;this.src='$DefaultSvgBase64';""></td><td><b>$Name</b></td><td>$($App.Publisher)</td><td>$($App.Version)</td><td style='text-align: right;'><b>$($App.DisplaySize)</b></td><td><span class='badge $($App.Type -replace ' ', '')'>$($App.Type)</span></td></tr>"
    } else {
        "<tr><td class='icon-cell'><img src=""$DefaultSvgBase64"" width=""32"" height=""32""></td><td><b>$Name</b></td><td>$($App.Publisher)</td><td>$($App.Version)</td><td style='text-align: right;'><b>$($App.DisplaySize)</b></td><td><span class='badge $($App.Type -replace ' ', '')'>$($App.Type)</span></td></tr>"
    }
}

Write-Progress -Activity "Scan Apps" -Completed

$HtmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>AppList</title>
<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; background: #f4f6f9; color: #333; }
    h2 { color: #2c3e50; margin-bottom: 20px; }
    table { border-collapse: collapse; width: 100%; background: #fff; box-shadow: 0 4px 6px rgba(0,0,0,0.05); border-radius: 8px; overflow: hidden; }
    th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #f1f1f1; }
    th { background-color: #0078d4; color: white; font-weight: 600; text-transform: uppercase; font-size: 13px; letter-spacing: 0.5px; }
    tr:hover { background-color: #f8fbff; }
    
    /* CẤU HÌNH KHUNG VÀ NỀN DÀNH RIÊNG CHO ICON */
    .icon-cell { text-align: center; width: 48px; }
    td img { 
        vertical-align: middle; 
        border-radius: 6px; 
        object-fit: contain;
        background-color: #94a2b0; /* Nền xám trung tính */
        border: 1px solid #dcdfe6;   /* Viền xám nhạt bao quanh */
        padding: 3px;               /* Đệm nhẹ cho icon vừa vặn */
        box-shadow: 0 1px 3px rgba(0,0,0,0.1); /* Đổ bóng nổi khối nhẹ */
    }
    
    .badge { padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: bold; }
    .DesktopApp { background: #e1f5fe; color: #0288d1; }
    .MicrosoftStore { background: #e8f5e9; color: #388e3c; }
</style>
</head>
<body>
<h2>Installed Applications & Disk Usage</h2>
<table>
<tr>
    <th width='5%' style='text-align: center;'>Icon</th>
    <th width='30%'>Application Name</th>
    <th width='25%'>Publisher</th>
    <th width='15%'>Version</th>
    <th width='12%' style='text-align: right;'>Size</th>
    <th width='13%'>Type</th>
</tr>
"@

$HtmlFooter = "</table></body></html>"

$FinalHtml = $HtmlHeader + ($HtmlRows -join "") + $HtmlFooter
[System.IO.File]::WriteAllText("$DesktopPath\AppList.html", $FinalHtml)

Write-Host "Successfully exported files to Desktop:" -ForegroundColor Green
Write-Host "1. HTML: $DesktopPath\AppList.html" -ForegroundColor Cyan
Write-Host "2. CSV:  $DesktopPath\AppList.csv" -ForegroundColor Cyan
