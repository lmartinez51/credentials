class BleConstants {
  // Service UUID (if applicable, but we scan for characteristic UUIDs directly in the original code)
  
  // Characteristic UUIDs
  static const String wifiCredsCharacteristicUuid = '01ffbc9a-7856-3412-ffde-bc9a78563412';
  static const String apiKeyCharacteristicUuid = '02ffbc9a-7856-3412-ffde-bc9a78563412';
  static const String sysCmdCharacteristicUuid = '03ffbc9a-7856-3412-ffde-bc9a78563412';

  // Commands
  static const String cmdEraseNvs = 'CMD:ERASE_NVS';

  // AI Chatbot BLE Markers
  static const List<int> aiMarkerPrefix = [0x41, 0x49, 0x43]; // "AIC"
}
