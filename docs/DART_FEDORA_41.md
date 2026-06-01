# Установка Dart SDK на Fedora 41 (пошагово)

На Fedora нет официального пакета Dart в репозиториях, поэтому ставим SDK вручную из архива с [dart.dev](https://dart.dev/get-dart/archive).

---

## Шаг 1. Подключиться к VM по SSH

С вашего ПК (PowerShell):

```powershell
ssh -i "C:\Users\Professional\.ssh\id_rsa" user1@95.174.93.191
```

Дальнейшие команды выполняются **на виртуальной машине** (в сессии SSH).

---

## Шаг 2. Проверить архитектуру

Fedora 41 Server на x86_64 — подойдёт архив `linux-x64`. Проверка:

```bash
uname -m
```

Ожидаемо: `x86_64`. Для ARM64 будет `aarch64` — тогда нужен другой архив (см. конец инструкции).

---

## Шаг 3. Установить зависимости

Для загрузки и распаковки архива:

```bash
sudo dnf install -y wget unzip
```

---

## Шаг 4. Скачать Dart SDK (stable)

Каталог для SDK:

```bash
sudo mkdir -p /usr/lib/dart
sudo chown "$USER" /usr/lib/dart
cd /usr/lib/dart
```

Актуальный формат URL архива — с **номером версии** и именем файла **dartsdk-*-release.zip** (не `dart-sdk-*.zip` и не `latest`). Скачать одну из рабочих ссылок:

```bash
# Вариант 1: Dart 3.11 (стабильный)
wget https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.0/sdk/dartsdk-linux-x64-release.zip

# Вариант 2: если 3.11.0 недоступен — попробовать 3.7.2
# wget https://storage.googleapis.com/dart-archive/channels/stable/release/3.7.2/sdk/dartsdk-linux-x64-release.zip
```

Через **curl** (если wget не ставится или блокируется):

```bash
curl -L -o dartsdk-linux-x64-release.zip "https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.0/sdk/dartsdk-linux-x64-release.zip"
```

Если ни одна ссылка не открывается — откройте [Dart SDK Archive](https://dart.dev/get-dart/archive), выберите **Stable**, **Linux**, **x64**, скачайте ZIP на ПК и загрузите на VM через `scp`, затем распакуйте в `/usr/lib/dart`.

---

## Шаг 5. Распаковать архив

```bash
cd /usr/lib/dart
unzip -q dartsdk-linux-x64-release.zip
ls
```

Внутри появится каталог вида `dart-sdk` (или `dart-sdk-3.11.0`). Удалить архив (по желанию):

```bash
rm dartsdk-linux-x64-release.zip
```

---

## Шаг 6. Добавить Dart в PATH

Узнайте точное имя распакованной папки (например `dart-sdk` или `dart-sdk-3.11.0`):

```bash
ls /usr/lib/dart
```

Подставьте его в PATH. Обычно папка называется `dart-sdk`:

```bash
echo 'export PATH="/usr/lib/dart/dart-sdk/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Если папка названа иначе (например `dart-sdk-3.11.0`):

```bash
echo 'export PATH="/usr/lib/dart/dart-sdk-3.11.0/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Только для текущей сессии:

```bash
export PATH="/usr/lib/dart/dart-sdk/bin:$PATH"
```

---

## Шаг 7. Проверить установку

```bash
dart --version
```

Пример вывода: `Dart SDK version: 3.x.x (stable) ...`.

Проверка `pub`:

```bash
dart pub --version
```

---

## Шаг 8. (Опционально) Установка для всех пользователей

Если нужен доступ к `dart` для всех пользователей и без прав владельца на `/usr/lib/dart`:

```bash
sudo unzip -o dartsdk-linux-x64-release.zip -d /usr/lib
sudo chown -R root:root /usr/lib/dart-sdk
```

Добавить в системный PATH (создайте файл в `/etc/profile.d/`):

```bash
echo 'export PATH="/usr/lib/dart-sdk/bin:$PATH"' | sudo tee /etc/profile.d/dart.sh
sudo chmod 644 /etc/profile.d/dart.sh
```

После нового входа по SSH или после `source /etc/profile.d/dart.sh` команда `dart` будет доступна всем.

---

## Обновление Dart

Скачать новый архив с [архива](https://dart.dev/get-dart/archive), распаковать поверх старой папки или в новую и обновить PATH. Либо повторить шаги 4–5 с новой версией и перезаписать `/usr/lib/dart/dart-sdk`.

---

## Другие архитектуры (ARM64)

Если `uname -m` выводит `aarch64`:

- Скачать архив для **Linux ARM64** (подставьте нужную версию, например 3.11.0):  
  `https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.0/sdk/dartsdk-linux-arm64-release.zip`
- Распаковать в `/usr/lib/dart`, добавить в PATH путь к `bin` внутри распакованной папки.

---

## Краткая последовательность (копировать целиком)

Выполнять на VM по SSH:

```bash
# Зависимости
sudo dnf install -y wget unzip

# Каталог и загрузка (URL с конкретной версией и именем dartsdk-*-release.zip)
sudo mkdir -p /usr/lib/dart
sudo chown "$USER" /usr/lib/dart
cd /usr/lib/dart
wget https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.0/sdk/dartsdk-linux-x64-release.zip
unzip -q dartsdk-linux-x64-release.zip
rm dartsdk-linux-x64-release.zip

# PATH (если папка называется иначе — замените dart-sdk на имя из ls)
echo 'export PATH="/usr/lib/dart/dart-sdk/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Проверка
dart --version
```

После этого можно переходить к запуску TechCafe API: копировать папку `server`, выполнить `dart pub get` и `dart run bin/server.dart` (см. `DEPLOY_SERVER.md`).
