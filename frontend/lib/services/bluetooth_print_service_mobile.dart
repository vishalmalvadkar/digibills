
import 'dart:async';
import 'dart:typed_data';

class BluetoothPrintService {
  static final BluetoothPrintService _instance = BluetoothPrintService._internal();
  factory BluetoothPrintService() => _instance;
  BluetoothPrintService._internal();

  Future<void> init() async {
    // Stub
  }

  Future<List<dynamic>> getBondedDevices() async {
    return [];
  }

  Future<bool> connect(dynamic device) async {
    return false;
  }

  Future<void> printThermalPdf(Uint8List pdfData) async {
    print("Native Bluetooth Print Disabled.");
  }
}
