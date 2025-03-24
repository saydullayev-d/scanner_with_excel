import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:scanner_with_excel/services/bluethooth_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  String? selectedDevice;
  String? connectedDeviceName;
  bool isConnected = false;
  List<dynamic> devices = [];
  BluethoothService bluethoothService = BluethoothService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _buttonAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeBluetooth();
  }

Future<void> _initializeBluetooth() async {
  isConnected = bluethoothService.isConnected;
  bool permissionsGranted = await bluethoothService.requestPermissions();
  if (!permissionsGranted) {
    print("Разрешения на Bluetooth не предоставлены");
    return;
  }

  List<dynamic> scannedDevices = await bluethoothService.scanDevices();

  setState(() {
    devices = scannedDevices;
    if (isConnected) {
      connectedDeviceName = bluethoothService.connectedDeviceName;
      _animationController.stop();
    } else {
      print("Попытка подключения к сохранённому устройству...");
      bluethoothService.connectToSavedDevice().then((_) {
        setState(() {
          isConnected = bluethoothService.isConnected;
          connectedDeviceName = bluethoothService.connectedDeviceName;
          if (isConnected) {
            print("Успешно подключено к: $connectedDeviceName");
          } else {
            print("Не удалось подключиться");
          }
          _animationController.stop();
        });
      }).catchError((e) {
        print("Ошибка при подключении: $e");
      });
    }
  });
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  onChanged: isConnected
                      ? null
                      : (value) => setState(() => selectedDevice = value),
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
                onPressed: isConnected
                    ? null
                    : () async {
                        List<dynamic> scannedDevices =
                            await bluethoothService.scanDevices();
                        setState(() {
                          devices = scannedDevices;
                        });
                      },
              ),
              const SizedBox(height: 20),
              _buildAnimatedButton(
                text: "Подключиться",
                icon: Icons.bluetooth_connected,
                color: Colors.green,
                onPressed: isConnected || selectedDevice == null
                    ? null
                    : () async {
                        await bluethoothService
                            .connectToDevice(selectedDevice!);
                        setState(() {
                          isConnected = bluethoothService.isConnected;
                          connectedDeviceName =
                              bluethoothService.connectedDeviceName;
                        });
                      },
              ),
              const SizedBox(height: 20),
              _buildAnimatedButton(
                text: "Отключиться",
                icon: Icons.bluetooth_disabled,
                color: Colors.redAccent,
                onPressed:
                    isConnected ? bluethoothService.disconnectDevice : null,
              ),
            ],
          ),
        ),
      ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 6,
              shadowColor: Colors.black.withOpacity(0.3),
            ),
          ),
        );
      },
    );
  }
}
