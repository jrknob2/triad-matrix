import 'package:flutter/foundation.dart';

const bool kEnableDevTools = bool.fromEnvironment('ENABLE_DEV_TOOLS');

bool get mockScenariosEnabled => kDebugMode || kEnableDevTools;
