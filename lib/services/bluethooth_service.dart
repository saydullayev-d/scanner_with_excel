import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluethoothService {
  static const MethodChannel _channel =
      MethodChannel("com.ssline.scanner_with_excel/bluetooth");
  List<String> devices = [];
  String? selectedDevice;
  String? connectedDeviceName;
  bool isConnected = false;

// запрос разрешения

  Future<int> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (statuses.values.every((status) => status.isGranted)) {
      return 1;
    } else {
      // Если разрешения нет, запрашиваем через нативный код
      try {
        final bool granted =
            await _channel.invokeMethod('requestBluetoothPermission');
        if (granted) {
          return 1;
        } else {
          return 2;
        }
      } on PlatformException catch (e) {
        debugPrint(e.message);
      }
    }
    return 0;
  }

// поиск устройств

  Future<List<dynamic>> _scanDevices() async {
    List<dynamic> result = [];
    try {
      result = await _channel.invokeMethod('scanDevices');
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
    return result;
  }

// подключение устройства

  Future<bool> _connectToDevice(String? selectedDevice) async {
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

  Future<void> _disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnect');
      isConnected = false;
      connectedDeviceName = null;
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
  }

  Future<void> _saveDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDevice', selectedDevice!);
  }

  Future<bool> _connectToSavedDevice(String device) async {
    try {
      String address = device.split(" - ")[1];
      await _channel.invokeMethod('connectToDevice', {"address": address});
      isConnected = true;
      connectedDeviceName = device;
      return true;
    } on PlatformException catch (e) {
      debugPrint(e.message);
      return false;
    }
  }
}
