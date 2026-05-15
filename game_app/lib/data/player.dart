import 'dart:typed_data';
import 'package:flutter/material.dart';

class WordAttempt {
  final String english;
  final String correctRussian;
  final String? userAnswer; // null, если попытки кончились и показан ответ
  final bool isCorrect;

  WordAttempt({
    required this.english,
    required this.correctRussian,
    this.userAnswer,
    required this.isCorrect,
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
    history.insert(0, result); // новые сверху
  }
}