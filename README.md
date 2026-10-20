# TUP Announcement App

A Flutter-based announcement and campus information app UI for students and campus organizations at the **Technological University of the Philippines (TUP)**.

This repository currently contains the **frontend/UI prototype**. Backend services, persistent storage, and real authentication still need to be integrated.

## Features

- **Home Feed** — Sample announcements with search, category filters, scope filters, and active/expired labels.
- **Announcement Details** — Announcement description, dates, office information, and attachment placeholder.
- **Campus Events** — A screen for campus event information.
- **Student Handbook** — Searchable handbook topics with detail placeholders.
- **Notification Preferences** — Toggles for notification settings.
- **Officer Login** — Demo login screen; it does not authenticate against a real backend.
- **Publish Announcement** — Form UI with category, office, description, date pickers, and attachment placeholder.

> **Prototype Note:** Announcement data is currently kept in local in-memory state. Changes made through the UI are not saved to a database and may be lost when the app restarts. Login, sharing, calendar, and attachment-related actions may be placeholders or demos.

## Tech Stack

- Flutter
- Dart
- Material UI components

## Requirements

Install the Flutter SDK and configure a supported target, such as Google Chrome, Android, or iOS.

Verify your setup:

```bash
flutter doctor
```

## Run the App

Clone the repository:

```bash
git clone https://github.com/welven-dev/tup-announcement-app.git
cd tup-announcement-app
```

Install dependencies:

```bash
flutter pub get
```

Run in Chrome:

```bash
flutter run -d chrome
```

Or run on a configured emulator or device:

```bash
flutter run
```

## Project Structure

```text
tup-announcement-app/
├── lib/
│   └── main.dart
├── test/
├── web/
├── android/
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

## Team Collaboration

This project separates frontend and backend responsibilities.

- **Frontend/UI:** Flutter screens, layout, navigation, and user interactions.
- **Backend:** API endpoints, database persistence, and real authentication — to be integrated.

Coordinate API requirements with the backend developer, including announcement fields, categories, dates, attachments, and authentication.

**Security:** Never commit passwords, access tokens, database credentials, or other secrets to this public repository.

## Current Status

- [x] Initial Flutter UI prototype
- [x] Basic screen navigation and sample content
- [ ] Backend API integration
- [ ] Database persistence
- [ ] Real authentication and authorization
- [ ] Production attachment uploads and notification delivery

## Repository

[GitHub — TUP Announcement App](https://github.com/welven-dev/tup-announcement-app)
