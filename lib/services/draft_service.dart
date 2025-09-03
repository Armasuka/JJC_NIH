import 'package:hive/hive.dart';
import '../utils/logger.dart';

class DraftService {
  static const String _boxName = 'drafts';
  
  static Box get _box => Hive.box(_boxName);
  
  // Save draft with timestamp
  static Future<bool> saveDraft({
    required String formType,
    required Map<String, dynamic> data,
  }) async {
    try {
      final draftKey = '${formType.toLowerCase()}_draft';
      final draftData = {
        ...data,
        'formType': formType,
        'timestamp': DateTime.now().toIso8601String(),
        'draftId': draftKey,
      };
      
      Logger.debug('📝 DraftService: Saving draft for $formType with key: $draftKey');
      await _box.put(draftKey, draftData);
      
      // Verify save
      final saved = _box.get(draftKey);
      if (saved != null) {
        Logger.debug('✅ DraftService: Draft saved successfully');
        return true;
      } else {
        Logger.debug('❌ DraftService: Failed to verify saved draft');
        return false;
      }
    } catch (e) {
      Logger.debug('❌ DraftService: Error saving draft: $e');
      return false;
    }
  }
  
  // Get all drafts sorted by timestamp (newest first)
  static List<Map<String, dynamic>> getAllDrafts() {
    try {
      final drafts = <Map<String, dynamic>>[];
      for (var key in _box.keys) {
        final draft = _box.get(key);
        if (draft != null && draft is Map) {
          drafts.add({
            'key': key,
            'data': Map<String, dynamic>.from(draft),
          });
        }
      }
      
      // Sort drafts by timestamp (newest first)
      drafts.sort((a, b) {
        final aTimestamp = a['data']['timestamp'] as String? ?? '';
        final bTimestamp = b['data']['timestamp'] as String? ?? '';
        
        if (aTimestamp.isEmpty && bTimestamp.isEmpty) return 0;
        if (aTimestamp.isEmpty) return 1;
        if (bTimestamp.isEmpty) return -1;
        
        try {
          final aDate = DateTime.parse(aTimestamp);
          final bDate = DateTime.parse(bTimestamp);
          return bDate.compareTo(aDate); // Descending order (newest first)
        } catch (e) {
          Logger.debug('❌ DraftService: Error parsing timestamp: $e');
          return 0;
        }
      });
      
      print('📋 DraftService: Found ${drafts.length} drafts (sorted by newest first)');
      return drafts;
    } catch (e) {
      Logger.debug('❌ DraftService: Error getting drafts: $e');
      return [];
    }
  }
  
  // Check if any drafts exist
  static bool hasDrafts() {
    try {
      final count = _box.keys.length;
      Logger.debug('🔍 DraftService: Draft count: $count');
      return count > 0;
    } catch (e) {
      Logger.debug('❌ DraftService: Error checking drafts: $e');
      return false;
    }
  }
  
  // Get draft count
  static int getDraftCount() {
    try {
      return _box.keys.length;
    } catch (e) {
      Logger.debug('❌ DraftService: Error getting draft count: $e');
      return 0;
    }
  }
  
  // Load specific draft
  static Map<String, dynamic>? loadDraft(String draftKey) {
    try {
      final draft = _box.get(draftKey);
      if (draft != null) {
        Logger.debug('📖 DraftService: Loaded draft $draftKey');
        return Map<String, dynamic>.from(draft);
      }
      return null;
    } catch (e) {
      Logger.debug('❌ DraftService: Error loading draft: $e');
      return null;
    }
  }
  
  // Delete draft
  static Future<bool> deleteDraft(String draftKey) async {
    try {
      await _box.delete(draftKey);
      Logger.debug('🗑️ DraftService: Deleted draft $draftKey');
      return true;
    } catch (e) {
      Logger.debug('❌ DraftService: Error deleting draft: $e');
      return false;
    }
  }
  
  // Clear all drafts
  static Future<bool> clearAllDrafts() async {
    try {
      await _box.clear();
      Logger.debug('🧹 DraftService: Cleared all drafts');
      return true;
    } catch (e) {
      Logger.debug('❌ DraftService: Error clearing drafts: $e');
      return false;
    }
  }
  
  // Debug: Print all drafts (sorted by newest first)
  static void debugPrintAllDrafts() {
    try {
      print('🔍 DraftService: DEBUG - All drafts (sorted by newest first):');
      final drafts = getAllDrafts(); // Use the sorted version
      for (var draft in drafts) {
        final key = draft['key'] as String;
        final draftData = draft['data'] as Map<String, dynamic>;
        final formType = draftData['formType'] ?? 'Unknown';
        final timestamp = draftData['timestamp'] ?? 'Unknown';
        final petugas1 = draftData['petugas1'] ?? 'Unknown';
        Logger.debug('   📄 $key: $formType | $petugas1 | $timestamp');
      }
    } catch (e) {
      Logger.debug('❌ DraftService: Debug error: $e');
    }
  }
}
