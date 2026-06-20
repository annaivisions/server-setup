<div align="center">

# Server Setup · aivisions

[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/AIvisionsss)
[![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@ai.visionsss)
[![Website](https://img.shields.io/badge/Website-1A73E8?style=for-the-badge&logo=googlechrome&logoColor=white)](https://aivisions.ru)
[![Boosty](https://img.shields.io/badge/Boosty-F15F2C?style=for-the-badge&logo=boosty&logoColor=white)](https://boosty.to/aivisions)

**Помощник, который сам настроит ваш сервер**

Вам не нужно разбираться в командах и технологиях. Просто запустите — и отвечайте на простые вопросы. Всё остальное скрипт сделает за вас: сделает сервер безопаснее и установит нужные программы.

</div>

---

## Как запустить

Скопируйте строчку ниже, вставьте в окно сервера и нажмите Enter:

```bash
bash <(curl -s https://raw.githubusercontent.com/annaivisions/server-setup/main/server-setup-aivisions.sh)
```

Дальше скрипт сам спросит, что вы хотите сделать, и подскажет на каждом шаге.

---

## Что можно выбрать

После запуска появится меню из трёх пунктов:

| № | Что выбрать | Для чего это |
|:-:|-------------|--------------|
| **1** | **Полная установка** | Настроить сервер «под ключ» и установить Claude Code — всё сразу |
| **2** | **Подготовка сервера** | Только настроить и защитить сервер |
| **3** | **Установка Claude Code** | Только установить программу Claude Code |

Если не знаете, что выбрать — выбирайте **1 (Полная установка)**, она подходит в большинстве случаев.

---

## Что именно делает скрипт

**Настройка и защита сервера:**

- 🏷 Даёт серверу понятное имя
- 🔐 Делает вход на сервер безопаснее
- 🧱 Включает «фаервол» — защиту от нежелательных подключений
- 🛡 Защищает от попыток подобрать пароль
- 🔑 Позволяет задать новый пароль (или оставить прежний)
- 📦 Обновляет систему

**Установка Claude Code:**

- 🤖 Устанавливает программу Claude Code и сразу делает её готовой к работе

---

## Что важно знать

- Скрипт работает на серверах с **Ubuntu**
- Запускать его нужно от имени администратора (**root**)
- На каждом шаге есть подсказки — ошибиться сложно

---

<div align="center">

Сделано с ❤️ командой **[AI VISIONS](https://t.me/AIvisionsss)**

[Telegram](https://t.me/AIvisionsss) · [YouTube](https://www.youtube.com/@ai.visionsss) · [Сайт](https://aivisions.ru) · [Boosty](https://boosty.to/aivisions)

</div>
