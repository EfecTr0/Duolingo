class PlayerData {
  static final PlayerData _instance = PlayerData._internal();
  factory PlayerData() => _instance;
  PlayerData._internal();

  int level = 1;
  int experience = 0;          // общий опыт
  static const int expPerLevel = 100;

  int get experienceForNextLevel => level * expPerLevel;
  int get experienceInCurrentLevel => experience % expPerLevel;
  double get progress => (experienceInCurrentLevel) / expPerLevel;

  void addExperience(int amount) {
    experience += amount;
    // пересчёт уровня
    level = 1 + (experience ~/ expPerLevel);
  }
}