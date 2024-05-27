import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'gpt_api.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VoiceToTextScreen(),
    );
  }
}

class VoiceToTextScreen extends StatefulWidget {
  @override
  _VoiceToTextScreenState createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends State<VoiceToTextScreen> {
  String _transcription = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.audio.status;
    if (!status.isGranted) {
      if (await Permission.audio.request().isGranted) {
        // 권한이 허용됨
        _pickFileAndTranscribe();
      } else {
        // 권한이 거부됨
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 접근 권한이 필요합니다.')),
        );
      }
    } else {
      // 이미 권한이 허용됨
      _pickFileAndTranscribe();
    }
  }

  Future<void> _pickFileAndTranscribe() async {
    // 파일 선택
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String file = result.files.single.path!;
      // OpenAI Whisper API 호출
      String transcription = await _transcribeFile(file);
      setState(() {
        _transcription = transcription;
      });
    }
  }

  Future<String> _transcribeFile(String filePath) async {
    String apiKey = gptApi;
    var request = http.MultipartRequest('POST', Uri.parse('https://api.openai.com/v1/audio/transcriptions'));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['model'] = 'whisper-1';

    var response = await request.send();
    var responseBody = await http.Response.fromStream(response);

    if (responseBody.statusCode == 200) {
      var responseData = json.decode(utf8.decode(responseBody.bodyBytes));
      return responseData['text'];
    } else {
      print('Failed to transcribe file: ${responseBody.statusCode}');
      print('Response body: ${responseBody.body}');
      return '파일 변환에 실패했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('음성 파일 텍스트 변환'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _requestPermissions,
              child: Text('파일 선택 및 변환'),
            ),
            SizedBox(height: 20),
            Text(
              '변환된 텍스트:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(_transcription),
          ],
        ),
      ),
    );
  }
}
