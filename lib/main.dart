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
  String _schedules = '';

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
      // GPT API 호출하여 일정 정보 추출
      String schedules = await _extractSchedules(transcription);
      setState(() {
        _schedules = schedules;
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

  Future<String> _extractSchedules(String text) async {
    String apiKey = gptApi;
    var request = http.Request('POST', Uri.parse('https://api.openai.com/v1/chat/completions'));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {
          'role': 'system',
          'content': 'You are an assistant that extracts and organizes schedule information from a given text. Make sure to accurately handle changes in schedules and convert relative dates to absolute dates based on today\'s date.'
        },
        {
          'role': 'user',
          'content': '''다음 텍스트에서 일정 정보를 추출하고, 각 일정을 시간, 날짜, 할일로 정리해 주세요. 일정이 여러 개인 경우 각각을 분리해 주세요. 또한, 대화 도중 일정이 변경된 경우 이전 일정은 폐기하고 변경된 일정에 대해 정확히 정리해 주세요. 상대적 날짜 표현(예: "내일", "다음 주 월요일")은 오늘 날짜를 기준으로 계산하여 정확히 숫자로 나타내 주세요.

텍스트:
$text

결과는 다음 형식으로 출력해 주세요:
[
  {
    "time": "시간",
    "date": "YYYY-MM-DD",
    "task": "할일"
  },
  ...
]'''
        }
      ],
      'max_tokens': 1024,
      'temperature': 0.5,
    });

    var response = await request.send();
    var responseBody = await http.Response.fromStream(response);

    if (responseBody.statusCode == 200) {
      var responseData = json.decode(utf8.decode(responseBody.bodyBytes));
      return responseData['choices'][0]['message']['content'];
    } else {
      print('Failed to extract schedules: ${responseBody.statusCode}');
      print('Response body: ${responseBody.body}');
      return 'api 호출에 실패하였습니다.';
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              SizedBox(height: 20),
              Text(
                '추출된 일정:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(_schedules),
              SizedBox(height: 20)
            ],
          ),
        ),
      ),
    );
  }
}