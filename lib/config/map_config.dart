class MapConfig {
  // Supplied with --dart-define-from-file=.env; the file itself is not bundled.
  static const apiKey = String.fromEnvironment('MAPTILER_KEY');
  static const styleId = String.fromEnvironment(
    'MAPTILER_STYLE_ID',
    defaultValue: 'streets-v4',
  );
}
