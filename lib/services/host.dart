import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

@visibleForTesting
bool? debugOnAndroid;

bool get onAndroid => debugOnAndroid ?? (!kIsWeb && Platform.isAndroid);

bool get onIOS => !kIsWeb && Platform.isIOS;

bool get onMobile => onAndroid || onIOS;
