# AI API Classifier

簡單、獨立的 Gemini AI 缺陷分類工具。

## 功能

- 選擇 1-100 張圖片或整個資料夾（桌面版）
- 批次發送到 Gemini API 進行缺陷分類
- 只輸出缺陷類型（不輸出詳細報告）
- 支援的缺陷類型：
  - Concrete Spalling
  - Tile Debonding
  - Water Leakage
  - Unauthorized Building Works
  - Rust / Corrosion
  - Crack
  - Insufficient Evidence
  - No Obvious Defect
  - Other

## 快速開始

```bash
cd "C:\bsafe-1\ai api app"

# 設定 Gemini API Key
$env:GEMINI_API_KEY="YOUR_GEMINI_API_KEY"

# 執行應用程式
flutter run -d R5CR30PFFTN --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY
```

## 功能說明

1. **選擇圖片**：點選「選擇 1-100 張圖片」，可多選圖片
2. **選擇資料夾**（桌面專用）：點選「選擇資料夾」，批量讀取 .jpg/.png/.webp/.bmp 檔案
3. **開始分析**：點選「開始分析」，分批發送到 Gemini 進行分類
4. **檢視結果**：每張圖片顯示對應的缺陷類型或錯誤訊息

## 依賴

- Flutter 3.0+
- http (API 呼叫)
- file_picker (檔案選擇)

## 環境變數

必須設定 `GEMINI_API_KEY` 環境變數，才能正常使用 Gemini API。

## 與 B-SAFE 的關係

此為獨立項目，不依賴原有的 bsafe 專案。可獨立開發和部署。

$env:GEMINI_API_KEY="AIzaSyBegENl97-wl_ql44wwgCk7fQfcEvSCCGQ"

Set-Location "C:\Users\student\Downloads\bsafe\ai api app" ; flutter run -d chrome