TUP Announcement App
A Flutter-based announcement and campus information app UI for students and campus organizations at Technological University of the Philippines (TUP).
This repository currently contains the frontend/UI prototype. Backend services, persistent storage, and real authentication still need to be integrated.
Features
Home feed — sample announcements with search, category filters, scope filters, and active/expired labels
Announcement details — announcement description, dates, office information, and attachment placeholder
Campus Events — a screen for campus event information
Student Handbook — searchable handbook topics with detail placeholders
Notification Preferences — toggles for notification settings
Officer Login — demo login screen; it does not authenticate against a real backend
Publish Announcement — form UI with category, office, description, date pickers, and attachment placeholder
> **Prototype note:** Announcement data is currently kept in local in-memory state. Changes made through the UI are not saved to a database and may be lost when the app restarts. Login, sharing, calendar, and attachment-related actions may be placeholders or demos.
Tech Stack
Flutter
Dart
Material UI components
Requirements
Install the Flutter SDK and configure a supported target such as Google Chrome, Android, or iOS. Verify your setup with:
```bash
flutter doctor
```
Run the App
Clone the repository:
```bash
   git clone https://github.com/welven-dev/tup-announcement-app.git
   cd tup-announcement-app
   ```
Get the Flutter dependencies:
```bash
   flutter pub get
   ```
Run the app in Chrome:
```bash
   flutter run -d chrome
   ```
Or run it on a configured emulator/device:
```bash
   flutter run
   ```
Project Structure
```text
tup-announcement-app/
├── lib/
│   └── main.dart       # Main app UI and screen implementations
├── pubspec.yaml        # Flutter package configuration
├── pubspec.lock        # Resolved package versions
└── README.md
```
Team Collaboration
This project is being developed with a separation between frontend and backend responsibilities.
Frontend/UI: Flutter screens, layout, navigation, and user interactions.
Backend: To be integrated — API endpoints, database persistence, and real authentication.
Before connecting the backend, coordinate API contracts with the UI developer, including announcement fields, categories, dates, attachments, and authentication requirements. Avoid committing credentials, tokens, or other secrets to this public repository.
Current Status
[x] Initial Flutter UI prototype
[x] Basic screen navigation and sample content
[ ] Backend API integration
[ ] Database persistence
[ ] Real authentication and authorization
[ ] Production attachment upload and notification delivery
Repository
https://github.com/welven-dev/tup-announcement-app