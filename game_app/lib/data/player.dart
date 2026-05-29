import 'dart:convert';
import 'dart:typed_data';
import '../api_service.dart';

class PlayerData {
  static final PlayerData _instance = PlayerData._internal();
  factory PlayerData() => _instance;
  PlayerData._internal();

  int level = 1;
  int experience = 0;
  static const int expPerLevel = 100;

  String nickname = 'player';
  Uint8List? avatarBytes;
  String? avatarBase64;

  List<int> friends = [];
  List<int> achievements = [];
  int consecutiveCardPerfect = 0;

  int get experienceForNextLevel => level * expPerLevel;
  int get experienceInCurrentLevel => experience % expPerLevel;
  double get progress => (experienceInCurrentLevel) / expPerLevel;

  void initFromProfile(Map<String, dynamic> profile) {
    nickname = profile['nickname'] ?? 'player';
    experience = profile['experience'] ?? 0;
    level = 1 + experience ~/ expPerLevel;

    final avatarStr = profile['avatar'];
    if (avatarStr != null && avatarStr.toString().isNotEmpty) {
      avatarBase64 = avatarStr;
      try {
        avatarBytes = base64Decode(avatarStr);
      } catch (_) {
        avatarBytes = null;
        avatarBase64 = null;
      }
    } else {
      avatarBytes = null;
      avatarBase64 = null;
    }

    final friendsList = profile['friends'] ?? [];
    if (friendsList is List) {
      friends = friendsList.map((f) => (f as Map<String, dynamic>)['id'] as int).toList();
    } else {
      friends = [];
    }

    achievements = List<int>.from(profile['achievements'] ?? []);
  }

  Future<void> addExperience(int amount) async {
    experience += amount;
    level = 1 + experience ~/ expPerLevel;
    await _syncStats();
  }

  void unlockAchievement(int id) {
    if (!achievements.contains(id)) {
      achievements.add(id);
      _syncStats();
    }
  }

  Future<void> _syncStats() async {
    try {
      await ApiService.updateStats(experience, achievements);
    } catch (e) {
      print('Failed to sync stats: $e');
    }
  }

  void onGameCompleted(String mode, String difficulty, int correct, int total) {
    bool perfect = (total > 0 && correct == total);
    if (perfect && difficulty == 'носитель') {
      unlockAchievement(3);
    }
    if (mode == 'cards' && perfect) {
      consecutiveCardPerfect++;
      if (consecutiveCardPerfect >= 3) {
        unlockAchievement(1);
      }
    } else {
      consecutiveCardPerfect = 0;
    }
  }
}