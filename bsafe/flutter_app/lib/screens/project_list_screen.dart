import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:bsafe_app/models/project_model.dart';
import 'package:bsafe_app/providers/inspection_provider.dart';
import 'package:bsafe_app/screens/inspection_screen.dart';
import 'package:bsafe_app/theme/app_theme.dart';

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
        _projects =
            list.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Failed to load projects: $e');
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
      debugPrint('Failed to save projects: $e');
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
            Text('New Project'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Building Name',
                hintText: 'E.g.: Commercial Building',
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
                labelText: 'Number of Floors',
                hintText: 'E.g.: 25',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.layers),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              final floors = int.tryParse(floorController.text.trim()) ?? 1;
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a building name')));
                return;
              }
              if (floors < 1) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Number of floors must be at least 1')));
                return;
              }
              Navigator.pop(ctx);
              _createProject(name, floors);
            },
            icon: const Icon(Icons.check),
            label: const Text('Create'),
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
    // Create or find session for this project's current floor
    _ensureSessionForFloor(inspection, project, project.currentFloor);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionScreen(project: project),
      ),
    ).then((_) {
      // Reload projects when returning
      _loadProjects();
    });
  }

  void _ensureSessionForFloor(
      InspectionProvider inspection, Project project, int floor) {
    // Look for existing session for this project+floor
    final existing = inspection.sessions.where(
      (s) => s.projectId == project.id && s.floor == floor,
    );
    if (existing.isNotEmpty) {
      inspection.switchSession(existing.first.id);
    } else {
      // Create a new session for this floor
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
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.buildingName}"?\nAll inspection data for all floors will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final inspection = context.read<InspectionProvider>();
              // Delete all sessions for this project
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 5),
                  Text('B-SAFE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('Projects'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? _buildEmptyState()
              : _buildProjectList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProjectDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Project'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.business_rounded, size: 56, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Projects Yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to create your\nfirst building inspection project',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateProjectDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Project'),
            ),
          ],
        ),
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
    // Count total pins for this project
    final projectSessions =
        inspection.sessions.where((s) => s.projectId == project.id).toList();
    final totalPins =
        projectSessions.fold<int>(0, (sum, s) => sum + s.totalPins);
    final analyzedPins =
        projectSessions.fold<int>(0, (sum, s) => sum + s.analyzedPins);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openProject(project),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.12),
                            AppTheme.primaryLight.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.business_rounded,
                          color: AppTheme.primaryColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(project.buildingName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text(
                            '${project.floorCount} Floors  \u00b7  ${project.createdAt.toString().substring(0, 10)}',
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') _deleteProject(project);
                      },
                      icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textHint),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildStatChip(
                          Icons.layers_rounded, '${project.floorCount} Floors', AppTheme.primaryColor),
                      const SizedBox(width: 16),
                      _buildStatChip(
                          Icons.push_pin_rounded, '$totalPins Points', Colors.orange.shade700),
                      const SizedBox(width: 16),
                      _buildStatChip(
                          Icons.check_circle_outline_rounded, '$analyzedPins Done', AppTheme.riskLow),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
