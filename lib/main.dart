import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:scanner_with_excel/services/excel_helper.dart';
import 'package:scanner_with_excel/pages/scanner_page.dart';
import 'package:intl/intl.dart';
import 'package:scanner_with_excel/pages/setting_page.dart';
import 'package:scanner_with_excel/services/bluethooth_service.dart';
import 'package:scanner_with_excel/services/checkbox_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CheckboxState(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Файлы',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: FileListScreen(),
    );
  }
}

class FileListScreen extends StatefulWidget {
  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  List<File> files = [];
  final String dirPath = Directory.systemTemp.path;
  late ExcelHelper excelHelper;
  String? connetctedDeviceName;
  bool isConnected = false;
  final bluethoothService = BluethoothService();

  @override
  void initState() {
    super.initState();
    excelHelper = ExcelHelper();
    _loadFiles();
    _bluetoothConnect();
  }

  Future<void> _bluetoothConnect() async {
    connetctedDeviceName = bluethoothService.connectedDeviceName;
    if (connetctedDeviceName == null) {
      isConnected = await bluethoothService.connectToSavedDevice();
    }
    if (isConnected == false) {
      _showBluetoothConnectionFailedModal();
    }
  }

  void _openBluetoothSettings() async {
    Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
  }

  void _showBluetoothConnectionFailedModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Для обработки клавиатуры и прокрутки
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        // Получаем размеры экрана
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.7, // Максимум 70% высоты экрана
            minHeight: 200, // Минимальная высота
          ),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04), // Адаптивные отступы (4% ширины)
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // Учет клавиатуры
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: screenWidth * 0.15, // Адаптивный размер иконки (15% ширины)
                    color: Colors.red,
                  ),
                  SizedBox(height: screenHeight * 0.02), // Адаптивный отступ (2% высоты)
                  Text(
                    "Не удалось подключиться к Bluetooth",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: screenWidth * 0.05, // Адаптивный шрифт (5% ширины)
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    "Проверьте, включён ли Bluetooth и устройство в зоне действия.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: screenWidth * 0.04, // Адаптивный шрифт (4% ширины)
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Адаптивная ширина кнопок
                      final buttonWidth = isLandscape
                          ? constraints.maxWidth * 0.45 // В альбомной ориентации кнопки уже
                          : constraints.maxWidth * 0.9; // В портретной — шире

                      return Wrap(
                        spacing: screenWidth * 0.02, // Отступ между кнопками
                        runSpacing: screenHeight * 0.02, // Отступ между строками
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                try {
                                  await bluethoothService.connectToSavedDevice();
                                  final result = await bluethoothService.isConnected;
                                  if (result == true) {
                                    setState(() {
                                      isConnected = true;
                                    });
                                  } else {
                                    _showBluetoothConnectionFailedModal();
                                  }
                                } on PlatformException catch (e) {
                                  debugPrint("Ошибка подключения: ${e.message}");
                                  _showBluetoothConnectionFailedModal();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.05,
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                              child: Text(
                                "Попробовать снова",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton(
                              onPressed: _openBluetoothSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.05,
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                              child: Text(
                                "Настройки",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[400],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.05,
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                              child: Text(
                                "Отмена",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: screenHeight * 0.02),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _loadFiles() {
    final directory = Directory(dirPath);
    setState(() {
      files = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.xlsx'))
          .toList();
    });
  }

  Future<void> _addFile() async {
    final result = await _showItemNumberDialog(context);

    if (result != null && result.isNotEmpty) {
      final String? itemNumber = result['itemNumber'];
      final comment = result['comment'];
      if(itemNumber != null && itemNumber.isNotEmpty && comment != null && comment.isNotEmpty) {
        final newFile = File('$dirPath/${comment}_$itemNumber.xlsx');
        await excelHelper.createExcelFileWithItemNumber(
            newFile.path, itemNumber, comment);
        _loadFiles();
      }
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    );
  }

  void _openFile(File file) async {
    try {
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось открыть файл: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _shareFile(File file) {
    Share.shareXFiles(
      [XFile(file.path)],
      text: 'Sharing ${file.path.split('/').last}',
    );
  }

  Future<void> _deleteFile(File file) async {
    bool? confirm = await _showDeleteConfirmationDialog(context, file.path.split('/').last);
    if (confirm == true) {
      try {
        await file.delete();
        _loadFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл успешно удален'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении файла: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openScanner(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScannerPage(filePath: file.path),
      ),
    ).then((_) => _loadFiles());
  }

  Future<Map<String, String>?> _showItemNumberDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final TextEditingController commentController = TextEditingController();
    return showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Colors.white,
        title: const Text(
          'Введите Номер Накладной',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 50,
              child: TextField(
                controller: controller,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'Номер Накладной',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                keyboardType: TextInputType.text,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: TextField(
                controller: commentController,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'Комментарий',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                keyboardType: TextInputType.text,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'itemNumber': controller.text,
              'comment': commentController.text,
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ОК', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, String fileName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Подтверждение удаления'),
        content: Text('Вы уверены, что хотите удалить "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Список файлов',
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
      ),
      body: files.isEmpty
          ? Center(
        child: Text(
          'Нет доступных файлов',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(
                  file.path.split('/').last,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => _openScanner(file),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.blueAccent),
                      onPressed: () => _openFile(file) ,
                      tooltip: 'Открыть файд',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.blueAccent),
                      onPressed: () => _shareFile(file),
                      tooltip: 'Поделиться',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteFile(file),
                      tooltip: 'Удалить файл',
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "fab_settings",
              onPressed: _openSettings,
              tooltip: 'Настройки',
              foregroundColor: Colors.white,
              backgroundColor: Colors.blueAccent,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.settings, size: 28),
            ),
            Expanded(child: Container()),
            FloatingActionButton(
              heroTag: 'fab_file',
              onPressed: _addFile,
              child: const Icon(Icons.add, size: 28),
              tooltip: 'Добавить файл',
              foregroundColor: Colors.white,
              backgroundColor: Colors.blueAccent,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            )
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}