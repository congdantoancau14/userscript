import os
import re
from urllib.parse import urlparse
from bs4 import BeautifulSoup
import requests

# Danh sách các định dạng ebook phổ biến để kiểm tra
EBOOK_EXTENSIONS = ('.pdf', '.epub', '.mobi', '.azw3', '.prc')

def process_and_clean_urls(urls):
    """Xử lý thêm 'download' vào URL nếu chưa có và xóa trùng lặp."""
    cleaned_urls = set()

    for url in urls:
        url = url.strip()
        if not url or url.startswith("#"):
            continue
            
        url_clean = url.split("#")[0].strip()
        if not url_clean:
            continue

        parsed_url = urlparse(url_clean)

        if "/download/" not in parsed_url.path:
            new_path = "/download" + parsed_url.path
            url_clean = f"{parsed_url.scheme}://{parsed_url.netloc}{new_path}"

        cleaned_urls.add(url_clean)

    return list(cleaned_urls)


def log_error_report(url, reason, report_filename="error_report.txt"):
    """Ghi nhận các link bị lỗi hoặc 404 vào file report."""
    with open(report_filename, "a", encoding="utf-8") as f:
        f.write(f"URL: {url} | Lý do: {reason}\n")


def download_pdf_from_page(url, output_folder="downloads"):
    """Đọc nguồn trang, tìm link tải và tải file về."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    try:
        print(f"\n[+] Đang xử lý trang: {url}")
        response = requests.get(url, headers=headers, timeout=15)
        
        # YÊU CẦU 3: Kiểm tra nếu lỗi 404 hoặc lỗi HTTP khác thì lưu vào report
        if response.status_code != 200:
            reason = f"Lỗi HTTP {response.status_code}"
            print(f"[-] Không thể truy cập trang. {reason}")
            log_error_report(url, reason)
            return

        soup = BeautifulSoup(response.text, "html.parser")
        download_links = soup.select(".entry-content table td a")

        if not download_links:
            reason = "Không tìm thấy selector link download (.entry-content table td a)"
            print(f"[-] {reason}")
            log_error_report(url, reason)
            return

        # Lấy phần tử cuối cùng trong mảng
        chosen_link = download_links[-1]
        download_url = chosen_link.get("href")
        print(f"[->] Tìm thấy link tải trực tiếp: {download_url}")

        # Xử lý lấy tên file từ cột td kế bên
        td_elements = chosen_link.find_parent("tr").find_all("td")
        if td_elements:
            raw_file_name = td_elements[0].text.strip()
            # Xóa các ký tự không hợp lệ khi đặt tên file
            file_name = re.sub(r'[\\/*?:"<>|]', "", raw_file_name)
            
            # YÊU CẦU 1: Check đuôi file ebook phổ biến để không tự ý thêm đuôi bừa bãi
            if not file_name.lower().endswith(EBOOK_EXTENSIONS):
                file_name += ".pdf"
        else:
            file_name = url.split("/")[-1] + ".pdf"

        # Tạo thư mục lưu trữ nếu chưa có
        if not os.path.exists(output_folder):
            os.makedirs(output_folder)

        file_path = os.path.join(output_folder, file_name)

        # YÊU CẦU 2: Kiểm tra nếu file đã tồn tại thì skip (bỏ qua) không tải lại
        if os.path.exists(file_path):
            print(f"[!] File đã tồn tại trên máy: {file_name} -> BỎ QUA (SKIP).")
            return

        # Tiến hành tải file nếu chưa có sẵn
        print(f"[...] Đang tải file: {file_name}")
        file_response = requests.get(download_url, headers=headers, stream=True)

        if file_response.status_code == 200:
            with open(file_path, "wb") as f:
                for chunk in file_response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            print(f"[✓] Tải thành công! File lưu tại: {file_path}")
        else:
            reason = f"Link tải trực tiếp trả về mã lỗi {file_response.status_code}"
            print(f"[-] Không thể tải file. {reason}")
            log_error_report(url, reason)

    except Exception as e:
        print(f"[-] Có lỗi xảy ra hệ thống: {e}")
        log_error_report(url, f"Ngoại lệ (Exception): {e}")


if __name__ == "__main__":
    input_filename = "urls.txt"
    
    # Kiểm tra xem file input đã tồn tại chưa
    if not os.path.exists(input_filename):
        print(f"[-] Không tìm thấy file '{input_filename}'. Đang tạo file mẫu...")
        sample_urls = [
            "https://sachmoi.net/cac-cuoc-thuong-luong-le-duc-tho-kissinger-tai-paris#gsc.tab=0\n",
            "https://sachmoi.net/download/cac-cuoc-thuong-luong-le-duc-tho-kissinger-tai-paris#gsc.tab=0\n"
        ]
        with open(input_filename, "w", encoding="utf-8") as f:
            f.writelines(sample_urls)
        print(f"[✓] Đã tạo xong file '{input_filename}'. Hãy thêm link vào file này rồi chạy lại tool.")
    else:
        with open(input_filename, "r", encoding="utf-8") as f:
            raw_urls = f.readlines()
            
        print("--- BẮT ĐẦU QUÁ TRÌNH XỬ LÝ URL ---")
        final_urls = process_and_clean_urls(raw_urls)
        print(f"Danh sách URL sau khi lọc trùng và chuẩn hóa ({len(final_urls)} link):")
        for u in final_urls:
            print(f" - {u}")

        print("\n--- BẮT ĐẦU TRUY CẬP VÀ TẢI SÁCH ---")
        for url in final_urls:
            download_pdf_from_page(url)
            
        print("\n--- HOÀN THÀNH QUÁ TRÌNH ---")
        if os.path.exists("error_report.txt"):
            print("[!] Phát hiện có lỗi trong quá trình tải. Vui lòng kiểm tra file 'error_report.txt' để xem chi tiết.")
        else:
            print("[✓] Không có lỗi nào xảy ra.")