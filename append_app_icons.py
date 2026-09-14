from bs4 import BeautifulSoup
from google_play_scraper import app as play_app
import time

# 1. Đọc file HTML gốc của bạn (thay tên file tương ứng)
input_file = "apps_20260527232642_1.html"
output_file = "apps_with_icons.html"

with open(input_file, "r", encoding="utf-8") as f:
    soup = BeautifulSoup(f.read(), "html.parser")

# Tìm tất cả các khối ứng dụng
app_items = soup.find_all("div", class_="app-item")

print(f"Đang xử lý {len(app_items)} ứng dụng...")

for index, item in enumerate(app_items):
    package_div = item.find("div", class_="package-name")
    if package_div:
        package_name = package_div.text.strip()
        
        try:
            # 2. Lấy thông tin từ Google Play Store bằng package name
            # Thêm timeout hoặc delay nhỏ để tránh bị Google chặn (Rate limit)
            time.sleep(0.5) 
            result = play_app(package_name, lang='vi', country='vn')
            icon_url = result.get('icon')
            
            if icon_url:
                # 3. Bổ sung thẻ img chứa icon vào trước app-name
                name_div = item.find("div", class_="app-name")
                if name_div:
                    # Tạo thẻ img mới
                    icon_tag = soup.new_tag("img", src=icon_url)
                    icon_tag['style'] = "width: 48px; height: 48px; display: block; margin: 0 auto 8px auto; border-radius: 10px;"
                    name_div.insert_before(icon_tag)
                    print(f"[{index+1}] Đã thêm icon cho: {package_name}")
                    
        except Exception as e:
            # Nếu ứng dụng không có trên Play Store (app nội địa, app tự phát triển, hoặc bị gỡ)
            print(f"[{index+1}] Không tìm thấy trên Play Store: {package_name}")
            
            # Thêm một icon mặc định nếu không tìm thấy
            name_div = item.find("div", class_="app-name")
            if name_div:
                icon_tag = soup.new_tag("img", src="https://cdn-icons-png.flaticon.com/512/564/564419.png")
                icon_tag['style'] = "width: 48px; height: 48px; display: block; margin: 0 auto 8px auto; opacity: 0.5;"
                name_div.insert_before(icon_tag)

# Sau khi chạy xong, lưu lại thành file mới
with open(output_file, "w", encoding="utf-8") as f:
    f.write(str(soup))

print("Hoàn thành! File mới đã được lưu thành:", output_file)