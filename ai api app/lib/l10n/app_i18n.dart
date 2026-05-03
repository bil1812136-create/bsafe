enum AppLanguage { zh, en }

class AppI18n {
  AppI18n(this.appLanguage);

  final AppLanguage appLanguage;

  bool get isZh => appLanguage == AppLanguage.zh;

  String pick(String zh, String en) => isZh ? zh : en;

  String get appTitle => pick('AI API 缺陷分類器', 'AI API Defect Classifier');
  String get settings => pick('設定', 'Settings');
  String get language => pick('語言', 'Language');
  String get chinese => '中文';
  String get english => 'English';
  String get report => pick('統計報表', 'Report');

  String get selectImages => pick('選擇 1-100 張圖片', 'Select 1-100 images');
  String get selectFolder => pick('選擇資料夾（桌面）', 'Select folder (desktop)');
  String get startAnalyze => pick('開始分析', 'Start Analysis');
  String get clear => pick('清空', 'Clear');
  String get noDataHint =>
      pick('先選圖片或資料夾，再按開始分析', 'Select images/folder, then start analysis');
  String progressText(int done, int total) =>
      pick('進度: $done / $total', 'Progress: $done / $total');

  String get pending => pick('等待中', 'Pending');
  String get analyzing => pick('分析中...', 'Analyzing...');
  String defectLabel(String label) => pick('缺陷: $label', 'Defect: $label');
  String errorText(String error) => pick('錯誤: $error', 'Error: $error');

  String get max100Hint =>
      pick('最多只會處理前 100 張圖片', 'Only the first 100 images will be processed');
  String get folderEmptyHint => pick(
      '資料夾沒有可用圖片，或你取消了選擇', 'No valid images in folder, or selection canceled');
  String get webNoFolderHint => pick('Web 不支援資料夾模式，請改用多選圖片',
      'Web does not support folder mode, use multi-image select');
  String get folderReadFailHint => pick('無法讀取資料夾內圖片，請改用多選圖片模式',
      'Cannot read images from folder, use multi-image select');

  String get totalRecords => pick('總記錄', 'Total records');
  String unknownRatio(String value) =>
      pick('Unknown 比例: $value%', 'Unknown ratio: $value%');
  String otherRatio(String value) =>
      pick('Other 比例: $value%', 'Other ratio: $value%');
  String get noRecords => pick('目前沒有分析記錄', 'No analysis records yet');
  String resultText(String result) => pick('結果: $result', 'Result: $result');
  String resultErrorText(String result, String error) =>
      pick('結果: $result | 錯誤: $error', 'Result: $result | Error: $error');
  String get deleteRecord => pick('刪除記錄', 'Delete record');
}
