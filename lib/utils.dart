import 'dart:io';

/// Downloads a file to a specified path
Future downloadFile(String url, String filename) async {
  await HttpClient()
      .getUrl(Uri.parse(url))
      .then((request) => request.close())
      .then((response) => response.pipe(File(filename).openWrite()));
}
