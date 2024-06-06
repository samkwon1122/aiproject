import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'gpt_api.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:device_calendar/device_calendar.dart';
import 'dart:io';

void main() {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VoiceToTextScreen(),
      theme: ThemeData(scaffoldBackgroundColor: Colors.green[50])
    );
  }
}

class VoiceToTextScreen extends StatefulWidget {
  @override
  _VoiceToTextScreenState createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends State<VoiceToTextScreen> {
  List<String> _summaries = []; // 추가된 일정 요약
  DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  Calendar? _defaultCalendar; // 확정된 일정 추가하는 캘린더
  Calendar? _undecidedCalendar; // 미확정 일정 추가하는 캘린더

  @override
  void initState() {
    super.initState();
    _retrieveCalendars();
  }

  Future<void> _retrieveCalendars() async {
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('캘린더 접근 권한이 필요합니다.')),
        );
        return;
      }
    }

    // 캘린더 있는지 확인하고 없으면 새로 생성
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data!.isNotEmpty) {
      var planACalendar = calendarsResult.data!.firstWhere(
        (calendar) => calendar.name == 'Plan-A',
        orElse: () => Calendar(id: ''),
      );
      if (planACalendar.name == 'Plan-A' ) {
        setState(() {
          _defaultCalendar = calendarsResult.data!.firstWhere((calendar) => calendar.name == 'Plan-A');
        });
      }
      else {
        await _deviceCalendarPlugin.createCalendar('Plan-A', calendarColor: Color(0xFF105625));
        setState(() {
          _defaultCalendar = calendarsResult.data!.firstWhere((calendar) => calendar.name == 'Plan-A');
        });
      }
      var planBCalendar = calendarsResult.data!.firstWhere(
            (calendar) => calendar.name == 'Plan-A (미확정)',
        orElse: () => Calendar(id: ''),
      );
      if (planBCalendar.name == 'Plan-A (미확정)' ) {
        setState(() {
          _undecidedCalendar = calendarsResult.data!.firstWhere((calendar) => calendar.name == 'Plan-A (미확정)');
        });
      }
      else {
        await _deviceCalendarPlugin.createCalendar('Plan-A (미확정)', calendarColor: Colors.red);
        setState(() {
          _undecidedCalendar = calendarsResult.data!.firstWhere((calendar) => calendar.name == 'Plan-A');
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.audio.status;
    await Permission.mediaLibrary.request();
    if (!status.isGranted) {
      if (await Permission.audio.request().isGranted || await Permission.mediaLibrary.request().isGranted) {
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
    // 통화 녹음 경로
    Directory recordDir = await Directory('/storage/emulated/0/Call');
    List<FileSystemEntity> files = recordDir.listSync();

    DateTime today = DateTime.now();
    DateTime startOfToday = DateTime(today.year, today.month, today.day);
    DateTime endOfToday = DateTime(today.year, today.month, today.day + 1).subtract(Duration(seconds: 1));

    for (var file in files) {
      if (file is File) {
        DateTime modificationDate = file.lastModifiedSync();

        // 오늘자 음성 파일 선택
        if (modificationDate.isAfter(startOfToday) && modificationDate.isBefore(endOfToday)) {
          String selectedFile = file.path;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(selectedFile.split('/').last), duration: Duration(seconds: 2)),
          );

          // OpenAI Whisper API 호출
          String transcription = await _transcribeFile(selectedFile);
          if (transcription == "") {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("파일 변환에 실패했습니다.")));
            continue;
          }

          // GPT API 호출하여 일정 정보 추출
          String schedules = await _extractSchedules(transcription);
          if (schedules == "") {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("일정 추출에 실패했습니다.")));
            continue;
          }

          // 캘린더에 일정 추가
          List<dynamic> schedulesList = json.decode(schedules);
          for (var schedule in schedulesList) {
            await _addScheduleToCalendar(schedule);
          }
        }
      }
    }
  }

  // OpenAI Whisper API 호출
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
      //print('Failed to transcribe file: ${responseBody.statusCode}');
      //print('Response body: ${responseBody.body}');
      return "";
    }
  }

  // GPT API 호출하여 일정 정보 추출
  Future<String> _extractSchedules(String text) async {
    String apiKey = gptApi;
    final now = tz.TZDateTime.now(tz.local);
    final formatter = DateFormat('yyyy-MM-dd');
    final strToday = formatter.format(now);

    var request = http.Request('POST', Uri.parse('https://api.openai.com/v1/chat/completions'));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({
      "model": "gpt-4o",
      "messages": [
        {
          "role": "system",
          "content": [
            {
              "type": "text",
              "text": "You are an assistant that extracts and organizes schedule information from a given text. Make sure to accurately handle changes in schedules and convert relative dates to absolute dates based on today's date. Today's date: ${strToday}. Time format should always be HH:MM. If the schedule is not decided, mark the \"decided\" with \"0\"."
            }
          ]
        },
        {
          "role": "user",
          "content": [
            {
              "text": "여보세요? \n네 여보세요? \n안녕하세요 김교수님 지스트 학사팀 김명진입니다.\n네 안녕하세요\n다름이 아니라 이번주 금요일 오전 10시에 총장님과 긴급 미팅을 하려고 하는데 가능하신가요?\n아 네 알겠습니다. 금요일에 뵙겠습니다.\n아! 잠시만요 제가 금요일 오전에 다른 미팅이 있어서 혹시 토요일 오전 11시에 미팅가능할까요?\n아 네 알겠습니다. \n감사합니다.",
              "type": "text"
            }
          ]
        },
        {
          "role": "assistant",
          "content": [
            {
              "type": "text",
              "text": "[{\n\"date\": \"2024-06-07\",\n\"time\": \"11:00\",\n\"location\": null,\n\"participants\": \"김명진, 총장님\",\n\"contact_info\": null,\n\"task\": \"긴급 미팅\",\n\"decided\": \"1\"\n}]"
            }
          ]
        },
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "안녕하세요 교수님 저희 AI 실무 프로젝트 수업 회식하려고 하는데요 시간 언제가 괜찮으세요? 아 네 영희씨 저는 다음주 이번주 금요일 6시나 다음주 월요일 5시에 가능할 것 같습니다. 일단 알겠습니다 저희도 일정 확인해보고 다음에 다시 연락드리겠습니다. 장소는 어디가 좋을까요? 그냥 가볍게 락락 어떠신가요? 좋습니다."
            }
          ]
        },
        {
          "role": "assistant",
          "content": [
            {
              "type": "text",
              "text": "[{\n\"date\": \"2024-06-07\",\n\"time\": \"18:00\",\n\"location\": \"락락\",\n\"participants\": \"교수님, 영희씨\",\n\"contact_info\": null,\n\"task\": \"AI 실무 프로젝트 수업 회식\",\n\"decided\": \"0\"\n},\n{\n\"date\": \"2024-06-10\",\n\"time\": \"17:00\",\n\"location\": \"락락\",\n\"participants\": [\"교수님, 영희씨\"],\n\"contact_info\": null,\n\"task\": \"AI 실무 프로젝트 수업 회식\",\n\"decided\": \"0\"\n}]"
            }
          ]
        },
        {
          "role": "user",
          "content": [
            {
              "text": "${text}",
              "type": "text"
            }
          ]
        }
      ],
      "temperature": 0.5,
      "max_tokens": 256
    });

    var response = await request.send();
    var responseBody = await http.Response.fromStream(response);

    if (responseBody.statusCode == 200) {
      var responseData = json.decode(utf8.decode(responseBody.bodyBytes));
      return responseData['choices'][0]['message']['content'];
    } else {
      //print('Failed to extract schedules: ${responseBody.statusCode}');
      //print('Response body: ${responseBody.body}');
      return "";
    }
  }

  // 캘린더에 일정 추가
  Future<void> _addScheduleToCalendar(Map<String, dynamic> schedule) async {
    if (_defaultCalendar == null || _undecidedCalendar == null) {
      return;
    }

    Event event;

    final location = tz.getLocation('Asia/Seoul'); // 타임존 설정

    final TZDateTime startDateTime = tz.TZDateTime.from(
      DateTime.parse(schedule['date'] + ' ' + schedule['time']),
      location,
    );

    final TZDateTime endDateTime = startDateTime.add(Duration(hours: 1));

    if (schedule['decided'] == "1") { // 확정된 일정인 경우
      event = Event(
        _defaultCalendar!.id,
        title: schedule['task'],
        description: schedule['participants'],
        start: startDateTime,
        end: endDateTime,
        location: schedule['location'],
        reminders: [Reminder(minutes: 30)],
        status: EventStatus.Confirmed,
      );
      setState(() {
        _summaries.add("일정: ${schedule['task']}\n시간: ${schedule['date']} ${schedule['time']}\n참여자: ${schedule['participants']}");
      });
    } else {
      event = Event( // 미확정 일정인 경우
        _undecidedCalendar!.id,
        title: schedule['task'] + " (미확정)",
        description: schedule['participants'],
        start: startDateTime,
        end: endDateTime,
        location: schedule['location'],
        reminders: [Reminder(minutes: 30)],
        status: EventStatus.Tentative,
      );
      setState(() {
        _summaries.add("일정: ${schedule['task']} (미확정)\n시간: ${schedule['date']} ${schedule['time']}\n참여자: ${schedule['participants']}");
      });
    }

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
    if (result?.isSuccess != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 추가에 실패했습니다.'), duration: Duration(seconds: 2)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정이 성공적으로 추가되었습니다.'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plan-A'),
        backgroundColor: Color(0xFFA0CFA0),
      ),
      body: Container(
        color: Colors.green[50], // 배경 색상 설정
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/logo.png', height: 200), // 로고 이미지 추가
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _requestPermissions,
                child: Text('실행'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Color(0xFF105625),
                  textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 20),
              Text(
                '추가된 일정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _summaries.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _summaries[index],
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}