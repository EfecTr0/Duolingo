import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, dynamic>> register(String login, String password) async {
    final response = await http.post(Uri.parse('$baseUrl/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'login': login, 'password': password}));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Registration failed (${response.statusCode}): ${response.body}');
  }
  static Future<Map<String, dynamic>> login(String login, String password) async {
    final response = await http.post(Uri.parse('$baseUrl/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'login': login, 'password': password}));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Login failed (${response.statusCode}): ${response.body}');
  }
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.get(Uri.parse('$baseUrl/profile'), headers: {'X-Auth-Token': token});
    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 401) await deleteToken();
    throw Exception('Failed to load profile (${response.statusCode}): ${response.body}');
  }
  static Future<void> updateProfile({String? nickname, String? avatar}) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.put(Uri.parse('$baseUrl/profile'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'nickname': nickname, 'avatar': avatar}));
    if (response.statusCode != 200) throw Exception('Failed to update profile (${response.statusCode}): ${response.body}');
  }
  static Future<void> updateStats(int experience, List<int> achievements) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/update_stats'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'experience': experience, 'achievements': jsonEncode(achievements)}));
    if (response.statusCode != 200) throw Exception('Failed to update stats (${response.statusCode}): ${response.body}');
  }
  static Future<void> sendFriendRequest(int targetId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/friend_request'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'target_id': targetId}));
    if (response.statusCode != 200) throw Exception('Failed to send request (${response.statusCode}): ${response.body}');
  }
  static Future<void> acceptRequest(int senderId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/accept_request'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'target_id': senderId}));
    if (response.statusCode != 200) throw Exception('Failed to accept (${response.statusCode}): ${response.body}');
  }
  static Future<void> declineRequest(int senderId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/decline_request'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'target_id': senderId}));
    if (response.statusCode != 200) throw Exception('Failed to decline (${response.statusCode}): ${response.body}');
  }
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/search_users'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'query': query}));
    if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    throw Exception('Search failed (${response.statusCode}): ${response.body}');
  }
  static Future<void> addGameHistory(Map<String, dynamic> result) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/add_game_history'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode(result));
    if (response.statusCode != 200) throw Exception('Failed to add game history (${response.statusCode}): ${response.body}');
  }
  static Future<Map<String, dynamic>> getPublicProfile(int userId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.get(
      Uri.parse('$baseUrl/public_profile/$userId'),
      headers: {'X-Auth-Token': token},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load public profile (${response.statusCode}): ${response.body}');
  }

  // PvP
   static Future<void> updateCollection(List<Map<String, dynamic>> collection) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(
      Uri.parse('$baseUrl/update_collection'),
      headers: {'Content-Type': 'application/json', 'X-Auth-Token': token},
      body: jsonEncode({'collection': jsonEncode(collection)}),
    );
    if (response.statusCode != 200) throw Exception('Failed to update collection');
  }
  static Future<void> leaveGame(String sessionId) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/leave_game?session_id=$sessionId'),
        headers: {'X-Auth-Token': token},
      );
    } catch (_) {}
  }
  static Future<Map<String, dynamic>> sendInvite(int friendId, String difficulty) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(
      Uri.parse('$baseUrl/invite'),
      headers: {'Content-Type': 'application/json', 'X-Auth-Token': token},
      body: jsonEncode({'friend_id': friendId, 'difficulty': difficulty}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to send invite (${response.statusCode}): ${response.body}');
  }
  static Future<List<Map<String, dynamic>>> pollInvites() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.get(Uri.parse('$baseUrl/poll_invites'), headers: {'X-Auth-Token': token});
    if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    throw Exception('Failed to poll invites (${response.statusCode}): ${response.body}');
  }
  static Future<void> acceptInvite(int inviteId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/accept_invite?invite_id=$inviteId'), headers: {'X-Auth-Token': token});
    if (response.statusCode != 200) throw Exception('Failed to accept invite (${response.statusCode}): ${response.body}');
  }
  static Future<void> declineInvite(int inviteId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/decline_invite?invite_id=$inviteId'), headers: {'X-Auth-Token': token});
    if (response.statusCode != 200) throw Exception('Failed to decline invite (${response.statusCode}): ${response.body}');
  }
  static Future<Map<String, dynamic>> getGameState(String sessionId) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.get(Uri.parse('$baseUrl/get_game_state?session_id=$sessionId'), headers: {'X-Auth-Token': token});
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get game state (${response.statusCode}): ${response.body}');
  }
  static Future<void> selectWords(String sessionId, List<String> words) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/select_words'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'session_id': sessionId, 'words': words}));
    if (response.statusCode != 200) throw Exception('Failed to select words (${response.statusCode}): ${response.body}');
  }
  static Future<void> submitAnswer(String sessionId, List<String> answers) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(Uri.parse('$baseUrl/submit_answer'), headers: {'Content-Type': 'application/json', 'X-Auth-Token': token}, body: jsonEncode({'session_id': sessionId, 'answers': answers}));
    if (response.statusCode != 200) throw Exception('Failed to submit answer (${response.statusCode}): ${response.body}');
  }
}