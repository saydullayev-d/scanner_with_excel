import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheckboxState extends ChangeNotifier {
  bool _isChecked = false;

  CheckboxState() {
    _loadState();
  }

  bool get isChecked => _isChecked;

  void setChecked(bool value) async {
    _isChecked = value;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isChecked', value);
  }

  void _loadState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isChecked = prefs.getBool('isChecked') ?? false;
    notifyListeners();
  }
}