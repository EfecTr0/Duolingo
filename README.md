# Language Learning App (Pascalingo)

Интерактивное кроссплатформенное приложение для изучения английского языка с русским интерфейсом.  
Разработано на Flutter, с серверной частью на Python и поддержкой голосового ввода.

## 📱 Возможности

- **4 уровня сложности** – Начинающий, Средний, Продвинутый, Профессионал
- **3 игровых режима** – Сопоставление карточек, Викторина, Перетаскивание (Drag & Drop)
- **Режим PvP** – соревнование с друзьями в реальном времени
- **Голосовой ввод** – распознавание речи через Web Speech API
- **Тёмная и светлая темы**
- **Сохранение прогресса** – звёзды за выполненные упражнения (SharedPreferences)
- **Кроссплатформенность** – Android, Windows, Web (Chrome / Edge)

## 🗂 Структура проекта

.
├── server.py # Серверная часть (Python + PostgreSQL)
├── game_app/ # Клиентское Flutter-приложение
│ ├── lib/
│ │ ├── main.dart # Точка входа, JS-интероп
│ │ ├── login_screen.dart
│ │ ├── main_screen.dart
│ │ ├── api_service.dart
│ │ ├── data/
│ │ │ ├── player.dart
│ │ │ └── words.dart
│ │ └── screens/
│ │ ├── menu_screen.dart
│ │ ├── game_screen.dart
│ │ ├── matching_cards_game.dart
│ │ ├── match_game_screen.dart
│ │ ├── mixed_game_screen.dart
│ │ ├── pvp_game_screen.dart
│ │ ├── profile_screen.dart
│ │ ├── friends_screen.dart
│ │ └── settings_screen.dart
│ ├── assets/audio/ # Фоновая музыка
│ ├── web/ # Веб-конфигурация, звуковые эффекты
│ └── pubspec.yaml
└── README.md


## 🛠 Технологии

| Часть | Технологии |
|-------|------------|
| **Клиент** | Flutter (Dart), `shared_preferences`, `http`, `dart:js` |
| **Сервер** | Python 3.x, REST API, PostgreSQL |
| **Аудио** | Web Audio API, MP3/OGG |
| **Голос** | Web Speech API (Chrome/Edge) |

## 🚀 Быстрый запуск (веб-версия)

### 1. Клонирование репозитория
```bash
git clone https://github.com/EfecTr0/Duolingo
cd Duolingo/game_app
2. Установка зависимостей Flutter
bash
flutter pub get
3. Запуск веб-сервера
bash
flutter run -d web-server --web-port=8080
Откройте браузер и перейдите на http://localhost:8080/.

При ошибке «Failed to bind» используйте другой порт: --web-port=5555

🖥 Запуск серверной части (для входа, PvP и AI)
bash
cd ..                # из game_app в корень проекта
python server.py     # убедитесь, что PostgreSQL запущен и настроен
Сервер ожидает подключения на порту 8000 (по умолчанию).

📚 Документация
Техническое задание – файл ТЗ.pdf (или отдельный документ)

Отчёт по проекту – 20+ страниц, LaTeX (Overleaf)

README – этот файл

👥 Разработчики
Амана Бикиливе Паскаль

Старченко Денис

Абашилов Магомед

Группа БИВ 255, МИЕМ НИУ ВШЭ, 2026 г.

🔗 Ссылки
Репозиторий: https://github.com/EfecTr0/Duolingo

Flutter: https://flutter.dev

Dart: https://dart.dev