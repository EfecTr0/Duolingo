import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api_service.dart';
import 'pvp_game_screen.dart';

class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loadingFriends = true;
  bool _loadingRequests = true;
  final TextEditingController _searchController = TextEditingController();
  bool _sendingInvite = false;
  Timer? _inviteTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _startPollingInvites();
  }

  void _startPollingInvites() {
    _inviteTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkInvites());
  }

  void _checkInvites() async {
    if (!mounted) return;
    try {
      final invites = await ApiService.pollInvites();
      if (invites.isNotEmpty && mounted) {
        final invite = invites.first;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Приглашение от ${invite['nickname']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(invite['avatar'], radius: 30),
                Text('Уровень: ${invite['level']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await ApiService.declineInvite(invite['invite_id']);
                  Navigator.pop(ctx);
                },
                child: const Text('Отклонить'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await ApiService.acceptInvite(invite['invite_id']);
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PvPGameScreen(sessionId: invite['session_id']),
                    ),
                  );
                },
                child: const Text('Принять'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    await Future.wait([_loadFriends(), _loadRequests()]);
  }

  Future<void> _loadFriends() async {
    try {
      final profile = await ApiService.getProfile();
      final friends =
          List<Map<String, dynamic>>.from(profile['friends'] ?? []);
      setState(() {
        _friends = friends;
        _loadingFriends = false;
      });
    } catch (e) {
      setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadRequests() async {
    try {
      final profile = await ApiService.getProfile();
      final requests =
          List<Map<String, dynamic>>.from(profile['requests'] ?? []);
      setState(() {
        _requests = requests;
        _loadingRequests = false;
      });
    } catch (e) {
      setState(() => _loadingRequests = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      final results = await ApiService.searchUsers(query);
      setState(() => _searchResults = results);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка поиска: $e')),
      );
    }
  }

  Future<void> _sendRequest(int targetId) async {
    try {
      await ApiService.sendFriendRequest(targetId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка отправлена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _acceptRequest(int senderId) async {
    try {
      await ApiService.acceptRequest(senderId);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _declineRequest(int senderId) async {
    try {
      await ApiService.declineRequest(senderId);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  void _showDifficultyDialog(int friendId) {
    String selectedDifficulty = 'лёгкий';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Выберите сложность'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['лёгкий', 'средний', 'сложный', 'носитель']
                .map((d) => RadioListTile<String>(
                      title: Text(d),
                      value: d,
                      groupValue: selectedDifficulty,
                      onChanged: (val) =>
                          setDialogState(() => selectedDifficulty = val!),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _sendInvite(friendId, selectedDifficulty);
              },
              child: const Text('Пригласить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendInvite(int friendId, String difficulty) async {
    if (_sendingInvite) return;
    setState(() => _sendingInvite = true);
    try {
      final result = await ApiService.sendInvite(friendId, difficulty);
      final sessionId = result['session_id'];
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PvPGameScreen(sessionId: sessionId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingInvite = false);
    }
  }

  // Просмотр профиля друга
  void _showFriendProfile(int friendId) async {
    try {
      final profile = await ApiService.getPublicProfile(friendId);
      if (!mounted) return;
      final topWords = _getTopFrequentWords(profile['collection'] as List?);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(profile['nickname'] ?? 'id:$friendId'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: profile['avatar'] != null &&
                          profile['avatar'].toString().isNotEmpty
                      ? MemoryImage(
                          Uint8List.fromList(base64Decode(profile['avatar'])))
                      : null,
                  child: profile['avatar'] == null ||
                          profile['avatar'].toString().isEmpty
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 8),
                Text('Уровень: ${profile['level']}'),
                const SizedBox(height: 4),
                Text('ID: $friendId'),
                const Divider(),
                Text(
                    'Достижения: ${(profile['achievements'] as List?)?.length ?? 0}'),
                const SizedBox(height: 12),
                if (topWords.isNotEmpty) ...[
                  const Text('Частые слова:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...topWords.map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                            '${w['english']} — ${w['timesEncountered']} раз'),
                      )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка загрузки профиля')));
    }
  }

  List<Map<String, dynamic>> _getTopFrequentWords(List? collection) {
    if (collection == null || collection.isEmpty) return [];
    final words = List<Map<String, dynamic>>.from(
        collection.map((e) => Map<String, dynamic>.from(e)));
    words.sort((a, b) =>
        (b['timesEncountered'] as int).compareTo(a['timesEncountered'] as int));
    return words.take(3).toList();
  }

  Widget _buildAvatar(String? avatarBase64, {double radius = 18}) {
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(avatarBase64);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, size: radius, color: Colors.white),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _inviteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Друзья'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Друзья'),
            Tab(text: 'Заявки'),
            Tab(text: 'Поиск'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Друзья
          _loadingFriends
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadFriends,
                  child: _friends.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 200),
                          Center(child: Text('У вас пока нет друзей')),
                        ])
                      : ListView.builder(
                          itemCount: _friends.length,
                          itemBuilder: (context, index) {
                            final friend = _friends[index];
                            return ListTile(
                              leading: _buildAvatar(friend['avatar']),
                              title: Text(
                                  friend['nickname'] ?? 'id:${friend['id']}'),
                              subtitle: Text('Уровень: ${friend['level']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.info_outline),
                                    onPressed: () =>
                                        _showFriendProfile(friend['id']),
                                  ),
                                  _sendingInvite
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.play_arrow,
                                              color: Colors.blue),
                                          onPressed: () =>
                                              _showDifficultyDialog(
                                                  friend['id']),
                                        ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
          // Заявки
          _loadingRequests
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: _requests.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 200),
                          Center(child: Text('Нет входящих заявок')),
                        ])
                      : ListView.builder(
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final req = _requests[index];
                            return ListTile(
                              leading: _buildAvatar(req['avatar']),
                              title:
                                  Text(req['nickname'] ?? 'id:${req['id']}'),
                              subtitle: Text('Уровень: ${req['level']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    onPressed: () =>
                                        _acceptRequest(req['id']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _declineRequest(req['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
          // Поиск
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                            labelText: 'Поиск по ID или нику'),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _search),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: _buildAvatar(user['avatar']),
                      title: Text(user['nickname'] ?? 'id:${user['id']}'),
                      subtitle: Text('Уровень: ${user['level']}'),
                      trailing: ElevatedButton(
                        onPressed: () => _sendRequest(user['id']),
                        child: const Text('Добавить'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}