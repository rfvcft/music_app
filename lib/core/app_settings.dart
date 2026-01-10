class AppSettings {
  // Singleton instance
  static final AppSettings instance = AppSettings._internal();

  // Private constructor
  AppSettings._internal();

  // Settings variables
  bool showPitchClasses = true;

  // Add more settings as needed
}
