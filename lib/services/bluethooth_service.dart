import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluethoothService {
  static const MethodChannel _channel =
      MethodChannel("com.ssline.scanner_with_excel/bluetooth");
  String? connectedDeviceName;
  bool isConnected = false;

// запрос разрешения

Future<bool> requestPermissions() async {
  try {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      return true;
    } else {
      // Если разрешения нет, запрашиваем через нативный код
      final bool granted = await _channel.invokeMethod('requestBluetoothPermission');
      return granted;
    }
  } on PlatformException catch (e) {
    debugPrint("Ошибка при запросе разрешений: ${e.message}");
    return false;
  }
}

// поиск устройств

  Future<List<dynamic>> scanDevices() async {
    List<dynamic> result = [];
    try {
      result = await _channel.invokeMethod('scanDevices');
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
    return result;
  }

// подключение устройства

  Future<bool> connectToDevice(String? selectedDevice) async {
    if (selectedDevice == null) {
      return false;
    }
    try {
      String address = selectedDevice!.split(" - ")[1];
      await _channel.invokeMethod('connectToDevice', {"address": address});
      isConnected = true;
      connectedDeviceName = selectedDevice;
      return true;
    } on PlatformException catch (e) {
      debugPrint(e.message);
      return false;
    }
  }

// отключение устройства

  Future<void> disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnect');
      isConnected = false;
      connectedDeviceName = null;
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
  }

  Future<void> saveDevice(String selectedDevice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDevice', selectedDevice!);
  }

  Future<bool> connectToSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevice = prefs.getString('selectedDevice');
      if (savedDevice != null) {
        String address = savedDevice.split(" - ")[1];
        await _channel.invokeMethod('connectToDevice', {"address": address});
        isConnected = true;
        connectedDeviceName = savedDevice;
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint(e.message);
      return false;
    }
  }
}
