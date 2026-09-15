import os
import json
import re
import csv
from pathlib import Path

def get_chrome_extension_path():
    local_appdata = os.environ.get('LOCALAPPDATA')
    if not local_appdata:
        print("Không tìm thấy đường dẫn AppData.")
        return None
    return Path(local_appdata) / "Google" / "Chrome" / "User Data"

def get_extension_size(extension_path):
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(extension_path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            if not os.path.islink(fp):
                try:
                    total_size += os.path.getsize(fp)
                except OSError:
                    pass
    return total_size

def clean_json_comments(json_str):
    # Xóa comment // và /* */ mà không làm hỏng chuỗi https://
    pattern = r'("(\\.|[^\\"])*")|//.*|/\*[\s\S]*?\*/'
    def replace(match):
        if match.group(1):
            return match.group(1)
        return ""
    cleaned = re.sub(pattern, replace, json_str)
    cleaned = re.sub(r',\s*([}\]])', r'\1', cleaned)
    return cleaned

def get_extension_name(version_path):
    manifest_path = version_path / "manifest.json"
    if not manifest_path.exists():
        return "Unknown Extension"
    
    try:
        with open(manifest_path, 'r', encoding='utf-8-sig', errors='ignore') as f:
            content = clean_json_comments(f.read())
            data = json.loads(content)
            name = data.get("name", "Unknown")
            
            if name.startswith("__MSG_") and name.endswith("__"):
                key = name.replace("__MSG_", "").replace("__", "")
                locale_dir = version_path / "_locales"
                if locale_dir.exists():
                    for lang in ['en', 'en_US', 'vi']:
                        msg_path = locale_dir / lang / "messages.json"
                        if msg_path.exists():
                            with open(msg_path, 'r', encoding='utf-8-sig', errors='ignore') as mf:
                                m_data = json.loads(clean_json_comments(mf.read()))
                                if key in m_data and "message" in m_data[key]:
                                    return m_data[key]["message"]
                                elif key.lower() in m_data and "message" in m_data[key.lower()]:
                                    return m_data[key.lower()]["message"]
                    
                    for first_lang in locale_dir.iterdir():
                        if first_lang.is_dir():
                            msg_path = first_lang / "messages.json"
                            if msg_path.exists():
                                with open(msg_path, 'r', encoding='utf-8-sig', errors='ignore') as mf:
                                    m_data = json.loads(clean_json_comments(mf.read()))
                                    if key in m_data and "message" in m_data[key]:
                                        return m_data[key]["message"]
            return name
    except Exception:
        return "Error reading manifest"

def export_to_csv(results, output_path="chrome_extensions.csv"):
    with open(output_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(["Profile", "Extension Name", "Extension ID", "Size Bytes", "Size MB", "Path"])
        for res in results:
            writer.writerow([res['profile'], res['name'], res['id'], res['size_bytes'], round(res['size_mb'], 2), res['path']])
    print(f"[+] Đã xuất file CSV: {output_path}")

def export_to_html(results, output_path="chrome_extensions.html"):
    rows_html = ""
    for res in results:
        # Tạo URL dạng file:///C:/Users/... để Chrome mở trực tiếp thư mục
        file_url = Path(res['path']).as_uri()
        
        rows_html += f"""
        <tr>
            <td>{res['profile']}</td>
            <td>{res['name']}</td>
            <td><code>{res['id']}</code></td>
            <td class="num" data-value="{res['size_bytes']}">{res['size_bytes']:,}</td>
            <td class="num" data-value="{res['size_mb']:.2f}">{res['size_mb']:.2f} MB</td>
            <td><a href="{file_url}" target="_blank" title="{res['path']}">Open Folder</a></td>
        </tr>"""

    html_content = f"""<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>Chrome Extensions Size Report</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 30px; background-color: #f8f9fa; color: #202124; }}
        h2 {{ color: #1a73e8; }}
        table {{ border-collapse: collapse; width: 100%; background: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.12); }}
        th, td {{ padding: 12px 16px; text-align: left; border-bottom: 1px solid #e0e0e0; }}
        th {{ background-color: #1a73e8; color: white; cursor: pointer; user-select: none; }}
        th:hover {{ background-color: #1557b0; }}
        tr:hover {{ background-color: #f1f3f4; }}
        .num {{ text-align: right; font-family: monospace; font-size: 14px; }}
        code {{ font-family: monospace; background: #f1f3f4; padding: 2px 6px; border-radius: 4px; }}
        a {{ color: #1a73e8; text-decoration: none; font-weight: 500; }}
        a:hover {{ text-decoration: underline; }}
    </style>
</head>
<body>
    <h2>Báo cáo dung lượng Chrome Extensions</h2>
    <p>Click vào tiêu đề cột để sắp xếp (tăng/giảm dần). Click <b>Open Folder</b> để mở thư mục trên Chrome.</p>
    <table id="extTable">
        <thead>
            <tr>
                <th onclick="sortTable(0, 'string')">Profile ⇳</th>
                <th onclick="sortTable(1, 'string')">Extension Name ⇳</th>
                <th onclick="sortTable(2, 'string')">Extension ID ⇳</th>
                <th onclick="sortTable(3, 'number')" style="text-align: right;">Size (Bytes) ⇳</th>
                <th onclick="sortTable(4, 'number')" style="text-align: right;">Size (MB) ⇳</th>
                <th onclick="sortTable(5, 'string')">Location ⇳</th>
            </tr>
        </thead>
        <tbody>{rows_html}
        </tbody>
    </table>

    <script>
        const sortDirections = {{}};
        function sortTable(colIndex, type) {{
            const table = document.getElementById("extTable");
            const tbody = table.querySelector("tbody");
            const rows = Array.from(tbody.querySelectorAll("tr"));
            
            const currentDir = sortDirections[colIndex] || 'desc';
            const nextDir = currentDir === 'asc' ? 'desc' : 'asc';
            sortDirections[colIndex] = nextDir;
            
            rows.sort((a, b) => {{
                const cellA = a.children[colIndex];
                const cellB = b.children[colIndex];
                
                let valA = cellA.getAttribute("data-value") !== null ? cellA.getAttribute("data-value") : cellA.innerText.trim();
                let valB = cellB.getAttribute("data-value") !== null ? cellB.getAttribute("data-value") : cellB.innerText.trim();
                
                if (type === 'number') {{
                    valA = parseFloat(valA) || 0;
                    valB = parseFloat(valB) || 0;
                    return nextDir === 'asc' ? valA - valB : valB - valA;
                }} else {{
                    return nextDir === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
                }}
            }});
            
            rows.forEach(row => tbody.appendChild(row));
        }}
    </script>
</body>
</html>"""

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"[+] Đã xuất file HTML: {output_path}")

def analyze_extensions():
    chrome_path = get_chrome_extension_path()
    if not chrome_path or not chrome_path.exists():
        print("Không tìm thấy thư mục cài đặt của Google Chrome.")
        return

    print(f"--- Đang quét thư mục: {chrome_path} ---\n")
    results = []

    for profile_dir in chrome_path.iterdir():
        if profile_dir.is_dir() and (profile_dir.name == "Default" or profile_dir.name.startswith("Profile ")):
            ext_dir = profile_dir / "Extensions"
            if ext_dir.exists():
                for ext_id_dir in ext_dir.iterdir():
                    if ext_id_dir.is_dir() and len(ext_id_dir.name) == 32:
                        size_bytes = get_extension_size(ext_id_dir)
                        size_mb = size_bytes / (1024 * 1024)
                        
                        ext_name = "Unknown"
                        versions = [d for d in ext_id_dir.iterdir() if d.is_dir()]
                        if versions:
                            ext_name = get_extension_name(versions[0])
                        
                        results.append({
                            "profile": profile_dir.name,
                            "id": ext_id_dir.name,
                            "name": ext_name,
                            "size_bytes": size_bytes,
                            "size_mb": size_mb,
                            "path": str(ext_id_dir.resolve())
                        })

    results.sort(key=lambda x: x['size_mb'], reverse=True)

    print(f"{'PROFILE':<12} | {'dung lượng (MB)':<15} | {'EXTENSION NAME':<35} | {'EXTENSION ID'}")
    print("-" * 100)
    for res in results:
        display_name = res['name'][:32] + '...' if len(res['name']) > 32 else res['name']
        print(f"{res['profile']:<12} | {res['size_mb']:<13.2f} MB | {display_name:<35} | {res['id']}")

    print("\n" + "=" * 50)
    export_to_csv(results)
    export_to_html(results)

if __name__ == "__main__":
    analyze_extensions()
    input("\nNhấn Enter để thoát...")
