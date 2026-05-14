import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 50),
            // Задел под аватарку и шкалу уровня
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Уровень: 5', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      LinearProgressIndicator(value: 0.7),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Кнопка Играть по центру
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Здесь будет переход к игре
                },
                child: const Text('Играть', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}