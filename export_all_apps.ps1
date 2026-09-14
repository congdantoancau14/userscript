$Path = "$env:USERPROFILE\Desktop\DanhSachApp ToanDien"
if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }

Add-Type -AssemblyName System.Drawing
$AppsList = New-Object System.Collections.Generic.List[Object]

# 1. QUÉT REGISTRY (Cả System và User)
$RegistryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$RegApps = Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and $_.ParentKeyName -eq $null }

foreach ($App in $RegApps) {
    $IconPath = ""
    if ($App.DisplayIcon) { $IconPath = $App.DisplayIcon -replace ',.*$', '' -replace '"', '' }
    if (!$IconPath -and $App.InstallLocation) { 
        $ExeFiles = Get-ChildItem -Path $App.InstallLocation -Filter *.exe -Recurse -ErrorAction SilentlyContinue
        if ($ExeFiles) { $IconPath = $ExeFiles[0].FullName }
    }
    
    # Lấy tên Nhà phát hành, nếu trống thì để "Unknown Publisher"
    $Publisher = $App.Publisher
    if (!$Publisher) { $Publisher = "Unknown Publisher" }
    
    $AppsList.Add([PSCustomObject]@{
        Name      = $App.DisplayName
        Publisher = $Publisher
        Version   = $App.DisplayVersion
        Type      = "Desktop App"
        Icon      = $IconPath
    })
}

# 2. QUÉT MICROSOFT STORE APPS (UWP)
$StoreApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { !$_.IsFramework -and $_.NonRemovable -ne $true }
foreach ($App in $StoreApps) {
    $Manifest = Get-AppxPackageManifest $App -ErrorAction SilentlyContinue
    $Name = $Manifest.Package.Properties.DisplayName
    if ($Name -like "ms-resource:*") { $Name = $App.Name }
    if (!$Name) { $Name = $App.Name }
    
    # Lấy tên Nhà phát hành từ ID gói Store
    $Publisher = $App.PublisherId
    if ($Manifest.Package.Properties.PublisherDisplayName) {
        $Publisher = $Manifest.Package.Properties.PublisherDisplayName
    }
    if (!$Publisher) { $Publisher = "Microsoft Corporation" }
    
    $AppFolder = $App.InstallLocation
    $LogoPath = ""
    if ($AppFolder -and (Test-Path $AppFolder)) {
        $LogoFiles = Get-ChildItem -Path $AppFolder -Include *logo*.png, *icon*.png -Recurse -ErrorAction SilentlyContinue
        if ($LogoFiles) { $LogoPath = $LogoFiles[0].FullName }
    }

    $AppsList.Add([PSCustomObject]@{
        Name      = $Name
        Publisher = $Publisher
        Version   = $App.Version
        Type      = "Microsoft Store"
        Icon      = $LogoPath
    })
}

# 3. LỌC TRÙNG VÀ XUẤT RA HTML
$UniqueApps = $AppsList | Group-Object Name | ForEach-Object { $_.Group[0] } | Sort-Object Name

$DefaultIconBase64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABGdBTUEAALGPC/xhBQAAADhJREFUWEft0rENAAAIA0H7b9zBCY6gUpInY6p67gwwgYABAQMCBgQMCBgQMCBgQMCBgQEB8wIe3wEtp9999wAAAABJRU5ErkJggg=="

$HtmlRows = foreach ($App in $UniqueApps) {
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
    
    "<tr><td><img src='$ImgSrc' width='32' height='32' onerror=""this.src='data:image/png;base64,$DefaultIconBase64'""></td><td><b>$Name</b></td><td>$($App.Publisher)</td><td>$($App.Version)</td><td><span class='badge $($App.Type -replace ' ', '')'>$($App.Type)</span></td></tr>"
}

$HtmlHeader = @"
<html>
<head>
<meta charset='UTF-8'>
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
<h2>Danh sách ứng dụng và Nhà phát hành</h2>
<table>
<tr>
    <th width='5%'>Icon</th>
    <th width='35%'>Tên ứng dụng</th>
    <th width='30%'>Nhà phát hành</th>
    <th width='15%'>Phiên bản</th>
    <th width='15%'>Loại</th>
</tr>
"@

$HtmlFooter = "</table></body></html>"

$HtmlHeader + ($HtmlRows -join "") + $HtmlFooter | Out-File "$env:USERPROFILE\Desktop\DanhSachApp_ToanDien.html" -Encoding utf8
Write-Host "Đã xuất danh sách kèm Nhà Phát Hành ra Desktop!" -ForegroundColor Green