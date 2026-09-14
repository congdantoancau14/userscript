import os
import json
import re
from pathlib import Path

def get_chrome_extension_path():
    # Tự động lấy đường dẫn AppData\Local của User hiện tại
    local_appdata = os.environ.get('LOCALAPPDATA')
    if not local_appdata:
        print("Không tìm thấy đường dẫn AppData.")
        return None
    return Path(local_appdata) / "Google" / "Chrome" / "User Data"

def get_extension_size(extension_path):
    # Tính tổng dung lượng của thư mục Extension (Bytes)
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(extension_path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            # Bỏ qua các file liên kết tượng trưng (symlinks) nếu có
            if not os.path.islink(fp):
                total_size += os.path.getsize(fp)
    return total_size

def get_extension_name(version_path):
    # Thử đọc tên từ manifest.json trước
    manifest_path = version_path / "manifest.json"
    if not manifest_path.exists():
        return "Unknown Extension"
    
    try:
        with open(manifest_path, 'r', encoding='utf-8', errors='ignore') as f:
            # Loại bỏ các comment trong file JSON nếu có (Chrome cho phép điều này)
            content = re.sub(r'//.*', '', f.read())
            data = json.loads(content)
            name = data.get("name", "Unknown")
            
            # Nếu tên dạng biến__MSG_appName__, cần vào thư mục _locales để lấy tên thật
            if name.startswith("__MSG_") and name.endswith("__"):
                key = name.replace("__MSG_", "").replace("__", "")
                
                # Thử tìm ở tiếng Anh (en) trước, nếu không có thì tìm ở ngôn ngữ mặc định khác
                locale_dir = version_path / "_locales"
                if locale_dir.exists():
                    # Thử tìm en, en_US hoặc thư mục đầu tiên xuất hiện
                    for lang in ['en', 'en_US', 'vi']:
                        msg_path = locale_dir / lang / "messages.json"
                        if msg_path.exists():
                            with open(msg_path, 'r', encoding='utf-8', errors='ignore') as mf:
                                m_data = json.loads(mf.read())
                                if key in m_data and "message" in m_data[key]:
                                    return m_data[key]["message"]
                                # Đôi khi key bị đổi thành chữ thường
                                elif key.lower() in m_data and "message" in m_data[key.lower()]:
                                    return m_data[key.lower()]["message"]
                    
                    # Nếu không trúng ngôn ngữ ưu tiên, lấy bừa thư mục locale đầu tiên
                    for first_lang in locale_dir.iterdir():
                        msg_path = first_lang / "messages.json"
                        if msg_path.exists():
                            with open(msg_path, 'r', encoding='utf-8', errors='ignore') as mf:
                                m_data = json.loads(mf.read())
                                if key in m_data and "message" in m_data[key]:
                                    return m_data[key]["message"]
            return name
    except Exception:
        return "Error reading manifest"

def analyze_extensions():
    chrome_path = get_chrome_extension_path()
    if not chrome_path or not chrome_path.exists():
        print("Không tìm thấy thư mục cài đặt của Google Chrome.")
        return

    print(f"--- Đang quét thư mục: {chrome_path} ---\n")
    results = []

    # Duyệt qua các thư mục con trong User Data để tìm các Profile (Default, Profile 1, Profile 2...)
    for profile_dir in chrome_path.iterdir():
        if profile_dir.is_dir() and (profile_dir.name == "Default" or profile_dir.name.startswith("Profile ")):
            ext_dir = profile_dir / "Extensions"
            if ext_dir.exists():
                # Quét từng thư mục mã băm của Extension
                for ext_id_dir in ext_dir.iterdir():
                    if ext_id_dir.is_dir() and len(ext_id_dir.name) == 32: # ID của Extension luôn dài 32 ký tự
                        
                        # Tính dung lượng tổng của Extension ID này
                        size_bytes = get_extension_size(ext_id_dir)
                        size_mb = size_bytes / (1024 * 1024)
                        
                        # Tìm thư mục phiên bản bên trong để đọc Tên (ví dụ: 1.0.0_0)
                        ext_name = "Unknown"
                        versions = [d for d in ext_id_dir.iterdir() if d.is_dir()]
                        if versions:
                            # Lấy phiên bản mới nhất/đầu tiên để đọc tên
                            ext_name = get_extension_name(versions[0])
                        
                        results.append({
                            "profile": profile_dir.name,
                            "id": ext_id_dir.name,
                            "name": ext_name,
                            "size_mb": size_mb
                        })

    # Sắp xếp kết quả theo dung lượng giảm dần
    results.sort(key=lambda x: x['size_mb'], reverse=True)

    # In kết quả ra màn hình dạng bảng trực quan
    print(f"{'PROFILE':<12} | {' dung lượng (MB)':<15} | {'EXTENSION NAME':<35} | {'EXTENSION ID'}")
    print("-" * 100)
    for res in results:
        # Giới hạn độ dài tên để bảng không bị vỡ hàng
        display_name = res['name'][:32] + '...' if len(res['name']) > 32 else res['name']
        print(f"{res['profile']:<12} | {res['size_mb']:<13.2f} MB | {display_name:<35} | {res['id']}")

if __name__ == "__main__":
    analyze_extensions()
    input("\nNhấn Enter để thoát...")