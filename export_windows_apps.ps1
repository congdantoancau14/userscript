# 0. ÉP MÃ HOÁ UTF-8 CHO CHÍNH CONSOLE WINDOWS (Code Page 65001)
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$null = chcp 65001

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

# 1. QUÉT REGISTRY (Desktop Apps)
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
    Write-Progress -Activity "Đang quét ứng dụng Desktop" -Status "Đang xử lý ($i/$totalReg): $($App.DisplayName)" -PercentComplete $percent

    $IconPath = ""
    if ($App.DisplayIcon) { $IconPath = $App.DisplayIcon -replace ',.*$', '' -replace '"', '' }
    if (!$IconPath -and $App.InstallLocation) { 
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

# 2. QUÉT MICROSOFT STORE APPS (UWP)
$StoreApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { !$_.IsFramework -and $_.NonRemovable -ne $true }
$j = 0
$totalStore = $StoreApps.Count

foreach ($App in $StoreApps) {
    $j++
    $percent = [math]::Round(($j / $totalStore) * 100)
    Write-Progress -Activity "Đang quét Microsoft Store Apps" -Status "Đang xử lý ($j/$totalStore): $($App.Name)" -PercentComplete $percent

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
        $LogoFiles = Get-ChildItem -Path $AppFolder -Include *logo*.png, *icon*.png -Recurse -ErrorAction SilentlyContinue
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

# 3. LỌC TRÙNG & SẮP XẾP
$UniqueApps = $AppsList | Group-Object Name | ForEach-Object { $_.Group[0] } | Sort-Object Name

# 4. XUẤT FILE CSV (Mở bằng Excel hiển thị tiếng Việt chuẩn)
$CsvPath = "$DesktopPath\DanhSachApp_ToanDien.csv"
$UniqueApps | Select-Object @{N='Tên ứng dụng';E={$_.Name}}, 
                            @{N='Nhà phát hành';E={$_.Publisher}}, 
                            @{N='Phiên bản';E={$_.Version}}, 
                            @{N='Dung lượng';E={$_.DisplaySize}}, 
                            @{N='Loại';E={$_.Type}}, 
                            @{N='Đường dẫn Icon';E={$_.Icon}} | 
    Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

# 5. TẠO VÀ XUẤT FILE HTML
$DefaultIconBase64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABGdBTUEAALGPC/xhBQAAADhJREFUWEft0rENAAAIA0H7b9zBCY6gUpInY6p67gwwgYABAQMCBgQMCBgQMCBgQMCBgQEB8wIe3wEtp9999wAAAABJRU5ErkJggg=="

$k = 0
$totalRender = $UniqueApps.Count

$HtmlRows = foreach ($App in $UniqueApps) {
    $k++
    $percent = [math]::Round(($k / $totalRender) * 100)
    Write-Progress -Activity "Đang trích xuất Icon và tạo HTML" -Status "Đang render ($k/$totalRender): $($App.Name)" -PercentComplete $percent

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
    
    if (!$Success) {
        [System.IO.File]::WriteAllBytes($ImgPath, [System.Convert]::FromBase64String($DefaultIconBase64))
    }
    
    "<tr><td><img src='$ImgSrc' width='32' height='32' onerror=""this.src='data:image/png;base64,$DefaultIconBase64'""></td><td><b>$Name</b></td><td>$($App.Publisher)</td><td>$($App.Version)</td><td style='text-align: right;'><b>$($App.DisplaySize)</b></td><td><span class='badge $($App.Type -replace ' ', '')'>$($App.Type)</span></td></tr>"
}

Write-Progress -Activity "Đang quét ứng dụng" -Completed

$HtmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>Danh sách ứng dụng</title>
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
<h2>Danh sách ứng dụng và Dung lượng</h2>
<table>
<tr>
    <th width='5%'>Icon</th>
    <th width='30%'>Tên ứng dụng</th>
    <th width='25%'>Nhà phát hành</th>
    <th width='15%'>Phiên bản</th>
    <th width='12%' style='text-align: right;'>Dung lượng</th>
    <th width='13%'>Loại</th>
</tr>
"@

$HtmlFooter = "</table></body></html>"

# Xuất HTML bằng UTF8 có BOM để trình duyệt tự mở đúng UTF-8
$FinalHtml = $HtmlHeader + ($HtmlRows -join "") + $HtmlFooter
$Utf8WithBom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$DesktopPath\DanhSachApp_ToanDien.html", $FinalHtml, $Utf8WithBom)

Write-Host "Đã xuất thành công 2 file ra Desktop:" -ForegroundColor Green
Write-Host "1. HTML: $DesktopPath\DanhSachApp_ToanDien.html" -ForegroundColor Cyan
Write-Host "2. CSV:  $DesktopPath\DanhSachApp_ToanDien.csv" -ForegroundColor Cyan