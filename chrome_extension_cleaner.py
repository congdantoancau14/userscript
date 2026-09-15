import os
import json
import re
import csv
from pathlib import Path

def get_chrome_user_data_path():
    local_appdata = os.environ.get('LOCALAPPDATA')
    if not local_appdata:
        print("Không tìm thấy đường dẫn AppData.")
        return None
    return Path(local_appdata) / "Google" / "Chrome" / "User Data"

def get_profile_names_map(user_data_path):
    local_state_path = user_data_path / "Local State"
    profile_map = {}
    if local_state_path.exists():
        try:
            with open(local_state_path, 'r', encoding='utf-8', errors='ignore') as f:
                data = json.load(f)
                info_cache = data.get("profile", {}).get("info_cache", {})
                for prof_dir, prof_info in info_cache.items():
                    profile_map[prof_dir] = prof_info.get("name", prof_dir)
        except Exception as e:
            print(f"Không thể đọc Local State: {e}")
    return profile_map

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
        writer.writerow([
            "Profile Directory", "Profile Name", "Extension Name", 
            "Extension ID", "Size Bytes", "Size MB", "Path", 
            "Launch Command", "Settings URL", "Webstore URL"
        ])
        for res in results:
            cmd = f'chrome.exe --profile-directory="{res["profile_dir"]}"'
            settings_url = f"chrome://extensions/?id={res['id']}"
            webstore_url = f"https://chromewebstore.google.com/detail/{res['id']}"
            
            writer.writerow([
                res['profile_dir'], 
                res['profile_name'], 
                res['name'], 
                res['id'], 
                res['size_bytes'], 
                round(res['size_mb'], 2), 
                res['path'],
                cmd,
                settings_url,
                webstore_url
            ])
    print(f"[+] Đã xuất file CSV: {output_path}")

def export_to_html(results, output_path="chrome_extensions.html"):
    rows_html = ""
    for res in results:
        file_url = Path(res['path']).as_uri()
        chrome_cmd = f'chrome.exe --profile-directory="{res["profile_dir"]}"'
        settings_url = f"chrome://extensions/?id={res['id']}"
        webstore_url = f"https://chromewebstore.google.com/detail/{res['id']}"
        
        rows_html += f"""
        <tr>
            <td><code>{res['profile_dir']}</code></td>
            <td class="profile-cell" 
                data-cmd='{chrome_cmd}' 
                onclick="copyToClipboard(this)" 
                title="Click to copy command: {chrome_cmd}">
                <b>{res['profile_name']}</b>
                <span class="copy-badge">Copied!</span>
            </td>
            <td><a href="{webstore_url}" target="_blank" title="Go to Chrome Web Store" class="webstore-link">{res['name']}</a></td>
            <td><a href="{settings_url}" target="_blank" title="Open Extension Settings" class="settings-link"><code>{res['id']}</code></a></td>
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
        
        /* Webstore & Settings Links */
        .webstore-link {{ color: #202124; }}
        .webstore-link:hover {{ color: #1a73e8; text-decoration: underline; }}
        .settings-link code {{ color: #1a73e8; }}
        .settings-link:hover code {{ text-decoration: underline; background: #e8f0fe; }}
        
        /* Style cho cột Profile Click-to-Copy */
        .profile-cell {{ cursor: pointer; position: relative; color: #1a73e8; transition: color 0.2s; }}
        .profile-cell:hover {{ color: #1557b0; text-decoration: underline; }}
        .copy-badge {{
            display: none;
            margin-left: 8px;
            padding: 2px 6px;
            font-size: 11px;
            background-color: #34a853;
            color: white;
            border-radius: 4px;
            font-weight: normal;
        }}
    </style>
</head>
<body>
    <h2>Báo cáo dung lượng Chrome Extensions</h2>
    <p>
        • Click <b>Extension Name</b> để tới Chrome Web Store.<br>
        • Click <b>Extension ID</b> để mở trang Cài đặt Extension.<br>
        • Click <b>Profile Name</b> để copy lệnh khởi chạy Profile.
    </p>
    <table id="extTable">
        <thead>
            <tr>
                <th onclick="sortTable(0, 'string')">Profile Dir ⇳</th>
                <th onclick="sortTable(1, 'string')">Profile Name ⇳</th>
                <th onclick="sortTable(2, 'string')">Extension Name ⇳</th>
                <th onclick="sortTable(3, 'string')">Extension ID ⇳</th>
                <th onclick="sortTable(4, 'number')" style="text-align: right;">Size (Bytes) ⇳</th>
                <th onclick="sortTable(5, 'number')" style="text-align: right;">Size (MB) ⇳</th>
                <th onclick="sortTable(6, 'string')">Location ⇳</th>
            </tr>
        </thead>
        <tbody>{rows_html}
        </tbody>
    </table>

    <script>
        function copyToClipboard(element) {{
            const cmd = element.getAttribute("data-cmd");
            if (!cmd) return;
            
            navigator.clipboard.writeText(cmd).then(() => {{
                const badge = element.querySelector(".copy-badge");
                if (badge) {{
                    badge.style.display = "inline";
                    setTimeout(() => {{ badge.style.display = "none"; }}, 1500);
                }}
            }}).catch(err => {{
                console.error("Lỗi copy: ", err);
            }});
        }}

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
    chrome_path = get_chrome_user_data_path()
    if not chrome_path or not chrome_path.exists():
        print("Không tìm thấy thư mục cài đặt của Google Chrome.")
        return

    profile_names_map = get_profile_names_map(chrome_path)

    print(f"--- Đang quét thư mục: {chrome_path} ---\n")
    results = []

    for profile_dir in chrome_path.iterdir():
        if profile_dir.is_dir() and (profile_dir.name == "Default" or profile_dir.name.startswith("Profile ")):
            ext_dir = profile_dir / "Extensions"
            if ext_dir.exists():
                profile_display_name = profile_names_map.get(profile_dir.name, profile_dir.name)
                
                for ext_id_dir in ext_dir.iterdir():
                    if ext_id_dir.is_dir() and len(ext_id_dir.name) == 32:
                        size_bytes = get_extension_size(ext_id_dir)
                        size_mb = size_bytes / (1024 * 1024)
                        
                        ext_name = "Unknown"
                        versions = [d for d in ext_id_dir.iterdir() if d.is_dir()]
                        if versions:
                            ext_name = get_extension_name(versions[0])
                        
                        results.append({
                            "profile_dir": profile_dir.name,
                            "profile_name": profile_display_name,
                            "id": ext_id_dir.name,
                            "name": ext_name,
                            "size_bytes": size_bytes,
                            "size_mb": size_mb,
                            "path": str(ext_id_dir.resolve())
                        })

    results.sort(key=lambda x: x['size_mb'], reverse=True)

    print(f"{'PROFILE DIR':<12} | {'PROFILE NAME':<20} | {'dung lượng (MB)':<15} | {'EXTENSION NAME':<30} | {'EXTENSION ID'}")
    print("-" * 115)
    for res in results:
        display_ext_name = res['name'][:27] + '...' if len(res['name']) > 30 else res['name']
        display_prof_name = res['profile_name'][:18] + '..' if len(res['profile_name']) > 20 else res['profile_name']
        print(f"{res['profile_dir']:<12} | {display_prof_name:<20} | {res['size_mb']:<13.2f} MB | {display_ext_name:<30} | {res['id']}")

    print("\n" + "=" * 50)
    export_to_csv(results)
    export_to_html(results)

if __name__ == "__main__":
    analyze_extensions()
    input("\nNhấn Enter để thoát...")
