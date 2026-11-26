enum AppFlavor {
  dev,
  staging,
  prod;

  static AppFlavor fromString(String value) {
    return switch (value.toLowerCase()) {
      'prod' || 'production' => AppFlavor.prod,
      'staging' => AppFlavor.staging,
      _ => AppFlavor.dev,
    };
  }
}
