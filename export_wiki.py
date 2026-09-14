import os
import time
import requests
from bs4 import BeautifulSoup

# Cấu hình cơ bản
BASE_URL = "https://vi.wikisource.org/wiki/Trang:%C4%90%E1%BA%A1i_Nam_qu%E1%BA%A5c_%C3%A2m_t%E1%BB%B1_v%E1%BB%81_1.pdf/"
OUTPUT_DIR = "dainam_pages"
START_PAGE = 1
END_PAGE = 20

# Tạo thư mục lưu trữ nếu chưa có
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

print("### Bắt đầu cào dữ liệu từ Wikisource... ###")

for page_num in range(START_PAGE, END_PAGE + 1):
    url = f"{BASE_URL}{page_num}"
    print(f"Đang cào trang {page_num}/{END_PAGE}...")
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Wikisource bọc nội dung văn bản đã gõ trong class 'pr-text' hoặc 'text'
            text_container = soup.find(class_="pr-text") or soup.find(class_="text")
            
            if text_container:
                # Lấy text và làm sạch khoảng trắng
                page_text = text_container.get_text()
                
                # Lưu vào file text
                file_path = os.path.join(OUTPUT_DIR, f"trang_{page_num:02d}.txt")
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(page_text.strip())
            else:
                print(f"[-] Cảnh báo: Không tìm thấy thẻ chứa text ở trang {page_num}")
                
        else:
            print(f"[-] Lỗi HTTP {response.status_code} tại trang {page_num}")
            
    except Exception as e:
        print(f"[-] Đã xảy ra lỗi tại trang {page_num}: {e}")
    
    # Delay nhẹ 0.5s để tránh bị chặn IP
    time.sleep(0.5)

print(f"\n### Hoàn thành! Tất cả các trang đã được lưu tại thư mục: {OUTPUT_DIR} ###")