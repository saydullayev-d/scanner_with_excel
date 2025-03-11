import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:another_flushbar/flushbar.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:scanner_with_excel/services/excel_helper.dart';

class CameraScannerPage extends StatefulWidget {
  final String filePath;

  const CameraScannerPage({required this.filePath});

  @override
  State<CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<CameraScannerPage> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  bool isScanningPaused = false;
  late ExcelHelper excelHelper;
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    excelHelper = ExcelHelper();
    excelHelper.setFilePath(widget.filePath);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0, end: 250).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Сканер",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => controller.toggleTorch(),
            tooltip: 'Включить/выключить фонарик',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (isScanningPaused) return;
              isScanningPaused = true;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  String rawText = barcode.rawValue!;
                  String cleanedData = removeUnreadableCharacters(rawText);
                  await _handleScannedData(cleanedData);
                } else {
                  _showScanErrorNotification(context);
                }
              }
              await Future.delayed(const Duration(seconds: 4));
              isScanningPaused = false;
            },
          ),
          Center(
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: ScannerOverlayPainter(scanLinePosition: _scanLineAnimation.value),
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                top: (MediaQuery.of(context).size.height - 335) / 2 + _scanLineAnimation.value,
                left: (MediaQuery.of(context).size.width - 250) / 2,
                child: Container(
                  width: 250,
                  height: 2,
                  color: Colors.blueAccent.withOpacity(0.7),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        label: const Text('Готово', style: TextStyle(fontSize: 16)),
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
      flushbarPosition: FlushbarPosition.BOTTOM,
      icon: Icon(
        color == Colors.green ? Icons.check_circle : Icons.warning_amber_rounded,
        color: Colors.white,
      ),
    ).show(context);
  }

  void _showScanErrorNotification(BuildContext context) {
    Flushbar(
      message: 'Не удалось считать код. Попробуйте снова.',
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.redAccent,
      margin: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(12),
      flushbarPosition: FlushbarPosition.TOP,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
      icon: const Icon(
        Icons.error,
        color: Colors.white,
        size: 28,
      ),
      leftBarIndicatorColor: Colors.white,
    ).show(context);
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double scanLinePosition;

  ScannerOverlayPainter({required this.scanLinePosition});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBackground = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final double scanBoxSize = 250;
    final double scanBoxLeft = (size.width - scanBoxSize) / 2;
    final double scanBoxTop = (size.height - scanBoxSize) / 2;
    final Rect scanBoxRect = Rect.fromLTWH(scanBoxLeft, scanBoxTop, scanBoxSize, scanBoxSize);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(screenRect),
        Path()..addRect(scanBoxRect),
      ),
      paintBackground,
    );

    final paintBorder = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(scanBoxRect, paintBorder);

    final paintCorners = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final double cornerLength = 30;

    canvas.drawLine(
        scanBoxRect.topLeft,
        scanBoxRect.topLeft.translate(cornerLength, 0),
        paintCorners);
    canvas.drawLine(
        scanBoxRect.topLeft,
        scanBoxRect.topLeft.translate(0, cornerLength),
        paintCorners);

    canvas.drawLine(
        scanBoxRect.topRight,
        scanBoxRect.topRight.translate(-cornerLength, 0),
        paintCorners);
    canvas.drawLine(
        scanBoxRect.topRight,
        scanBoxRect.topRight.translate(0, cornerLength),
        paintCorners);

    canvas.drawLine(
        scanBoxRect.bottomLeft,
        scanBoxRect.bottomLeft.translate(cornerLength, 0),
        paintCorners);
    canvas.drawLine(
        scanBoxRect.bottomLeft,
        scanBoxRect.bottomLeft.translate(0, -cornerLength),
        paintCorners);

    canvas.drawLine(
        scanBoxRect.bottomRight,
        scanBoxRect.bottomRight.translate(-cornerLength, 0),
        paintCorners);
    canvas.drawLine(
        scanBoxRect.bottomRight,
        scanBoxRect.bottomRight.translate(0, -cornerLength),
        paintCorners);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true; // Repaint for animation
}