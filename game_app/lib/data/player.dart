import 'dart:typed_data';

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

class RoundDetail {
  final String type; // 'cards' или 'matching'
  final bool success;
  final List<WordAttempt> cardAttempts;
  final List<MatchPair> matchPairs;
  RoundDetail({
    required this.type,
    required this.success,
    this.cardAttempts = const [],
    this.matchPairs = const [],
  });
}

class GameResult {
  final String difficulty;
  final DateTime dateTime;
  final int timeSpentSeconds;
  final int correct;
  final int total;
  final bool bonusAvailable;
  final bool bonusSolved;
  final int experienceEarned;
  final List<WordAttempt> attempts;

  final String? mode; // 'cards', 'matching', 'mixed'
  final List<MatchPair>? matchPairs;
  final List<RoundDetail>? roundDetails;
  final int? cardRoundsSuccess;
  final int? cardRoundsFailed;
  final int? matchRoundsSuccess;
  final int? matchRoundsFailed;

  GameResult({
    required this.difficulty,
    required this.dateTime,
    required this.timeSpentSeconds,
    required this.correct,
    required this.total,
    required this.bonusAvailable,
    required this.bonusSolved,
    required this.experienceEarned,
    required this.attempts,
    this.mode,
    this.matchPairs,
    this.roundDetails,
    this.cardRoundsSuccess,
    this.cardRoundsFailed,
    this.matchRoundsSuccess,
    this.matchRoundsFailed,
  });
}

class PlayerData {
  static final PlayerData _instance = PlayerData._internal();
  factory PlayerData() => _instance;
  PlayerData._internal();

  int level = 1;
  int experience = 0;
  static const int expPerLevel = 100;

  String nickname = 'Игрок';
  Uint8List? avatarBytes;

  int subscriptions = 0;
  int subscribers = 0;
  List<String> friends = List.generate(5, (i) => 'друн');

  final List<GameResult> history = [];

  int get experienceForNextLevel => level * expPerLevel;
  int get experienceInCurrentLevel => experience % expPerLevel;
  double get progress => (experienceInCurrentLevel) / expPerLevel;

  void addExperience(int amount) {
    experience += amount;
    level = 1 + (experience ~/ expPerLevel);
  }

  void addGameResult(GameResult result) {
    history.insert(0, result);
  }
}