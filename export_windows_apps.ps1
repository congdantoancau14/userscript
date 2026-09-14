$DesktopPath = "$env:USERPROFILE\Desktop"
$Path = "$DesktopPath\DanhSachApp ToanDien"
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
        # Cắt bỏ tham số ,0 hoặc ," ở cuối đường dẫn icon
        $CleanIcon = $App.DisplayIcon -replace '",.*$', '' -replace ',.*$', '' -replace '"', ''
        if (Test-Path $CleanIcon) { $IconPath = $CleanIcon }
    }
    
    # Fallback 1: Quét file .exe trong InstallLocation
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
        # Fallback nâng cao cho UWP App: Quét kỹ các tên Asset phổ biến
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
$CsvPath = "$DesktopPath\DanhSachApp_ToanDien.csv"
$UniqueApps | Select-Object @{N='Application Name';E={$_.Name}}, 
                            @{N='Publisher';E={$_.Publisher}}, 
                            @{N='Version';E={$_.Version}}, 
                            @{N='Size';E={$_.DisplaySize}}, 
                            @{N='Type';E={$_.Type}}, 
                            @{N='Icon Path';E={$_.Icon}} | 
    Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

# 5. GENERATE HTML (VỚI DEFAULT SVG ICON)
# Icon SVG bánh răng mặc định cực nét dạng Data URI
$DefaultSvgIcon = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%230078d4'><path d='M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z'/></svg>"

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
    $ImgSrc = "./DanhSachApp ToanDien/$SafeName.png"
    
    $Success = $false
    if ($App.Icon -and (Test-Path $App.Icon)) {
        try {
            if ($App.Icon -match '\.png$|\.jpg$|\.jpeg$') {
                Copy-Item -Path $App.Icon -Destination $ImgPath -Force -ErrorAction SilentlyContinue
                $Success = $true
            } else {
                $Bmp = [System.Drawing.Icon]::ExtractAssociatedIcon($App.Icon).ToBitmap()
                $Bmp.Save($ImgPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $Bmp.Dispose()
                $Success = $true
            }
        } catch {}
    }
    
    # Render ra HTML: Dùng đường dẫn icon trích xuất, nếu load lỗi (onerror) sẽ tự đổi sang SVG Mặc định
    if ($Success) {
        "<tr><td><img src='$ImgSrc' width='32' height='32' onerror=""this.src='$DefaultSvgIcon'""></td><td><b>$Name</b></td><td>$($App.Publisher)</td><td>$($App.Version)</td><td style='text-align: right;'><b>$($App.DisplaySize)</b></td><td><span class='badge $($App.Type -replace ' ', '')'>$($App.Type)</span></td></tr>"
    } else {
        "<tr><td><img src='$DefaultSvgIcon' width='32' height='32'></td><td><b>$Name</b></td><td>$($App.Publisher)</td><td>$($App.Version)</td><td style='text-align: right;'><b>$($App.DisplaySize)</b></td><td><span class='badge $($App.Type -replace ' ', '')'>$($App.Type)</span></td></tr>"
    }
}

Write-Progress -Activity "Scan Apps" -Completed

$HtmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>Installed Applications</title>
<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; background: #f4f6f9; color: #333; }
    h2 { color: #2c3e50; margin-bottom: 20px; }
    table { border-collapse: collapse; width: 100%; background: #fff; box-shadow: 0 4px 6px rgba(0,0,0,0.05); border-radius: 8px; overflow: hidden; }
    th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #f1f1f1; }
    th { background-color: #0078d4; color: white; font-weight: 600; text-transform: uppercase; font-size: 13px; letter-spacing: 0.5px; }
    tr:hover { background-color: #f8fbff; }
    td img { vertical-align: middle; border-radius: 4px; }
    .badge { padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: bold; }
    .DesktopApp { background: #e1f5fe; color: #0288d1; }
    .MicrosoftStore { background: #e8f5e9; color: #388e3c; }
</style>
</head>
<body>
<h2>Installed Applications & Disk Usage</h2>
<table>
<tr>
    <th width='5%'>Icon</th>
    <th width='30%'>Application Name</th>
    <th width='25%'>Publisher</th>
    <th width='15%'>Version</th>
    <th width='12%' style='text-align: right;'>Size</th>
    <th width='13%'>Type</th>
</tr>
"@

$HtmlFooter = "</table></body></html>"

$FinalHtml = $HtmlHeader + ($HtmlRows -join "") + $HtmlFooter
[System.IO.File]::WriteAllText("$DesktopPath\DanhSachApp_ToanDien.html", $FinalHtml)

Write-Host "Successfully exported 2 files to Desktop:" -ForegroundColor Green
Write-Host "1. HTML: $DesktopPath\DanhSachApp_ToanDien.html" -ForegroundColor Cyan
Write-Host "2. CSV:  $DesktopPath\DanhSachApp_ToanDien.csv" -ForegroundColor Cyan
