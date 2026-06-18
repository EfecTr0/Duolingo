import 'package:flutter/material.dart';
import '../data/player.dart';
import '../main.dart' show playClickSound, playCorrectSound, playIncorrectSound;

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({Key? key}) : super(key: key);

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String _filterDifficulty = 'все';
  String _sortBy = 'date'; // date, success, favorite
  bool _showOnlyFavorites = false;

  List<StudiedWord> get _filteredWords {
    var words = List<StudiedWord>.from(PlayerData().studiedWords);
    
    if (_showOnlyFavorites) {
      words = words.where((w) => w.isFavorite).toList();
    } else if (_filterDifficulty != 'все') {
      words = words.where((w) => w.difficulty == _filterDifficulty).toList();
    }

    switch (_sortBy) {
      case 'date':
        words.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
        break;
      case 'success':
        words.sort((a, b) => b.successRate.compareTo(a.successRate));
        break;
      case 'favorite':
        words.sort((a, b) => (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0));
        break;
    }
    return words;
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'лёгкий': return Colors.green;
      case 'средний': return Colors.yellow;
      case 'сложный': return Colors.red;
      case 'носитель': return Color(0xFF800000);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _filteredWords;

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Моя коллекция',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Фильтры и сортировка
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('все', '📚'),
                _buildFilterChip('лёгкий', '😊'),
                _buildFilterChip('средний', '😁'),
                _buildFilterChip('сложный', '🤔'),
                _buildFilterChip('носитель', '😈'),
                const SizedBox(width: 8),
                const VerticalDivider(),
                const SizedBox(width: 8),
                _buildSortChip('date', '📅', 'Дата'),
                _buildSortChip('success', '⭐', 'Успех'),
                _buildSortChip('favorite', '❤️', 'Избранное'),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('⭐ Только избранные'),
                  selected: _showOnlyFavorites,
                  onSelected: (val) {
                    playClickSound();
                    setState(() => _showOnlyFavorites = val);
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.amber[100],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          if (words.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Пока нет изученных слов',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Сыграйте в любую игру, чтобы пополнить коллекцию',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9,     // квадратики почти как в истории
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final word = words[index];
                  return _WordCard(word: word, onRefresh: () => setState(() {}));
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String difficulty, String emoji) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji),
            const SizedBox(width: 4),
            Text(difficulty == 'все' ? 'Все' : difficulty),
          ],
        ),
        selected: _filterDifficulty == difficulty,
        onSelected: (val) {
          playClickSound();
          setState(() => _filterDifficulty = difficulty);
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue[100],
      ),
    );
  }

  Widget _buildSortChip(String value, String icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: _sortBy == value,
        onSelected: (val) {
          playClickSound();
          setState(() => _sortBy = value);
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.green[100],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final StudiedWord word;
  final VoidCallback onRefresh;

  const _WordCard({required this.word, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final successPercent = (word.successRate * 100).toInt();
    final color = word.difficulty == 'лёгкий' ? Colors.green
        : word.difficulty == 'средний' ? Colors.yellow
        : word.difficulty == 'сложный' ? Colors.red
        : const Color(0xFF800000);

    return GestureDetector(
      onTap: () {
        playClickSound();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WordDetailScreen(
              word: word,
              onFavoriteToggled: onRefresh,
            ),
          ),
        ).then((_) => onRefresh());
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              word.english,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${word.timesEncountered} раз',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '$successPercent%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: successPercent >= 70 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Экран детального просмотра остаётся без изменений (как раньше)
class WordDetailScreen extends StatefulWidget {
  final StudiedWord word;
  final VoidCallback onFavoriteToggled;
  const WordDetailScreen({Key? key, required this.word, required this.onFavoriteToggled}) : super(key: key);
  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final TextEditingController _answerController = TextEditingController();
  String _feedback = '';
  bool _showAnswer = false;
  int _attemptsLeft = 2;
  bool _isTestMode = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    final userAnswer = _answerController.text.trim().toLowerCase();
    final correct = widget.word.russian.toLowerCase();
    if (userAnswer == correct) {
      playCorrectSound();
      setState(() {
        _feedback = 'Правильно! 🎉';
        _showAnswer = true;
      });
    } else {
      _attemptsLeft--;
      playIncorrectSound();
      if (_attemptsLeft > 0) {
        setState(() => _feedback = 'Неправильно. Осталось попыток: $_attemptsLeft');
      } else {
        setState(() {
          _feedback = 'Правильный ответ: ${widget.word.russian}';
          _showAnswer = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.word.english),
        actions: [
          IconButton(
            icon: Icon(widget.word.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.word.isFavorite ? Colors.red : null),
            onPressed: () {
              playClickSound();
              PlayerData().toggleFavorite(widget.word.english);
              widget.onFavoriteToggled();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.school),
            onPressed: () {
              playClickSound();
              setState(() {
                _isTestMode = !_isTestMode;
                _feedback = '';
                _showAnswer = false;
                _attemptsLeft = 2;
                _answerController.clear();
              });
            },
            tooltip: _isTestMode ? 'Выйти из режима теста' : 'Проверить себя',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isTestMode) ...[
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Text(widget.word.english,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(widget.word.russian,
                          style: const TextStyle(fontSize: 24, color: Colors.grey)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatChip('Уровень', widget.word.difficulty),
                          const SizedBox(width: 12),
                          _buildStatChip('Встреч', '${widget.word.timesEncountered}'),
                          const SizedBox(width: 12),
                          _buildStatChip('Успех', '${(widget.word.successRate * 100).toInt()}%'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Последнее повторение: ${_formatDate(widget.word.lastSeen)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  playClickSound();
                  setState(() => _isTestMode = true);
                },
                icon: const Icon(Icons.quiz),
                label: const Text('Проверить себя'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ] else ...[
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Text('Переведите слово:', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Text(widget.word.english,
                          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _answerController,
                        decoration: InputDecoration(
                          hintText: 'Введите перевод',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        onSubmitted: (_) => _checkAnswer(),
                        enabled: !_showAnswer,
                      ),
                      const SizedBox(height: 16),
                      if (_feedback.isNotEmpty)
                        Text(_feedback,
                            style: TextStyle(
                                color: _feedback.contains('Правильно') ? Colors.green : Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      if (!_showAnswer)
                        ElevatedButton(
                          onPressed: _checkAnswer,
                          child: const Text('Проверить'),
                        ),
                      if (_showAnswer)
                        ElevatedButton.icon(
                          onPressed: () {
                            playClickSound();
                            setState(() {
                              _isTestMode = false;
                              _feedback = '';
                              _showAnswer = false;
                              _attemptsLeft = 2;
                              _answerController.clear();
                            });
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Вернуться к карточке'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'сегодня';
    if (diff.inDays == 1) return 'вчера';
    if (diff.inDays < 7) return '${diff.inDays} дня(ей) назад';
    return '${date.day}.${date.month}.${date.year}';
  }
}