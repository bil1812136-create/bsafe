import 'package:flutter/foundation.dart';

enum AppLanguage { zh, en }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.en;

  AppLanguage get language => _language;
  bool get isEnglish => _language == AppLanguage.en;

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }

  String t(String key) {
    return _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    'settings': 'Settings',
    'language': 'Language',
    'chinese': 'Chinese',
    'english': 'English',
    'online': 'Online',
    'offline': 'Offline',
    'switched_online': 'Switched to online mode',
    'switched_offline': 'Switched to offline mode',
    'manual_offline_hint': 'Manual offline mode - tap top-right icon to switch',
    'offline_sync_hint':
        'Offline mode - data will sync when connection resumes',
    'nav_home': 'Home',
    'nav_report': 'Report',
    'nav_history': 'History',
    'nav_analysis': 'Analysis',
    'nav_followup': 'Follow-up',
    'nav_location': 'Location',
    'monitor_title': 'Building Safety Monitoring',
    'monitor_count_prefix': 'Monitoring',
    'monitor_count_suffix': 'issue reports',
    'pending_sync_suffix': 'pending sync',
    'risk_overview': 'Risk Overview',
    'high_risk': 'High Risk',
    'medium_risk': 'Medium Risk',
    'low_risk': 'Low Risk',
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
    'quick_report': 'Quick Report',
    // Report Screen
    'take_photo': 'Take Photo',
    'take_photo_desc': 'Open Camera',
    'gallery': 'Gallery',
    'select_photo_desc': 'Select Photo',
    'take_building_photo': 'Take Photo of Building Damage',
    'ai_analyze_category_severity':
        'AI will automatically analyze issue category and severity',
    'ai_analyzing': '🤖 AI is analyzing environment...',
    'identify_safety_risks': 'Smart identification of safety risks',
    'upload_photo': 'Please upload a photo first',
    'wait_ai_analysis': 'Please wait for AI analysis to complete',
    'no_defect_detected':
        'Current result: "No obvious defects detected / insufficient evidence", not recommended to submit',
    'ai_complete': '✨ AI analysis complete!',
    'ai_defect_found': '✅ AI analysis complete (problem detected)',
    'ai_no_defect': 'ℹ️ AI analysis complete (no obvious defects)',
    'ai_invalid_result': 'AI did not return valid result, please retry',
    'ai_analysis_failed': 'AI analysis failed: ',
    'submit_success':
        '✅ Report submitted successfully! Redirecting to history...',
    'submit_failed': 'Submit failed: ',
    'building_safety_issue': 'Building Safety Issue',
    'ai_auto_detect': 'AI Auto Detection',
    'positioning': 'Positioning (UWB)',
    'ai_no_obvious_defect': 'Insufficient image evidence / No defects detected',
    'ai_building_damage': 'Building Damage',
    'ai_auto_detect_building_damage':
        'AI automatically detected building damage',
    // History Screen
    'history': 'History',
    'sync_to_cloud': 'Sync to Cloud',
    'synced_success': 'Synced',
    'synced_count': 'reports to cloud',
    'all_updated': 'All reports are up to date',
    'search_report': 'Search reports...',
    'all': 'All',
    'filter_conditions': 'Filter Conditions',
    'status': 'Status',
    'confirm': 'Confirm',
    'no_matching_report': 'No matching reports',
    'no_report_yet': 'No reports yet',
    // Analysis Screen
    'risk_distribution': '📊 Risk Distribution',
    'trend_7days': '📈 7-Day Trend',
    'processing_status': '📋 Processing Status',
    'summary_stats': '📊 Summary Statistics',
    'high_abbr': 'H',
    'medium_abbr': 'M',
    'low_abbr': 'L',
    'empty_data': 'No data yet',
    // Location Screen
    'positioning_map': 'Positioning Map',
    'data_details': 'Data Details',
    'device_settings': 'Device Settings',
    'error_occurred': 'Error occurred',
    'dismiss': 'Dismiss',
  };
}
