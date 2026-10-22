import 'package:flutter/material.dart';

class ShellState extends ChangeNotifier {
  String _title = 'Dashboard';
  List<Widget> _actions = [];
  Widget? _leading;

  String get title => _title;
  List<Widget> get actions => _actions;
  Widget? get leading => _leading;

  void update({required String title, List<Widget> actions = const [], Widget? leading}) {
    _title = title;
    _actions = actions;
    _leading = leading;
    notifyListeners();
  }

  void reset(String defaultTitle) {
    _title = defaultTitle;
    _actions = [];
    _leading = null;
    notifyListeners();
  }
}
