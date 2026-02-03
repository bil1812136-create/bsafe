import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:bsafe_app/models/report_model.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'bsafe.db';
  static const int _dbVersion = 1;

  // Singleton pattern
  static final DatabaseService instance = DatabaseService._init();
  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Reports table
    await db.execute('''
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        risk_level TEXT DEFAULT 'low',
        risk_score INTEGER DEFAULT 0,
        is_urgent INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        image_path TEXT,
        image_base64 TEXT,
        location TEXT,
        latitude REAL,
        longitude REAL,
        ai_analysis TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Pending sync queue table
    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (report_id) REFERENCES reports (id)
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_reports_status ON reports(status)');
    await db.execute('CREATE INDEX idx_reports_risk_level ON reports(risk_level)');
    await db.execute('CREATE INDEX idx_reports_created_at ON reports(created_at)');
    await db.execute('CREATE INDEX idx_reports_synced ON reports(synced)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
  }

  // ==================== Report Operations ====================

  // Insert a new report
  Future<int> insertReport(ReportModel report) async {
    final db = await database;
    final id = await db.insert('reports', report.toMap());
    
    // Add to sync queue if not synced
    if (!report.synced) {
      await _addToSyncQueue(id, 'create');
    }
    
    return id;
  }

  // Get all reports
  Future<List<ReportModel>> getAllReports() async {
    final db = await database;
    final maps = await db.query(
      'reports',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ReportModel.fromMap(map)).toList();
  }

  // Get report by ID
  Future<ReportModel?> getReportById(int id) async {
    final db = await database;
    final maps = await db.query(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ReportModel.fromMap(maps.first);
    }
    return null;
  }

  // Get reports by status
  Future<List<ReportModel>> getReportsByStatus(String status) async {
    final db = await database;
    final maps = await db.query(
      'reports',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ReportModel.fromMap(map)).toList();
  }

  // Get reports by risk level
  Future<List<ReportModel>> getReportsByRiskLevel(String riskLevel) async {
    final db = await database;
    final maps = await db.query(
      'reports',
      where: 'risk_level = ?',
      whereArgs: [riskLevel],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ReportModel.fromMap(map)).toList();
  }

  // Get unsynced reports
  Future<List<ReportModel>> getUnsyncedReports() async {
    final db = await database;
    final maps = await db.query(
      'reports',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => ReportModel.fromMap(map)).toList();
  }

  // Update report
  Future<int> updateReport(ReportModel report) async {
    final db = await database;
    final result = await db.update(
      'reports',
      report.toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
    
    // Add to sync queue
    if (report.id != null) {
      await _addToSyncQueue(report.id!, 'update');
    }
    
    return result;
  }

  // Mark report as synced
  Future<void> markReportAsSynced(int id) async {
    final db = await database;
    await db.update(
      'reports',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete report
  Future<int> deleteReport(int id) async {
    final db = await database;
    await _addToSyncQueue(id, 'delete');
    return await db.delete(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Sync Queue Operations ====================

  Future<void> _addToSyncQueue(int reportId, String action) async {
    final db = await database;
    await db.insert('pending_sync', {
      'report_id': reportId,
      'action': action,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    final db = await database;
    return await db.query(
      'pending_sync',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('pending_sync');
  }

  Future<void> removeSyncQueueItem(int id) async {
    final db = await database;
    await db.delete(
      'pending_sync',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Statistics ====================

  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reports'),
    ) ?? 0;
    
    final highRisk = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM reports WHERE risk_level = 'high'"),
    ) ?? 0;
    
    final mediumRisk = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM reports WHERE risk_level = 'medium'"),
    ) ?? 0;
    
    final lowRisk = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM reports WHERE risk_level = 'low'"),
    ) ?? 0;
    
    final urgent = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reports WHERE is_urgent = 1'),
    ) ?? 0;
    
    final pending = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM reports WHERE status = 'pending'"),
    ) ?? 0;
    
    final resolved = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM reports WHERE status = 'resolved'"),
    ) ?? 0;

    return {
      'total': total,
      'highRisk': highRisk,
      'mediumRisk': mediumRisk,
      'lowRisk': lowRisk,
      'urgent': urgent,
      'pending': pending,
      'resolved': resolved,
    };
  }

  // Get trend data for last 7 days
  Future<List<Map<String, dynamic>>> getTrendData() async {
    final db = await database;
    final List<Map<String, dynamic>> trendData = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      
      final total = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM reports WHERE created_at LIKE '$dateStr%'",
        ),
      ) ?? 0;
      
      final high = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM reports WHERE created_at LIKE '$dateStr%' AND risk_level = 'high'",
        ),
      ) ?? 0;
      
      final medium = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM reports WHERE created_at LIKE '$dateStr%' AND risk_level = 'medium'",
        ),
      ) ?? 0;
      
      final low = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM reports WHERE created_at LIKE '$dateStr%' AND risk_level = 'low'",
        ),
      ) ?? 0;
      
      trendData.add({
        'date': '${date.month}/${date.day}',
        'total': total,
        'high': high,
        'medium': medium,
        'low': low,
      });
    }
    
    return trendData;
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
