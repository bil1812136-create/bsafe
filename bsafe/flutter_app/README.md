# B-SAFE Flutter App

智慧城市建築安全應用 — 手機 App + 公司 Web 後台

> **最後更新：2026-03-10**
> **Git Branch：`billy-version1`**
> **最新 Tag：`Billy-Version1` (commit `7ad8af5`)**

---

## 環境資訊（重要）

| 項目 | 值 |
|------|-----|
| Flutter 版本 | 3.38.8 stable |
| 手機裝置 | Samsung SM-A5260 |
| 手機 Device ID | `R5CR30PFFTN` |
| Git Repo 根目錄 | `C:\Users\student\Downloads\bsafe` |
| Flutter Project 路徑 | `C:\Users\student\Downloads\bsafe\bsafe\flutter_app` |
| Supabase URL | `https://adtahhkhyuyqipkulwwp.supabase.co` |
| Supabase Anon Key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkdGFoaGtoeXV5cWlwa3Vsd3dwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2OTE0MTAsImV4cCI6MjA4ODI2NzQxMH0.HpCdD2BRnhnuNdqavWfJAaePHfYLFEt0nRafmEF2Ido` |
| Supabase Storage Buckets | `floor-plans` (Public), `report-images` (Public) |

---

## 快速啟動指令

```bash
# 切換到 Flutter project
cd "C:\Users\student\Downloads\bsafe\bsafe\flutter_app"

# 手機 App
flutter run -d R5CR30PFFTN

# Web 管理後台（Chrome）
flutter run -d chrome --target lib/main_web.dart

# 安裝依賴
flutter pub get
```

---

## 架構概覽

### 雙 Entry Point 設計
- `lib/main.dart` → **手機 App**（Android）
- `lib/main_web.dart` → **Web 管理後台**（公司用）

### 資料儲存架構
> **報告資料只存在 Supabase，不使用本地 SQLite**
> （`database_service.dart` 仍存在但已不被 `ReportProvider` 使用）

```
手機 App ──→ Supabase (reports table) ←── Web 後台
```

### Supabase `reports` 表欄位

| 欄位 | 類型 | 說明 |
|------|------|------|
| `id` | BIGSERIAL (PK) | 自增主鍵 |
| `local_id` | INTEGER UNIQUE | 舊版本地 ID（向後兼容） |
| `title` | TEXT | 標題 |
| `description` | TEXT | 描述 |
| `category` | TEXT | 類別 |
| `severity` | TEXT | 嚴重程度 |
| `risk_level` | TEXT | low / medium / high |
| `risk_score` | INTEGER | 0–100 |
| `is_urgent` | BOOLEAN | 是否緊急 |
| `status` | TEXT | pending / in_progress / resolved |
| `image_url` | TEXT | Supabase Storage 圖片 URL |
| `location` | TEXT | 位置描述 |
| `latitude` | FLOAT | 緯度 |
| `longitude` | FLOAT | 經度 |
| `ai_analysis` | TEXT | AI 分析結果 |
| `company_notes` | TEXT | **公司回饋/跟進任務**（需 ALTER TABLE） |
| `created_at` | TIMESTAMPTZ | 建立時間 |
| `updated_at` | TIMESTAMPTZ | 更新時間 |

> ⚠️ **Supabase SQL 需執行（如未執行）：**
> ```sql
> ALTER TABLE reports ADD COLUMN IF NOT EXISTS company_notes TEXT;
> ```

---

## 功能清單

### 手機 App 功能
- 拍照上傳問題報告（相機 / 相簿）
- AI 圖像識別自動評估損壞程度（Poe API SSE 解析）
- 問題類別：結構性 / 外牆 / 公共區域 / 電氣 / 水管 / 其他
- 嚴重程度：輕微 / 中度 / 嚴重
- 風險評分 0–100，自動判斷是否緊急
- GPS 定位記錄
- 查看歷史報告（從 Supabase 讀取）
- **更新報告狀態：只可設為「待處理」或「處理中」**（已解決由 Web 後台設定）
- 顯示公司回饋（`company_notes`）藍色區塊
- 圖片顯示三層 fallback：本地檔案 → Supabase URL → base64

### Web 管理後台功能
- 查看所有報告列表（DataTable）
- 報告詳情頁面
- **更新狀態：可設為「待處理」/ 「處理中」/ 「已解決」**（三個選項）
- 填寫公司回饋（`company_notes`），儲存至 Supabase
- 圖片顯示（URL 優先，base64 fallback）
- 數據統計 Dashboard

### AI / 分析功能
- Poe API 整合（SSE streaming 解析）
- YOLO 物件偵測（TFLite，`yolo11n.tflite`）
- 離線時使用本地規則評估
- 損壞趨勢分析圖表

### 建築巡檢功能（InspectionScreen）
- UWB 室內定位整合
- 平面圖標注（多樓層）
- 缺陷記錄（Defect model，含 AI 分析 + 聊天記錄）
- Word 報告匯出
- 專案管理（Project model）

---

## 狀態權限設計

| 狀態 | 手機 App | Web 後台 |
|------|----------|----------|
| 待處理 (pending) | ✅ 可設定 | ✅ 可設定 |
| 處理中 (in_progress) | ✅ 可設定 | ✅ 可設定 |
| 已解決 (resolved) | ❌ 不可設定 | ✅ 可設定 |

---

## 項目結構

```
flutter_app/
├── lib/
│   ├── main.dart                      # 手機 App 入口
│   ├── main_web.dart                  # Web 後台入口
│   ├── theme/
│   │   └── app_theme.dart             # 主題配置
│   ├── models/
│   │   ├── report_model.dart          # 報告數據模型（含 imageUrl, companyNotes）
│   │   ├── inspection_model.dart      # 巡檢模型（InspectionSession, InspectionPin, Defect）
│   │   ├── project_model.dart         # 專案模型
│   │   └── uwb_model.dart             # UWB 配置模型
│   ├── providers/
│   │   ├── report_provider.dart       # 報告狀態管理（Supabase-only，無 SQLite）
│   │   ├── inspection_provider.dart   # 巡檢狀態管理
│   │   ├── connectivity_provider.dart # 網絡狀態管理
│   │   └── navigation_provider.dart   # 導航狀態管理
│   ├── services/
│   │   ├── supabase_service.dart      # Supabase 雲端服務（主要資料來源）
│   │   ├── api_service.dart           # Poe AI API 服務（SSE）
│   │   ├── database_service.dart      # 本地 SQLite（已不被 ReportProvider 使用）
│   │   ├── uwb_service.dart           # UWB 藍牙服務
│   │   ├── yolo_service.dart          # YOLO TFLite 物件偵測
│   │   ├── word_export_service.dart   # Word 報告匯出
│   │   └── mobile_serial_service.dart # 手機串口服務
│   ├── screens/
│   │   ├── home_screen.dart           # 首頁
│   │   ├── report_screen.dart         # 上報頁面
│   │   ├── history_screen.dart        # 歷史記錄（含雲端同步按鈕）
│   │   ├── analysis_screen.dart       # 數據分析圖表
│   │   ├── report_detail_screen.dart  # 報告詳情（手機，StatefulWidget）
│   │   ├── location_screen.dart       # 位置選擇
│   │   ├── inspection_screen.dart     # 建築巡檢（UWB + 平面圖）
│   │   ├── calibration_screen.dart    # UWB 校正
│   │   └── web/
│   │       ├── web_dashboard_screen.dart      # Web 後台首頁
│   │       └── web_report_detail_screen.dart  # Web 報告詳情（含公司回饋編輯）
│   └── widgets/
│       ├── stat_card.dart             # 統計卡片
│       ├── recent_report_card.dart    # 最近報告卡片
│       ├── report_detail_card.dart    # 報告詳情卡片
│       ├── category_selector.dart     # 類別選擇器
│       ├── severity_selector.dart     # 嚴重程度選擇器
│       ├── ai_analysis_result.dart    # AI 分析結果組件
│       ├── animated_counter.dart      # 數字動畫
│       ├── shimmer_loading.dart       # 載入動畫
│       └── severity_selector.dart     # 嚴重程度選擇器
├── android/
│   └── app/src/main/assets/
│       └── yolo11n.tflite             # YOLO 模型
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
└── pubspec.yaml
```

---

## 主要修改歷史（開發日誌）

### v1.0 — Billy Version (tag: `Billy-Version`)
- 基礎 Flutter App 架構
- Poe AI SSE 解析修復（image URL, setState dispose）

### v2.0 — Billy Version1 (tag: `Billy-Version1`, commit `7ad8af5`)
- Supabase 雲端同步整合
- Web Dashboard（`main_web.dart`）
- YOLO TFLite 整合
- 多樓層建築巡檢
- Word 報告匯出
- UWB 校正改進

### v2.1 — (commit `dbf70f5`)
- **ReportModel** 新增 `imageUrl`、`companyNotes` 欄位
- **ReportProvider** 完全重寫為 Supabase-only（移除所有 SQLite 依賴）
- **手機報告詳情**：
  - StatelessWidget → StatefulWidget
  - 圖片三層 fallback（本地 → URL → base64）
  - 狀態更新對話框（只有「待處理」/「處理中」，移除「已解決」）
  - 顯示公司回饋藍色區塊（`_CompanyFeedbackSection`）
- **Web 報告詳情**：
  - 新增「公司回饋/跟進任務」可編輯區塊
  - `_save()` 包含 `company_notes` 儲存至 Supabase
  - 圖片支援 base64 fallback
- **SupabaseService** 新增 `createReport()`、`mapToReportModel()` 方法
- **HistoryScreen** 新增雲端同步按鈕（含 badge 顯示未同步數量）
- 修復 `main.dart` 無用 import

---

## 技術棧

| 技術 | 用途 |
|------|------|
| Flutter 3.38.8 | 跨平台 UI 框架 |
| Provider | 狀態管理 |
| Supabase Flutter | 雲端資料庫 + Storage |
| sqflite | 本地 SQLite（備用，目前未使用） |
| connectivity_plus | 網絡狀態檢測 |
| image_picker | 圖片選取 |
| fl_chart | 圖表可視化 |
| http | HTTP 請求 |
| tflite_flutter | YOLO 物件偵測 |
| flutter_blue_plus | UWB 藍牙通訊 |
| docx | Word 匯出 |

---

## Git 操作

```bash
# 切換到 repo 根目錄（.git 在這裡）
cd "C:\Users\student\Downloads\bsafe"

# 查看提交歷史
git log --oneline

# 推送到遠端
git push origin billy-version1

# 查看所有 branch
git branch -a
```

### Git 歷史
```
dbf70f5  Supabase-only reports, mobile status restriction, image/feedback fixes
7ad8af5  Billy Version1 - Supabase cloud sync, web dashboard, YOLO, multi-floor, word export  ← tag: Billy-Version1
e3a8048  Billy Version - fix Poe AI analysis (SSE parsing, image URL, setState dispose)       ← tag: Billy-Version
550d55c  mix 2 version
```

---

## 待辦事項

- [ ] Supabase SQL Editor 執行：`ALTER TABLE reports ADD COLUMN IF NOT EXISTS company_notes TEXT;`
- [ ] 確認 `report-images` Storage bucket 已建立且為 Public
- [ ] 測試完整流程：手機上報 → Web 看到 → Web 填寫回饋 → 手機同步顯示回饋 → 手機更新狀態為處理中 → Web 設定已解決


-----
電腦:
cd "C:\Users\student\Downloads\bsafe\bsafe\flutter_app"
flutter run -d chrome --target lib/main_web.dart

手機:
cd "C:\Users\student\Downloads\bsafe\bsafe\flutter_app"
flutter run -d android

flutter run -d R5CR30PFFTN

