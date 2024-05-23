import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'gpt_api.dart';

void main() => runApp(SpeechFileApp());

class SpeechFileApp extends StatefulWidget {
  @override
  _SpeechFileAppState createState() => _SpeechFileAppState();
}

class _SpeechFileAppState extends State<SpeechFileApp> {
  String _transcription = "Transcription will appear here";
  final String _apiKey = gptApi; // OpenAI Whisper API 키

  @override
  void initState() {
    super.initState();
    _requestPermissions().then((granted) {
      if (granted) {
        _transcribeStoredFile();
      } else {
        setState(() {
          _transcription = "Permissions not granted.";
        });
      }
    });
  }

  Future<bool> _requestPermissions() async {
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    return false;
  }

  Future<void> _transcribeStoredFile() async {
    try {
      Directory? appDocDir = await getDownloadsDirectory();
      if (appDocDir == null) {
        setState(() {
          _transcription = "External storage not available.";
        });
        return;
      }
      String recordingsDirPath = path.join(appDocDir.path, '');

      Directory recordingsDir = Directory(recordingsDirPath);
      List<FileSystemEntity> files = recordingsDir.listSync();

      FileSystemEntity? recentFile;
      DateTime recentModified = DateTime.fromMillisecondsSinceEpoch(0);
      for (var file in files) {
        if (file is File) {
          DateTime fileModified = await file.lastModified();
          if (fileModified.isAfter(recentModified)) {
            recentModified = fileModified;
            recentFile = file;
          }
        }
      }

      if (recentFile == null) {
        setState(() {
          _transcription = "No audio files found in the directory.";
        });
        return;
      }

      var audioBytes = File(recentFile.path).readAsBytesSync();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.files.add(http.MultipartFile.fromBytes('file', audioBytes, filename: path.basename(recentFile.path)));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseBody);

        setState(() {
          _transcription = jsonResponse['text'];
        });
      } else {
        setState(() {
          _transcription = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _transcription = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Speech to Text from File'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(_transcription),
            ],
          ),
        ),
      ),
    );
  }
}
