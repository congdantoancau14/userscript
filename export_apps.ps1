$Path = "$env:USERPROFILE\Desktop\DanhSachApp"
if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }

Add-Type -AssemblyName System.Drawing
$UninstallKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$Apps = Get-ItemProperty $UninstallKeys | Where-Object { $_.DisplayName -and $_.DisplayIcon }

$HtmlRows = foreach ($App in $Apps) {
    $Name = $App.DisplayName
    $IconPath = $App.DisplayIcon -replace ',.*$', '' -replace '"', ''
    $SafeName = $Name -replace '[^a-zA-Z0-9]', ''
    $ImgPath = "$Path\$SafeName.png"
    
    if (Test-Path $IconPath) {
        try {
            $Bmp = [System.Drawing.Icon]::ExtractAssociatedIcon($IconPath).ToBitmap()
            $Bmp.Save($ImgPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $Bmp.Dispose()
            "<tr><td><img src='./DanhSachApp/$SafeName.png' width='32' height='32'></td><td>$Name</td><td>$($App.DisplayVersion)</td></tr>"
        } catch {
            "<tr><td>❌</td><td>$Name</td><td>$($App.DisplayVersion)</td></tr>"
        }
    } else {
        "<tr><td>❓</td><td>$Name</td><td>$($App.DisplayVersion)</td></tr>"
    }
}

$HtmlHeader = "<html><head><meta charset='UTF-8'><style>body{font-family:sans-serif;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background-color:#f2f2f2;}</style></head><body><h2>Danh sách ứng dụng đã cài đặt</h2><table><tr><th>Icon</th><th>Tên ứng dụng</th><th>Phiên bản</th></tr>"
$HtmlFooter = "</table></body></html>"

$HtmlHeader + ($HtmlRows -join "") + $HtmlFooter | Out-File "$env:USERPROFILE\Desktop\DanhSachApp.html" -Encoding utf8
Write-Host "Xong! Hãy kiểm tra file DanhSachApp.html ngoài Desktop." -ForegroundColor Green