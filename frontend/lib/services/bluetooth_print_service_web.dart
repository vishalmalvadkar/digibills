
import 'dart:async';
import 'dart:typed_data';

class BluetoothPrintService {
  // Singleton Pattern
  static final BluetoothPrintService _instance = BluetoothPrintService._internal();
  factory BluetoothPrintService() => _instance;
  BluetoothPrintService._internal();

  Future<void> init() async {
    // No-op on Web
  }

  Future<List<dynamic>> getBondedDevices() async {
    return [];
  }

  Future<bool> connect(dynamic device) async {
    return false;
  }

  Future<void> printThermalPdf(Uint8List pdfData) async {
    // On Web, we rely on standard browser print
    print("Bluetooth printing is not supported on Web. Use System Print.");
  }
}
