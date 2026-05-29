import 'package:flutter/material.dart';
import 'api_service.dart';
import 'data/player.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<bool> onToggleTheme;
  final VoidCallback onResetTheme;
  const LoginScreen({
    Key? key,
    required this.onToggleTheme,
    required this.onResetTheme,
  }) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;

  void _submit() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text.trim();
    if (login.isEmpty || password.isEmpty) return;

    try {
      Map<String, dynamic> data;
      if (_isLogin) {
        data = await ApiService.login(login, password);
      } else {
        data = await ApiService.register(login, password);
      }
      await ApiService.saveToken(data['access_token']);
      final profile = await ApiService.getProfile();
      PlayerData().initFromProfile(profile);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Вход' : 'Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _loginController,
              decoration: const InputDecoration(labelText: 'Логин'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
            ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? 'Создать аккаунт' : 'Уже есть аккаунт'),
            ),
          ],
        ),
      ),
    );
  }
}