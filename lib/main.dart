import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterDownloader.initialize(
    debug: true,
    ignoreSsl: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Fetcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DownloadHomeScreen(),
    );
  }
}

class VideoQualityOption {
  final String quality;
  final String downloadUrl;

  VideoQualityOption({required this.quality, required this.downloadUrl});
}

class DownloadHomeScreen extends StatefulWidget {
  const DownloadHomeScreen({super.key});

  @override
  State<DownloadHomeScreen> createState() => _DownloadHomeScreenState();
}

class _DownloadHomeScreenState extends State<DownloadHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ReceivePort _port = ReceivePort();

  List<VideoQualityOption> _availableQualities = [];
  VideoQualityOption? _selectedQuality;

  bool _isFetchingQualities = false;
  String? _taskId;
  int _progress = 0;
  DownloadTaskStatus _status = DownloadTaskStatus.undefined;

  @override
  void initState() {
    super.initState();
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
    _requestPermissions();
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    _urlController.dispose();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }

    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      int progress = data[2];

      setState(() {
        if (_taskId == null || _taskId == id) {
          _status = status;
          _progress = progress;
        }
      });
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await Permission.storage.request();
  }

  Future<void> _fetchVideoQualities() async {
    final inputUrl = _urlController.text.trim();
    if (inputUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya ek valid URL enter karein')),
      );
      return;
    }

    setState(() {
      _isFetchingQualities = true;
      _availableQualities = [];
      _selectedQuality = null;
    });

    try {
      final yt = YoutubeExplode();
      VideoId? videoId;
      
      try {
        videoId = VideoId(inputUrl);
      } catch (_) {
        videoId = null;
      }

      if (videoId != null) {
        var manifest = await yt.videos.streamsClient.getManifest(videoId);
        var muxedStreams = manifest.muxed.sortByBitrate();

        List<VideoQualityOption> parsed = [];
        for (var stream in muxedStreams) {
          parsed.add(VideoQualityOption(
            quality: '${stream.qualityLabel} (${stream.container.name.toUpperCase()})',
            downloadUrl: stream.url.toString(),
          ));
        }
        setState(() {
          _availableQualities = parsed;
        });
      } else if (inputUrl.endsWith('.m3u8')) {
        final response = await http.get(Uri.parse(inputUrl));
        if (response.statusCode == 200) {
          final lines = response.body.split('\n');
          List<VideoQualityOption> parsed = [];

          for (int i = 0; i < lines.length; i++) {
            if (lines[i].contains('RESOLUTION=')) {
              final resMatch =
                  RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(lines[i]);
              String resolutionLabel =
                  resMatch != null ? '${resMatch.group(1)}p' : 'Unknown Quality';

              if (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty) {
                String streamUrl = lines[i + 1].trim();
                if (!streamUrl.startsWith('http')) {
                  final baseUri = Uri.parse(inputUrl);
                  streamUrl = baseUri.resolve(streamUrl).toString();
                }
                parsed.add(VideoQualityOption(
                  quality: resolutionLabel,
                  downloadUrl: streamUrl,
                ));
              }
            }
          }
          setState(() {
            _availableQualities = parsed;
          });
        }
      }

      yt.close();

      if (_availableQualities.isEmpty) {
        setState(() {
          _availableQualities = [
            VideoQualityOption(quality: '1080p (HD)', downloadUrl: inputUrl),
            VideoQualityOption(quality: '720p (HD)', downloadUrl: inputUrl),
            VideoQualityOption(quality: '480p (SD)', downloadUrl: inputUrl),
            VideoQualityOption(quality: '360p (Low)', downloadUrl: inputUrl),
          ];
        });
      }

      if (_availableQualities.isNotEmpty) {
        setState(() {
          _selectedQuality = _availableQualities.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching qualities: $e')),
      );
    } finally {
      setState(() {
        _isFetchingQualities = false;
      });
    }
  }

  Future<void> _startDownload() async {
    if (_selectedQuality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle quality select karein')),
      );
      return;
    }

    final dir = await getExternalStorageDirectory();
    if (dir == null) return;

    final fileName =
        'video_${_selectedQuality!.quality.replaceAll(RegExp(r'[^\w\s]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final taskId = await FlutterDownloader.enqueue(
      url: _selectedQuality!.downloadUrl,
      savedDir: dir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );

    setState(() {
      _taskId = taskId;
      _status = DownloadTaskStatus.enqueued;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Fetcher'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Image.asset(
              'x.png',
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  '⚠️ x.png root directory me nahi mili.',
                  style: TextStyle(color: Colors.red),
                );
              },
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'YouTube Link / .mp4 / .m3u8 URL',
                border: OutlineInputBorder(),
                hintText: 'Paste link here...',
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isFetchingQualities ? null : _fetchVideoQualities,
              icon: _isFetchingQualities
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Fetch Qualities'),
            ),

            const SizedBox(height: 20),

            if (_availableQualities.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Download Quality:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: _availableQualities.map((item) {
                  return RadioListTile<VideoQualityOption>(
                    title: Text(item.quality),
                    value: item,
                    groupValue: _selectedQuality,
                    onChanged: (VideoQualityOption? val) {
                      setState(() {
                        _selectedQuality = val;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: Text('Download (${_selectedQuality?.quality ?? ''})'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],

            const SizedBox(height: 25),

            if (_taskId != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Status: ${_status.toString().replaceAll('DownloadTaskStatus.', '')}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      _progress == 0 && _status == DownloadTaskStatus.running
                          ? const LinearProgressIndicator()
                          : LinearProgressIndicator(value: _progress / 100),
                      const SizedBox(height: 10),
                      Text(_progress == 0 && _status == DownloadTaskStatus.running
                          ? 'Downloading...'
                          : '$_progress %'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}