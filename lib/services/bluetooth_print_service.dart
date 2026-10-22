
// Conditional Import
// If dart.library.io is available (Mobile/Desktop), use mobile implementation
// If dart.library.html is available (Web), use web implementation

import 'bluetooth_print_service_web.dart' if (dart.library.io) 'bluetooth_print_service_mobile.dart';

export 'bluetooth_print_service_web.dart' if (dart.library.io) 'bluetooth_print_service_mobile.dart';
