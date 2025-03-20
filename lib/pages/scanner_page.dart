import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:scanner_with_excel/services/excel_helper.dart';

class CameraScannerPage extends StatefulWidget {
  final String filePath;

  const CameraScannerPage({required this.filePath});

  @override
  State<CameraScannerPage> createState() => _CameraScannerPage();
}

class _CameraScannerPage extends State<CameraScannerPage> with SingleTickerProviderStateMixin {
  static const MethodChannel _channel = MethodChannel("com.ssline.scanner_with_excel/bluetooth");
  List<String> devices = [];
  String? selectedDevice;
  String? connectedDeviceName;
  bool isConnected = false;
  late ExcelHelper excelHelper;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    excelHelper = ExcelHelper();
    excelHelper.setFilePath(widget.filePath);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _buttonAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _channel.setMethodCallHandler(_handleMethodCall);
    _checkConnectionStatus();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (statuses.values.every((status) => status.isGranted)) {
      _scanDevices();
    } else {
      // Если разрешения нет, запрашиваем через нативный код
      try {
        final bool granted = await _channel.invokeMethod('requestBluetoothPermission');
        if (granted) {
          _scanDevices();
        } else {
          _showNotification(context, "Bluetooth разрешения отклонены", Colors.red);
        }
      } on PlatformException catch (e) {
        _showNotification(context, "Ошибка запроса разрешений: ${e.message}", Colors.red);
      }
    }
  }

  Future<void> _checkConnectionStatus() async {
    try {
      final Map<dynamic, dynamic>? status = await _channel.invokeMethod('isConnected');
      setState(() {
        isConnected = status?['isConnected'] ?? false;
        connectedDeviceName = status?['deviceName'];
      });
      if (isConnected) {
        _animationController.stop();
      } else {
        _animationController.repeat(reverse: true);
      }
    } on PlatformException catch (e) {
      _showNotification(context, "Ошибка проверки состояния: ${e.message}", Colors.red);
    }
  }

  Future<void> _scanDevices() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('scanDevices');
      setState(() {
        devices = result.cast<String>();
      });
    } on PlatformException catch (e) {
      _showNotification(context, "Ошибка сканирования: ${e.message}", Colors.red);
    }
  }

  Future<void> _connectToDevice() async {
    if (selectedDevice == null) {
      _showNotification(context, "Выберите устройство", Colors.orange);
      return;
    }
    try {
      String address = selectedDevice!.split(" - ")[1];
      await _channel.invokeMethod('connectToDevice', {"address": address});
      setState(() {
        isConnected = true;
        connectedDeviceName = selectedDevice;
        _animationController.stop();
      });
      _showNotification(context, "Подключено", Colors.green);
    } on PlatformException catch (e) {
      _showNotification(context, "Ошибка подключения: ${e.message}", Colors.red);
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnect');
      setState(() {
        isConnected = false;
        connectedDeviceName = null;
        _animationController.repeat(reverse: true);
      });
      _showNotification(context, "Отключено", Colors.green);
    } on PlatformException catch (e) {
      _showNotification(context, "Ошибка отключения: ${e.message}", Colors.red);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == "onDataReceived") {
      String scannedData = call.arguments;
      String cleanedData = removeUnreadableCharacters(scannedData);
      await _handleScannedData(cleanedData);
    }
  }

  Future<void> _handleScannedData(String scannedData) async {
    if (await excelHelper.isDataUnique(scannedData)) {
      await excelHelper.addData(scannedData);
      _showNotification(context, "Код добавлен", Colors.green);
    } else {
      _showNotification(context, "Код уже существует", Colors.orange);
    }
  }

  String removeUnreadableCharacters(String input) {
    RegExp regExp = RegExp(r'[^\x20-\x7E]');
    return input.replaceAll(regExp, '');
  }

  void _showNotification(BuildContext context, String message, Color color) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 3),
      backgroundColor: color,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      flushbarPosition: FlushbarPosition.TOP,
      icon: Icon(
        color == Colors.green ? Icons.check_circle : Icons.warning_amber_rounded,
        color: Colors.white,
      ),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Сканер Bluetooth${isConnected ? " (Подключено)" : ""}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[100]!, Colors.grey[300]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: selectedDevice,
                  hint: const Text(
                    "Выберите устройство",
                    style: TextStyle(color: Colors.grey),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: devices.map((device) {
                    return DropdownMenuItem<String>(
                      value: device,
                      child: Text(
                        device,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                  onChanged: isConnected ? null : (value) => setState(() => selectedDevice = value),
                ),
              ),
              if (isConnected && connectedDeviceName != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Text(
                    "Подключено к: $connectedDeviceName",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 30),
              _buildAnimatedButton(
                text: "Сканировать устройства",
                icon: Icons.bluetooth_searching,
                color: Colors.blueAccent,
                onPressed: isConnected ? null : _scanDevices,
              ),
              const SizedBox(height: 20),
              _buildAnimatedButton(
                text: "Подключиться",
                icon: Icons.bluetooth_connected,
                color: Colors.green,
                onPressed: isConnected ? null : _connectToDevice,
              ),
              const SizedBox(height: 20),
              _buildAnimatedButton(
                text: "Отключиться",
                icon: Icons.bluetooth_disabled,
                color: Colors.redAccent,
                onPressed: isConnected ? _disconnectDevice : null,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        label: const Text(
          'Готово',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.done),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tooltip: 'Завершить сканирование',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAnimatedButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return AnimatedBuilder(
      animation: _buttonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: onPressed != null ? _buttonAnimation.value : 1.0,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 24),
            label: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 6,
              shadowColor: Colors.black.withOpacity(0.3),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}