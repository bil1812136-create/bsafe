import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:bsafe_app/features/building_medical_record/data/models/project_model.dart';
import 'package:bsafe_app/features/building_medical_record/presentation/providers/inspection_provider.dart';
import 'package:bsafe_app/features/building_medical_record/presentation/pages/inspection_page.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  List<Project> _projects = [];
  bool _isLoading = true;
  static const String _projectsKey = 'bsafe_projects';
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_projectsKey);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List<dynamic>;
        _projects = list
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('載入專案失敗: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _projectsKey, jsonEncode(_projects.map((p) => p.toJson()).toList()));
    } catch (e) {
      debugPrint('保存專案失敗: $e');
    }
  }

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    final floorController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_business, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('新建專案'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '大廈名稱',
                hintText: '例如：港島商業大廈',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: floorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '樓層數目',
                hintText: '例如：25',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.layers),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              final floors = int.tryParse(floorController.text.trim()) ?? 1;
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('請輸入大廈名稱')));
                return;
              }
              if (floors < 1) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('樓層數目至少為 1')));
                return;
              }
              Navigator.pop(ctx);
              _createProject(name, floors);
            },
            icon: const Icon(Icons.check),
            label: const Text('建立'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _createProject(String name, int floorCount) {
    final project = Project(
      id: _uuid.v4(),
      buildingName: name,
      floorCount: floorCount,
    );
    setState(() {
      _projects.insert(0, project);
    });
    _saveProjects();
    _openProject(project);
  }

  void _openProject(Project project) {
    final inspection = context.read<InspectionProvider>();
    _ensureSessionForFloor(inspection, project, project.currentFloor);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionScreen(project: project),
      ),
    ).then((_) {
      _loadProjects();
    });
  }

  void _ensureSessionForFloor(
      InspectionProvider inspection, Project project, int floor) {
    final existing = inspection.sessions.where(
      (s) => s.projectId == project.id && s.floor == floor,
    );
    if (existing.isNotEmpty) {
      inspection.switchSession(existing.first.id);
    } else {
      inspection.createSession(
        '${project.buildingName} - ${floor}F',
        projectId: project.id,
        floor: floor,
      );
    }
  }

  void _deleteProject(Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除專案'),
        content: Text('確定要刪除「${project.buildingName}」？\n所有樓層的巡檢數據也會被刪除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final inspection = context.read<InspectionProvider>();
              final sessionsToDelete = inspection.sessions
                  .where((s) => s.projectId == project.id)
                  .map((s) => s.id)
                  .toList();
              for (final sid in sessionsToDelete) {
                inspection.deleteSession(sid);
              }
              setState(() {
                _projects.removeWhere((p) => p.id == project.id);
              });
              _saveProjects();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text('B-SAFE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('專案管理',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? _buildEmptyState()
              : _buildProjectList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('新建專案'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '尚無專案',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '按下方「+ 新建專案」開始建立大廈巡檢專案',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateProjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('新建專案'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        return _buildProjectCard(project);
      },
    );
  }

  Widget _buildProjectCard(Project project) {
    final inspection = context.read<InspectionProvider>();
    final projectSessions =
        inspection.sessions.where((s) => s.projectId == project.id).toList();
    final totalPins =
        projectSessions.fold<int>(0, (sum, s) => sum + s.totalPins);
    final analyzedPins =
        projectSessions.fold<int>(0, (sum, s) => sum + s.analyzedPins);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _openProject(project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.business,
                        color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.buildingName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(
                          '${project.floorCount} 層  |  建立於 ${project.createdAt.toString().substring(0, 10)}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') _deleteProject(project);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('刪除', style: TextStyle(color: Colors.red)),
                            ],
                          )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip(
                      Icons.layers, '${project.floorCount} 樓層', Colors.blue),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      Icons.push_pin, '$totalPins 巡檢點', Colors.orange),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      Icons.analytics, '$analyzedPins 已分析', Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
