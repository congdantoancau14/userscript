# Temporary Chat

**Exported:** 6/1/2026 0:53:53  
**Link:** [https://gemini.google.com/app/287492cea1ab1b35](https://gemini.google.com/app/287492cea1ab1b35)

## Prompt:
làm sao để xuất danh sách app trên windows?

## Response:
Để xuất danh sách các ứng dụng đã cài đặt trên Windows, cách nhanh chóng và chuyên nghiệp nhất là sử dụng **PowerShell** hoặc **Command Prompt (CMD)**. Dưới đây là các cách thực hiện từ đơn giản đến chi tiết:

Cách 1: Sử dụng PowerShell (Khuyên dùng - Đầy đủ nhất)
------------------------------------------------------

PowerShell có thể quét qua registry để liệt kê chính xác các ứng dụng hệ thống và ứng dụng bên thứ ba.

1.  Nhấn phím `Windows`, gõ **PowerShell**, nhấp chuột phải vào nó và chọn **Run as administrator**.
2.  Copy và paste câu lệnh sau rồi nhấn `Enter`:
    
```
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table -AutoSize > "$env:USERPROFILE\Desktop\DanhSachApp.txt"
```

*   **Kết quả:** Một file tên `DanhSachApp.txt` sẽ xuất hiện ngay ngoài màn hình **Desktop** của bạn.
*   **Thông tin xuất ra gồm:** Tên ứng dụng, phiên bản, nhà phát triển và ngày cài đặt.

> 💡 **Mẹo:** Nếu bạn muốn xuất thành file **Excel (CSV)** để dễ quản lý, hãy đổi đoạn cuối từ `Format-Table...` thành: `... | Export-Csv -Path "$env:USERPROFILE\Desktop\DanhSachApp.csv" -NoTypeInformation -Encoding UTF8`

Cách 2: Sử dụng Command Prompt (CMD) với WMIC
---------------------------------------------

Cách này rất nhanh và file xuất ra có định dạng bảng text rất gọn gàng.

1.  Nhấn phím `Windows`, gõ **CMD**, nhấp chuột phải và chọn **Run as administrator**.
2.  Nhập lệnh sau và nhấn `Enter`:
    
```
wmic product get name,version /format:table > "%USERPROFILE%\Desktop\DanhSachApp_CMD.txt"
```

*   **Kết quả:** File `DanhSachApp_CMD.txt` sẽ được lưu ở **Desktop**.
*   _Lưu ý:_ Lệnh `wmic` đôi khi sẽ mất một vài phút để chạy vì nó cần cấu hình lại các gói MSI trong lúc quét.

Cách 3: Xuất danh sách app từ Windows Settings (Thủ công)
---------------------------------------------------------

Nếu bạn không muốn dùng dòng lệnh và danh sách app không quá dài, bạn có thể copy thủ công từ Settings:

1.  Mở **Settings** (Nhấn `Windows + I`) \> chọn **Apps** \> **Installed apps** (hoặc _Apps & features_ tùy phiên bản Windows).
2.  Dùng chuột bôi đen toàn bộ danh sách ứng dụng hiển thị trên màn hình.
3.  Nhấn `Ctrl + C` để copy, sau đó mở **Notepad** hoặc **Excel** và nhấn `Ctrl + V` để paste lại. Bạn sẽ cần chỉnh sửa một chút vì định dạng copy từ giao diện này thường kèm theo dung lượng và ngày cài đặt nằm rời rạc.

Nếu bạn cần tinh chỉnh câu lệnh để lọc riêng một số app cụ thể, cứ nói cho mình biết nhé!



---
Powered by [Gemini Exporter](https://www.ai-chat-exporter.com)