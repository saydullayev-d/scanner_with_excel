import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:scanner_with_excel/services/excel_helper.dart';
import 'package:scanner_with_excel/pages/scanner_page.dart';
import 'package:intl/intl.dart'; // For date formatting

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File List App',
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

  @override
  void initState() {
    super.initState();
    excelHelper = ExcelHelper();
    _loadFiles();
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
    final itemNumber = await _showItemNumberDialog(context);
    if (itemNumber != null && itemNumber.isNotEmpty) {
      final currentDate = DateFormat('yyyyMMdd').format(DateTime.now());
      final newFile = File('$dirPath/накладная_${itemNumber}.xlsx');
      await excelHelper.createExcelFileWithItemNumber(newFile.path, itemNumber);
      _loadFiles();
    }
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

  Future<String?> _showItemNumberDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Введите Номер Накладной',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Номер Накладной',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey[200],
          ),
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
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
                onTap: () => _openFile(file),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_outlined, color: Colors.blueAccent),
                      onPressed: () => _openScanner(file),
                      tooltip: 'Открыть сканер',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addFile,
        child: const Icon(Icons.add, size: 28),
        tooltip: 'Добавить файл',
        foregroundColor: Colors.white,
        backgroundColor: Colors.blueAccent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}