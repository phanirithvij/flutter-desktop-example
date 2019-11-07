// A Wallpaper cli app in dart
// Uses dart:ffi requires dart>=2.5.0

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'utils.dart' show downloadFile;

/// MAX_PATH for a filename
// ignore: constant_identifier_names
const MAX_PATH = 1000;

Future<int> main(List args) async {
  if (args.length == 1) {
    final file = p.canonicalize(args[0]);
    final exists =
        FileSystemEntity.typeSync(file) != FileSystemEntityType.notFound;

    if (exists && !setWallpaper(file)) {
      print('Failed to set wallpaper');
      return -1;
    }
    print('Not a file');
    // url
    final directory = await Directory.systemTemp.createTemp('my_temp_dir');
    final path = directory.path;

    await downloadFile(args[0], '$path/temp.png').whenComplete(() {
      setWallpaper(p.canonicalize('$path/temp.png'));
    });
    return 0;
  }
  print(getWallpaper());
  return 0;
}

/// [Utf16] Helper class to decode and encode String to Utf16 and back
/// [ffi_examples](https://github.com/dart-lang/samples/blob/master/ffi/structs/structs.dart#L9)
///
extension Utf16String on Pointer<Utf16> {
  /// Get a [String] from a [Pointer<Utf16>] object
  /// [details](https://github.com/dart-lang/ffi/issues/21#issuecomment-550336125)
  String fromUtf16() {
    final units = <int>[];
    var len = 0;
    // ignore: literal_only_boolean_expressions
    while (true) {
      final char = cast<Int16>().elementAt(len++).value;
      if (char == 0 || len > MAX_PATH) {
        break;
      }
      units.add(char);
    }
    return String.fromCharCodes(units);
  }
}

/*
BOOL SystemParametersInfoW(
  UINT  uiAction,
  UINT  uiParam,
  PVOID pvParam,
  UINT  fWinIni
);

https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow
https://github.com/sindresorhus/win-wallpaper/blob/master/wallpaper.c

*/

typedef SystemParametersInfoWC = Int8 Function(
    Uint32 uiAction, Uint32 uiParam, Pointer pvParam, Uint32 fWinIni);
typedef SystemParametersInfoWDart = int Function(
    int uiAction, int uiParam, Pointer pvParam, int fWinIni);

/// Get the wallpaper path
String getWallpaper() {
  // Load user32.dll.
  final dylib = DynamicLibrary.open('user32.dll');

  // Look up the function.
  final systemParWP =
      dylib.lookupFunction<SystemParametersInfoWC, SystemParametersInfoWDart>(
          'SystemParametersInfoW');

  // Allocate pointers to Utf16 arrays containing the command arguments.
  final filenameP = Utf16.toUtf16('0' * MAX_PATH);

  // ignore: constant_identifier_names
  const SPI_GETDESKWALLPAPER = 0x0073;
  // Invoke the command, and free the pointers.
  systemParWP(SPI_GETDESKWALLPAPER, MAX_PATH, filenameP, 0);
  final wall = filenameP.fromUtf16();
  free(filenameP);

  return wall;
}

/// Sets the given filename as the wallpaper
bool setWallpaper(String filename) {
  // Load user32.dll.
  final dylib = DynamicLibrary.open('user32.dll');

  // Look up the function.
  final systemParWP =
      dylib.lookupFunction<SystemParametersInfoWC, SystemParametersInfoWDart>(
          'SystemParametersInfoW');

  // http://pinvoke.net/default.aspx/Enums/SPIF.html

// ignore: constant_identifier_names
  const SPI_SETDESKWALLPAPER = 0x0014;
// ignore: constant_identifier_names
  const SPIF_UPDATEINIFILE = 0x01;
// ignore: constant_identifier_names
  const SPIF_SENDCHANGE = 0x02;

  // Allocate pointers to Utf16 arrays containing the command arguments.
  final filenameP = Utf16.toUtf16(filename);

  // Invoke the command, and free the pointers.
  final result = systemParWP(
      SPI_SETDESKWALLPAPER, 0, filenameP, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);

  free(filenameP);
  return result > 0;
}
