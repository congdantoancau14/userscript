function cleanAllDuplicates() {
  // Thay 'ID_THU_MUC_CUA_BAN' bằng ID thư mục gốc bạn muốn quét
  var rootFolderId = 'ID_THU_MUC_CUA_BAN'; 
  var rootFolder = DriveApp.getFolderById(rootFolderId);
  
  var fileMap = {};
  
  // Hàm phụ để quét đệ quy qua tất cả thư mục con
  function scanFolder(folder) {
    Logger.log('Đang quét thư mục: ' + folder.getName());
    
    // 1. Quét tất cả các file trong thư mục hiện tại
    var files = folder.getFiles();
    while (files.hasNext()) {
      var file = files.next();
      var name = file.getName();
      var size = file.getSize();
      // Gom nhóm theo Tên + Dung lượng để tránh xóa nhầm các file trùng tên nhưng khác nội dung
      var key = name + "_" + size; 
      
      if (fileMap.hasOwnProperty(key)) {
        fileMap[key].push(file);
      } else {
        fileMap[key] = [file];
      }
    }
    
    // 2. Tìm các thư mục con và tiếp tục quét sâu vào trong
    var subFolders = folder.getFolders();
    while (subFolders.hasNext()) {
      scanFolder(subFolders.next());
    }
  }
  
  // Bắt đầu kích hoạt quét từ thư mục gốc
  scanFolder(rootFolder);
  
  // Tiến hành xử lý và xóa các file trùng lặp sau khi đã gom hết dữ liệu
  var duplicateCount = 0;
  for (var key in fileMap) {
    if (fileMap[key].length > 1) {
      // Giữ lại file đầu tiên, đưa các file trùng lặp còn lại vào Thùng rác
      for (var i = 1; i < fileMap[key].length; i++) {
        var fileToTrash = fileMap[key][i];
        Logger.log('-> Đã chuyển vào Thùng rác: ' + fileToTrash.getName());
        fileToTrash.setTrashed(true); 
        duplicateCount++;
      }
    }
  }
  Logger.log('Hoàn thành! Tổng số file trùng lặp đã xóa: ' + duplicateCount);
}