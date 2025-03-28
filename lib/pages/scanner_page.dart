import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:scanner_with_excel/services/excel_helper.dart';
import 'package:scanner_with_excel/services/bluethooth_service.dart';

class CameraScannerPage extends StatefulWidget {
  final String filePath;

  const CameraScannerPage({required this.filePath});

  @override
  State<CameraScannerPage> createState() => _CameraScannerPage();
}

class _CameraScannerPage extends State<CameraScannerPage> with SingleTickerProviderStateMixin {
  static const MethodChannel _channel = MethodChannel("com.ssline.scanner_with_excel/bluetooth");
  late ExcelHelper excelHelper;
  List<String> dataMarks = [];
  bool isConnected = false;
  String? selectedDevice;
  String? connectedDeviceName;
  BluethoothService bluethoothService = BluethoothService();

  @override
  void initState() {
    super.initState();
    excelHelper = ExcelHelper();
    excelHelper.setFilePath(widget.filePath);
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _initializeBluetooth() async {
    isConnected = bluethoothService.isConnected;
    bool permissionsGranted = await bluethoothService.requestPermissions();
    if (!permissionsGranted) {
      print("Разрешения на Bluetooth не предоставлены");
      return;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == "onDataReceived") {
      String scannedData = call.arguments;
      String cleanedData = removeUnreadableCharacters(scannedData);
      setState(() {
        if(!dataMarks.contains(cleanedData)){
          dataMarks.add(cleanedData);
        }

      });
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
      duration: const Duration(seconds: 1, milliseconds: 500),
      backgroundColor: color,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(12),
      flushbarPosition: FlushbarPosition.TOP,
      icon: Icon(
        color == Colors.green ? Icons.check_circle : Icons.warning_amber_rounded,
        color: Colors.white,
      ),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[200]!, Colors.grey[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: dataMarks.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Список пуст\nСканируйте коды для добавления",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: dataMarks.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green[400],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dataMarks[index],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        label: const Text(
          'Готово',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.done, color: Colors.white),
        backgroundColor: Colors.green[600],
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        tooltip: 'Завершить сканирование',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}