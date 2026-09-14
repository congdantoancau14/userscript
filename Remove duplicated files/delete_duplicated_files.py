import os

# 1. Thư mục Local cần dọn dẹp
LOCAL_FOLDER = r"E:\Sach"
DRIVE_LIST_PATH = r"drive_sachlatbua_books_files.txt"

# 2. Đọc danh sách và chỉ lọc lấy TÊN FILE, bỏ phần đường dẫn Drive đi
drive_file_names = set()

with open(DRIVE_LIST_PATH, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line:
            # os.path.basename lấy phần cuối cùng (tên file)
            # Ví dụ: "I:\My Drive\Lap trinh\python.pdf" -> "python.pdf"
            file_name = os.path.basename(line) 
            
            # Nếu bạn muốn lấy phần thư mục: dir_name = os.path.dirname(line)
            
            drive_file_names.add(file_name)

print(f"Đã tải {len(drive_file_names)} tên file từ danh sách Drive.")
print("Bắt đầu quét thư mục Local để xóa file trùng...")

# 3. Quét thư mục Local
for root, dirs, files in os.walk(LOCAL_FOLDER):
    for file_name in files:
        # Nếu tên file ở local nằm trong danh sách tên file trên Drive
        if file_name in drive_file_names:
            full_local_path = os.path.join(root, file_name)
            try:
                # Tiến hành xóa
                os.remove(full_local_path)
                print(f" Đã xóa file trùng: {full_local_path}")
                
                # --- ĐOẠN DRY RUN BẮT ĐẦU ---
                # Thay vì chạy os.remove(), ta chỉ in thông báo ra màn hình
                # print(f"[DRY RUN] Phát hiện trùng - SẼ XÓA: {full_local_path}")
                
                # os.remove(full_local_path) # Đã khóa lệnh xóa thật bằng dấu #
                # --- ĐOẠN DRY RUN KẾT THÚC ---
                # Thay vì in ra màn hình, ghi thẳng vào file log
                # with open("ket_qua_dry_run.txt", "a", encoding="utf-8") as log_file:
                    # log_file.write(f"Sẽ xóa: {full_local_path}\n")
            except Exception as e:
                print(f"❌ Lỗi không thể xóa {full_local_path}: {e}")

print("Hoàn thành dọn dẹp!")