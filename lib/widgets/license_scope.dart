import '../models/license_model.dart';
import 'package:flutter/material.dart';

class LicenseScope extends InheritedWidget {
  final bool isReadOnly;
  final LicenseModel? license;

  const LicenseScope({
    super.key,
    required this.isReadOnly,
    this.license,
    required super.child,
  });

  static LicenseScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LicenseScope>();
  }

  static bool isReadOnlyMode(BuildContext context) {
    return of(context)?.isReadOnly ?? false; 
  }

  static LicenseModel? licenseOf(BuildContext context) {
    return of(context)?.license;
  }

  @override
  bool updateShouldNotify(LicenseScope oldWidget) {
    return isReadOnly != oldWidget.isReadOnly || license != oldWidget.license;
  }
}
