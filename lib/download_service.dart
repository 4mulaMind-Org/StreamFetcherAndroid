import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class DownloadService {
  static Future<void> downloadStream(String inputUrl) async {
    // 1. Storage Permission Check karein
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    String downloadUrl = inputUrl;

    // 2. Agar YouTube link hai toh YoutubeExplode se real stream URL nikalein
    if (inputUrl.contains('youtube.com') || inputUrl.contains('youtu.be')) {
      final yt = YoutubeExplode();
      try {
        print("Extracting YouTube stream...");
        var manifest = await yt.videos.streamsClient.getManifest(inputUrl);
        var streamInfo = manifest.muxed.withHighestQuality();
        downloadUrl = streamInfo.url.toString();
      } catch (e) {
        print("Error parsing YouTube link: $e");
        yt.close();
        rethrow;
      }
      yt.close();
    }

    // 3. Download directory set karein (Phone ke Download folder mein save hoga)
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final savedDir = directory?.path ?? '';

    // 4. Download start karein
    await FlutterDownloader.enqueue(
      url: downloadUrl,
      savedDir: savedDir,
      showNotification: true,
      openFileFromNotification: true,
    );
    
    print("Download enqueued to: $savedDir");
  }
}