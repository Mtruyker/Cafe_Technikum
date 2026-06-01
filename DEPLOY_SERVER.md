# Запуск TechCafe API на удаленной VM (Fedora 41)

Ниже обновленные шаги для развертывания сервера с поддержкой SQLite и JWT-авторизации.

- **Пользователь:** `user1`
- **Публичный IP:** `95.174.93.191`
- **ОС:** Fedora 41 Server
- **API порт:** `8080` (TCP)

---

## 1. Подключение по SSH

С вашего ПК (Windows PowerShell):

```powershell
ssh -i C:\Users\Professional\.ssh\id_rsa user1@95.174.93.191
```

---

## 2. Установка Dart SDK и SQLite

На VM (Fedora):

```bash
# Установка необходимых системных библиотек и утилит
sudo dnf install -y wget unzip sqlite-devel git

# Создание каталога для SDK
sudo mkdir -p /usr/lib/dart
sudo chown "$USER" /usr/lib/dart
cd /usr/lib/dart

# Загрузка и распаковка Dart SDK (версия 3.11.0 или новее)
wget https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.0/sdk/dartsdk-linux-x64-release.zip
unzip -q dartsdk-linux-x64-release.zip
rm dartsdk-linux-x64-release.zip

# Добавление в PATH (для текущего пользователя)
echo 'export PATH="/usr/lib/dart/dart-sdk/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Проверка
dart --version
```

---

## 3. Копирование серверной части

С вашего ПК (из корня проекта):

```powershell
cd G:\CafeApp\flutte2
ssh user1@95.174.93.191 "mkdir -p /home/user1/techcafe"
scp -O -r .\server user1@95.174.93.191:/home/user1/techcafe/
```

---

## 4. Первый запуск и настройка окружения

На VM:

```bash
cd /home/user1/techcafe/server
dart pub get

# Ручной запуск для проверки (используйте свой секретный ключ)
export JWT_SECRET="your-safe-secret-key-here"
export PORT=8080
export SEED_DEMO_DATA=true
export DB_PATH="techcafe.db"

dart run bin/server.dart
```

Если сервер успешно запустился, вы увидите: `TechCafe API is running on http://0.0.0.0:8080`.

**Тестовые PIN-коды (при SEED_DEMO_DATA=true):**
- Админ: `9999`
- Кассир: `1111`
- Бариста: `2222`

---

## 5. Открытие порта 8080

На VM (Fedora `firewalld`):

```bash
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

*Не забудьте также открыть TCP 8080 в панели управления вашего облачного провайдера.*

---

## 6. Автозапуск через systemd

Создайте файл сервиса с необходимыми переменными окружения:

```bash
sudo tee /etc/systemd/system/techcafe.service > /dev/null <<'EOF'
[Unit]
Description=TechCafe Dart API (SQLite)
After=network.target

[Service]
User=user1
WorkingDirectory=/home/user1/techcafe/server
# Обязательно замените JWT_SECRET на свой в продакшене!
Environment=PORT=8080
Environment=JWT_SECRET=techcafe-secret-at-95-174-93-191
Environment=DB_PATH=techcafe.db
Environment=SEED_DEMO_DATA=true
ExecStart=/usr/lib/dart/dart-sdk/bin/dart run bin/server.dart
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```

Активация сервиса:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now techcafe
sudo systemctl status techcafe --no-pager
```

---

## 7. Проверка работы

С локального ПК:

```powershell
# Проверка здоровья
curl http://95.174.93.191:8080/health

# Попытка авторизации (должна вернуть JWT токен)
curl -X POST http://95.174.93.191:8080/auth/login `
     -H "Content-Type: application/json" `
     -d '{"pin": "9999"}'
```

---

## 8. Подключение Flutter приложений

При сборке или запуске Flutter приложений используйте флаг `--dart-define`:

```bash
# Гостевое мобильное приложение
flutter run --dart-define=API_BASE_URL=http://95.174.93.191:8080

# Админ-панель (Windows)
flutter run -d windows -t lib/admin_main.dart --dart-define=API_BASE_URL=http://95.174.93.191:8080

# Сборка APK
flutter build apk --dart-define=API_BASE_URL=http://95.174.93.191:8080
```

---

## Обслуживание базы данных

- Файл БД находится по пути: `/home/user1/techcafe/server/techcafe.db`
- Для резервного копирования просто скопируйте этот файл.
- Для сброса данных: удалите файл и перезапустите сервис (при `SEED_DEMO_DATA=true` база создастся заново).

```bash
sudo systemctl restart techcafe
journalctl -u techcafe -f
```
