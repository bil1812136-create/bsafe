# B-SAFE Flutter App

智慧城市建築安全應用 - Flutter 前端

## 功能特點

### ✅ 已實現功能

1. **問題描述和嚴重程度分類**
   - 輕微 / 中度 / 嚴重 三級分類
   - 視覺化選擇器

2. **標籤系統**
   - 結構性問題 🏗️
   - 外牆問題 🧱
   - 公共區域 🚪
   - 電氣問題 ⚡
   - 水管問題 🚰
   - 其他 📋

3. **拍照上傳**
   - 相機拍照
   - 相簿選取
   - 圖片預覽

4. **AI圖像識別自動評估損壞程度**
   - POE API 整合接口（需配置API Key）
   - 離線時使用本地規則評估

5. **生成建築安全風險評分**
   - 0-100 分數評估
   - 圓形進度顯示

6. **自動判斷是否需要緊急處理**
   - 基於嚴重程度和類別自動判斷
   - 緊急標籤顯示

7. **損壞趨勢分析**
   - 近7天趨勢折線圖
   - 風險分佈餅圖
   - 處理狀態柱狀圖

8. **顏色標識風險等級**
   - 🔴 高風險 (紅色)
   - 🟡 中風險 (黃色)
   - 🟢 低風險 (綠色)

9. **在線/離線功能**
   - 自動檢測網絡狀態
   - 離線時數據存儲到本地 SQLite
   - 恢復連線後自動同步

## 項目結構

```
flutter_app/
├── lib/
│   ├── main.dart                 # 應用入口
│   ├── theme/
│   │   └── app_theme.dart        # 主題配置
│   ├── models/
│   │   └── report_model.dart     # 報告數據模型
│   ├── providers/
│   │   ├── report_provider.dart       # 報告狀態管理
│   │   └── connectivity_provider.dart # 網絡狀態管理
│   ├── services/
│   │   ├── database_service.dart # 本地數據庫服務
│   │   └── api_service.dart      # API 服務 (含 POE AI)
│   ├── screens/
│   │   ├── home_screen.dart      # 首頁
│   │   ├── report_screen.dart    # 上報頁面
│   │   ├── history_screen.dart   # 歷史記錄
│   │   ├── analysis_screen.dart  # 數據分析
│   │   └── report_detail_screen.dart # 報告詳情
│   └── widgets/
│       ├── stat_card.dart        # 統計卡片
│       ├── recent_report_card.dart    # 最近報告卡片
│       ├── report_detail_card.dart    # 報告詳情卡片
│       ├── category_selector.dart     # 類別選擇器
│       ├── severity_selector.dart     # 嚴重程度選擇器
│       └── ai_analysis_result.dart    # AI分析結果組件
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
└── pubspec.yaml
```

## 安裝和運行

### 1. 安裝依賴

```bash
cd flutter_app
flutter pub get
```

### 2. 配置 POE API

在 `lib/services/api_service.dart` 中設置你的 POE API Key：

```dart
static const String poeApiKey = 'YOUR_POE_API_KEY';
```

### 3. 運行應用

```bash
# 運行在模擬器
flutter run

# 運行在特定設備
flutter run -d <device_id>

# 構建 APK
flutter build apk

# 構建 iOS
flutter build ios
```

## 技術棧

- **Flutter 3.x** - 跨平台 UI 框架
- **Provider** - 狀態管理
- **sqflite** - 本地 SQLite 數據庫
- **connectivity_plus** - 網絡狀態檢測
- **image_picker** - 圖片選取
- **fl_chart** - 圖表可視化
- **http** - HTTP 請求

## 下一步：後端開發

前端已完成，接下來需要開發：

1. **PHP REST API** - 後端接口
2. **MariaDB 數據庫** - 數據存儲
3. **POE API 整合** - AI 圖像分析

需要我繼續創建後端嗎？

-----

## 開發環境 & 運行指令

```bash
# 進入 flutter 目錄
cd "C:\Users\student\Downloads\bsafe\bsafe\flutter_app"

# 電腦 Web Dashboard
flutter run -d chrome --target lib/main_web.dart

# 手機 (Samsung SM-A5260)
flutter run -d R5CR30PFFTN
# 或
flutter run -d android
```

## Git 資訊

- **Repo 根目錄**: `C:\Users\student\Downloads\bsafe` (`.git` 在這裡)
- **主要 Branch**: `billy-version1`
- **重要 Tags**: `Billy-Version1` @ `7ad8af5`, `Billy-Version` @ `e3a8048`
- **推送指令**: `git push origin billy-version1`

```bash
cd "C:\Users\student\Downloads\bsafe"
git add -A
git commit -m "your message"
git push origin billy-version1
```

## Supabase 設定

- **Project URL**: `https://adtahhkhyuyqipkulwwp.supabase.co`
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkdGFoaGtoeXV5cWlwa3Vsd3dwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2OTE0MTAsImV4cCI6MjA4ODI2NzQxMH0.HpCdD2BRnhnuNdqavWfJAaePHfYLFEt0nRafmEF2Ido`
- **Storage Buckets**: `floor-plans` (Public), `report-images` (Public)
- **reports 表格欄位**: id (BIGSERIAL), local_id, title, description, category, severity, risk_level, risk_score, is_urgent, status, image_url, location, latitude, longitude, ai_analysis, company_notes, created_at, updated_at

> ⚠️ 需在 Supabase SQL Editor 執行：
> `ALTER TABLE reports ADD COLUMN IF NOT EXISTS company_notes TEXT;`

## 架構說明（目前狀態）

| 項目 | 說明 |
|------|------|
| 報告儲存 | **Supabase 雲端唯一**，不用本地 SQLite |
| 手機端 status | 只能設 `待處理` / `處理中` |
| Web 後台 status | 可設所有狀態包括 `已解決` |
| 圖片儲存 | Supabase Storage (`report-images` bucket) |
| 公司回饋 | Web 後台填寫 `company_notes`，手機同步顯示 |

## 已完成功能 (Copilot 開發記錄)

| 版本 | 完成功能 |
|------|----------|
| Billy-Version | Poe AI SSE 修復, 圖片 URL, setState dispose 修復 |
| Billy-Version1 | Supabase 雲同步, Web Dashboard, YOLO, 多樓層, Word 匯出 |
| dbf70f5 | Supabase-only 報告儲存, 圖片顯示修復 (3層 fallback), Web 公司回饋欄, 手機 status 限制, report_provider 完全重寫 |

## 主要檔案索引

| 檔案 | 用途 |
|------|------|
| `lib/main.dart` | 手機 App 入口 |
| `lib/main_web.dart` | Web Dashboard 入口 |
| `lib/models/report_model.dart` | 報告資料模型 (含 imageUrl, companyNotes) |
| `lib/providers/report_provider.dart` | 報告狀態管理 (Supabase-only) |
| `lib/services/supabase_service.dart` | 所有 Supabase 操作 |
| `lib/services/api_service.dart` | Poe AI API |
| `lib/screens/report_detail_screen.dart` | 手機報告詳情 |
| `lib/screens/web/web_dashboard_screen.dart` | Web 主頁 |
| `lib/screens/web/web_report_detail_screen.dart` | Web 報告詳情+編輯 |
| `lib/screens/history_screen.dart` | 歷史記錄列表 |

