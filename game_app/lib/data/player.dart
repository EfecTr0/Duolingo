import 'dart:convert';
import 'dart:typed_data';
import '../api_service.dart';

// Вспомогательные классы для игр (восстановлены)
class WordAttempt {
  final String english;
  final String correctRussian;
  final String? userAnswer;
  final bool isCorrect;
  WordAttempt({
    required this.english,
    required this.correctRussian,
    this.userAnswer,
    required this.isCorrect,
  });
}

class MatchPair {
  final String english;
  final String russian;
  final bool isCorrect;
  MatchPair({required this.english, required this.russian, required this.isCorrect});
}

class StudiedWord {
  final String english;
  final String russian;
  final String difficulty;
  int timesEncountered;
  int timesCorrect;
  DateTime lastSeen;
  bool isFavorite;

  StudiedWord({
    required this.english,
    required this.russian,
    required this.difficulty,
    this.timesEncountered = 1,
    this.timesCorrect = 0,
    DateTime? lastSeen,
    this.isFavorite = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

  double get successRate => timesEncountered > 0 ? timesCorrect / timesEncountered : 0.0;

  Map<String, dynamic> toJson() => {
        'english': english,
        'russian': russian,
        'difficulty': difficulty,
        'timesEncountered': timesEncountered,
        'timesCorrect': timesCorrect,
        'lastSeen': lastSeen.toIso8601String(),
        'isFavorite': isFavorite,
      };

  factory StudiedWord.fromJson(Map<String, dynamic> json) => StudiedWord(
        english: json['english'],
        russian: json['russian'],
        difficulty: json['difficulty'],
        timesEncountered: json['timesEncountered'],
        timesCorrect: json['timesCorrect'],
        lastSeen: DateTime.parse(json['lastSeen']),
        isFavorite: json['isFavorite'] ?? false,
      );
}


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

  List<StudiedWord> studiedWords = [];

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

    final collection = profile['collection'] ?? [];
    if (collection is List) {
      studiedWords = collection.map((e) => StudiedWord.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      studiedWords = [];
    }
  }

  Future<void> addExperience(int amount) async {
    experience += amount;
    level = 1 + experience ~/ expPerLevel;
    await _syncStats();
  }
  List<StudiedWord> getTopFrequentWords(int count) {
    if (studiedWords.isEmpty) return [];
    final sorted = List<StudiedWord>.from(studiedWords);
    sorted.sort((a, b) => b.timesEncountered.compareTo(a.timesEncountered));
    return sorted.take(count).toList();
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

  // ----- Новые методы для коллекции -----
  void addOrUpdateStudiedWord(String english, String russian, String difficulty, bool wasCorrect) {
    final existingIndex = studiedWords.indexWhere((w) => w.english == english);
    if (existingIndex >= 0) {
      final word = studiedWords[existingIndex];
      word.timesEncountered++;
      if (wasCorrect) word.timesCorrect++;
      word.lastSeen = DateTime.now();
    } else {
      studiedWords.add(StudiedWord(
        english: english,
        russian: russian,
        difficulty: difficulty,
        timesEncountered: 1,
        timesCorrect: wasCorrect ? 1 : 0,
      ));
    }
    _syncCollection();
  }

  void toggleFavorite(String english) {
    final word = studiedWords.firstWhere((w) => w.english == english);
    word.isFavorite = !word.isFavorite;
    _syncCollection();
  }

  Future<void> _syncCollection() async {
    try {
      await ApiService.updateCollection(studiedWords.map((w) => w.toJson()).toList());
    } catch (e) {
      print('Failed to sync collection: $e');
    }
  }
}