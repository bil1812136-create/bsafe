## 📱 实时对话自动更新功能说明

### 🎯 问题
在 webapp 和手机 app 之间发送对话信息时，如果不手动刷新（退出重进），另一方不会看到新消息，这会影响用户体验。

### ✅ 解决方案
实现了基于 **Supabase Realtime** 的自动同步机制，使得当一端发送信息时，另一端会**自动收到并刷新 UI**，无需手动操作。

---

### 🔧 核心实现

#### 1️⃣ **RealtimeService** （新增）
📄 `lib/services/realtime_service.dart`

**功能**：
- 监听 Supabase 中特定报告的数据变化
- 当对话、状态或其他字段更新时，自动触发回调
- 支持多个报告的并发订阅

**关键方法**：
```dart
// 订阅报告的实时更新
void subscribeToReport(int reportId, Function(ReportModel) onUpdate)

// 取消订阅
Future<void> unsubscribeFromReport(int reportId)

// 取消所有订阅
Future<void> unsubscribeAll()
```

#### 2️⃣ **ReportProvider** （增强）
📄 `lib/providers/report_provider.dart`

**新增功能**：
- `_currentReport`：追踪正在查看的报告
- `subscribeToReport()`：启动实时监听
- `unsubscribeFromCurrentReport()`：停止监听
- `updateCurrentReport()`：处理实时更新

**工作流程**：
```
用户进入报告details → subscribeToReport()
           ↓
Realtime 监听 Supabase 中的报告变化
           ↓
有新对话/状态变化 → 触发 onUpdate 回调
           ↓
Provider 通知所有监听器 → UI 自动刷新
           ↓
用户离开details → unsubscribeFromCurrentReport()
```

#### 3️⃣ **ReportDetailScreen** （集成）
📄 `lib/screens/report_detail_screen.dart`

**修改内容**：
- `initState()` 中调用 `subscribeToReport()` 开始监听
- `dispose()` 中调用 `unsubscribeFromCurrentReport()` 停止监听
- `build()` 中使用 `context.watch<ReportProvider>()` 获取最新数据

**核心代码**：
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 🔴 启动实时监听
    context.read<ReportProvider>().subscribeToReport(_report);
  });
}

@override
void dispose() {
  // 🔴 停止监听，释放资源
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<ReportProvider>().unsubscribeFromCurrentReport();
  });
  super.dispose();
}

@override
Widget build(BuildContext context) {
  // 🔴 观察 Provider，获取实时更新数据
  final provider = context.watch<ReportProvider>();
  if (provider.currentReport != null && provider.currentReport!.id == _report.id) {
    _report = provider.currentReport!; // 自动更新到最新数据
  }
  // ... 使用 _report 显示 UI ...
}
```

---

### 🚀 工作流程

#### 场景：工人 app 接收公司 webapp 的新对话

```
┌─────────────────────────────────────────────┐
│  公司 WebApp 发送新对话                      │
│  → supabase_service.addCompanyMessage()  │
│  → 更新 Supabase reports 表               │
└──────────────────┬──────────────────────────┘
                   │ (数据库更新)
┌──────────────────▼──────────────────────────┐
│  Supabase Realtime 检测到变化           │
│  → 推送更新事件给所有监听客户端          │
└──────────────────┬──────────────────────────┘
                   │ (实时推送)
┌──────────────────▼──────────────────────────┐
│  工人手机 App (RealtimeService)          │
│  → 接收 PostgreSQL 变化事件              │
│  → _handleReportUpdate() 处理数据        │
│  → 触发所有注册的回调函数                │
└──────────────────┬──────────────────────────┘
                   │ (回调执行)
┌──────────────────▼──────────────────────────┐
│  ReportProvider 监听器被触发              │
│  → updateCurrentReport() 更新当前报告    │
│  → notifyListeners() 通知 UI 重建        │
└──────────────────┬──────────────────────────┘
                   │ (状态通知)
┌──────────────────▼──────────────────────────┐
│  ReportDetailScreen rebuild                │
│  → build() 获取最新 currentReport          │
│  → mergedConversation 包含新对话          │
│  → 用户看到新消息 ✨                       │
└─────────────────────────────────────────────┘
```

---

### 📋 数据库要求

需要在 Supabase 中执行以下 SQL（已更新注释）：

```sql
-- 启用 Realtime 监听
ALTER TABLE reports REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE reports;

-- 确保 conversation 列存在
ALTER TABLE reports ADD COLUMN conversation JSONB;
ALTER TABLE reports ADD COLUMN has_unread_company BOOLEAN DEFAULT FALSE;
```

> **重要**：`REPLICA IDENTITY FULL` 必须启用，否则 Realtime 无法检测到更新！

---

### 🎨 特性对比

| 功能 | 旧方案（手动刷新） | 新方案（自动更新） |
|------|------------------|------------------|
| **用户体验** | 需要退出重进 | 自动无感刷新 |
| **延迟** | 几秒（手动操作） | <1秒（Realtime推送） |
| **资源占用** | 每次全量刷新 | 仅更新必要数据 |
| **网络请求** | 频繁 HTTP 请求 | WebSocket 长连接 |
| **多设备同步** | ❌ 无法跨设备同步 | ✅ 实时跨设备同步 |

---

### 🔐 性能优化

1. **只在详情页监听**
   - 进入详情页时启动监听，离开时立即停止
   - 避免后台持续消耗资源

2. **条件更新**
   ```dart
   if (provider.currentReport!.id == _report.id) {
     _report = provider.currentReport!; // 仅当 ID 匹配时更新
   }
   ```

3. **WebSocket 并发**
   - 支持同时监听多个报告
   - 内部使用 `Map<int, RealtimeChannel>` 管理频道

---

### 🧪 测试步骤

1. **准备两个设备/浏览器**
   - 设备 A：手机 app（从报告列表进入某报告详情页面）
   - 设备 B：WebApp（后台同一报告，发送新对话）

2. **测试过程**
   - 在设备 B 发送对话信息
   - **不刷新** 设备 A
   - 观察设备 A 的对话区域是否自动显示新消息
   - 预期：约 1-2 秒内自动出现新消息 ✨

3. **验证成功标志**
   - ❌ 不需要手动刷新
   - ✅ 对话自动实时显示
   - ✅ 离开详情页面后停止监听（无资源泄漏）

---

### 🐛 常见问题

**Q: 为什么没有收到实时更新？**
- A: 检查 Supabase 是否启用了 `REPLICA IDENTITY FULL` 和 `ALTER PUBLICATION`

**Q: Realtime 连接断了怎么办？**
- A: 可以在 RealtimeService 中添加自动重连逻辑（当前版本有基本的错误处理）

**Q: 支持离线模式吗？**
- A: 离线时无法接收实时推送，恢复连接后会自动重新订阅

**Q: 能否取消所有订阅？**
- A: 可以，调用 `RealtimeService.instance.unsubscribeAll()`

---

### 📚 相关文件清单

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `realtime_service.dart` | ✨ 新增 | Realtime 监听服务 |
| `report_provider.dart` | 🔄 增强 | 添加订阅/取消订阅逻辑 |
| `report_detail_screen.dart` | 🔧 集成 | 启用实时监听 |
| `supabase_service.dart` | 📝 更新 | SQL 文档(数据库结构) |

---

### 🎓 技术架构总结

```
User Input (webapp/phone)
        ↓
supabase_service.addCompanyMessage()
        ↓
Supabase Database (UPDATE conversation)
        ↓
Supabase Realtime (PostgreSQL LISTEN/NOTIFY)
        ↓
RealtimeService (WebSocket 接收)
        ↓
ReportProvider (notifyListeners)
        ↓
ReportDetailScreen (rebuild with latest data)
        ↓
UI 自动刷新 ✨ (无需手动操作)
```

---

**✅ 现在 webapp 和手机 app 可以完全同步实时对话！** 🎉
