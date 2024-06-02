import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'gpt_api.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:device_calendar/device_calendar.dart';

void main() {
  tz.initializeTimeZones();
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
  DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  Calendar? _defaultCalendar;

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

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data!.isNotEmpty) {
      setState(() {
        _defaultCalendar = calendarsResult.data!.elementAt(1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_defaultCalendar!.name ?? "heelo")),
      );
    }
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
      //String transcription = await _transcribeFile(file);
      String transcription = '''
      안녕하세요 우진씨,잘 지내셨나요? 안녕하세요 교수님, 잘 지내고 있었어요. 교수님은 잘 지내셨어요? 네, 저도 잘지냈죠. 요즘 날씨가 좋아서 기분이 좋더라고요. 맞아요, 요즘 날씨 진짜 좋죠. 주말에 뭐 하셨어요? 저는 가족들이랑 공원에 산책다녀왔어요. 우진씨는요? 저는 친구들이랑 무등산 등산 같이 갔다 왔어요. 오랜만에 산 오르니까 상쾌하고 좋더라고요. 아, 좋으셨겠어요. 전화드린 거는 다름이 아니라 이번에 새로운 인공지능 연구 프로젝트 예산에 대해서 문의하고 싶어서요. 아,네. 혹시 필요하신 부분 있으신가요? 일단은 하드웨어 업그레이드랑 소프트웨어 라이선스, 데이터 획득, 그리고 추가 연구원 고용에 대해서 예산을 할당을 해야 돼요. 아, 네네. 혹시 구체적인 금액을 좀 알려주실 수 있을까요? 저희 하드웨어 업그레이드에는 2000만원 정도 들고, 소프트웨어 라이선스에는 500만뭔, 데이터 수집에는 300만원, 그리고 추가 연구원 고용에는한 1억 정도 필요할 것 같아요. 아,감사합니다. 그럼 제가 재무팀과 공투해보고 어떻게 지원할 수 있는지 알아볼게요. 또 필요하신거 있으실까요? 아, 그 예기치 많은 비용에 대해서 대비한 추가 자금이 있는지 궁금해요. 보통비상자금을 마련해두긴 해요. 확인해보고 한번 자세한 내용 알려드릴게요.아,알겠습니다. 아, 그리고 예산조율 관련해서힌번 더 자세히 논의할 수 있게 미팅을 한번 하면 좋을 것 같아요. 아, 네네. 미팅 일정은 언제가 편하신가요? 이번 주금요일 오후 2시는 어떨까요? 아,네.가능할 것 같습니다. 2시에 뵈요.아, 네. 좋습니다. 아, 죄송해요 교수님, 제가 금요일 오후 2시에 이미 다른 일정이 있네요. 혹시 다른 시간 어떠세요? 아, 그렇군요. 그러면 금요일 오전10시는 어떨까요? 금요일오전10시... 아, 네. 그 시간은 괜찮네요. 캘린더에 기록해두겠습니다. 필요한 자료 있으면 미리 보내주시면 감사하겠습니다.
      ''';

      setState(() {
        _transcription = transcription;
      });
      // GPT API 호출하여 일정 정보 추출
      String schedules = await _extractSchedules(transcription);
      setState(() {
        _schedules = schedules;
      });

      List<dynamic> schedulesList = json.decode(schedules);
      for (var schedule in schedulesList) {
        await _addScheduleToCalendar(schedule);
      }
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
    final now = tz.TZDateTime.now(tz.local);
    final formatter = DateFormat('yyyy-MM-dd');
    final strToday = formatter.format(now);

    var request = http.Request('POST', Uri.parse('https://api.openai.com/v1/chat/completions'));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({
      "model": "gpt-3.5-turbo",
      "messages": [
        {
          "role": "system",
          "content": [
            {
              "text": "You are an assistant that extracts and organizes schedule information from a given text. Make sure to accurately handle changes in schedules and convert relative dates to absolute dates based on today's date. Today's date: ${strToday}",
              "type": "text"
            }
          ]
        },
        {
          "role": "user",
          "content": [
            {
              "text": "여보세요? \n네 여보세요? \n안녕하세요 김교수님 지스트 학사팀 김철수입니다.\n네 안녕하세요\n다름이 아니라 이번주 금요일 오전 10시에 총장님과 긴급 미팅을 하려고 하는데 가능하신가요?\n아 네 알겠습니다. 금요일에 뵙겠습니다.\n아! 잠시만요 제가 금요일 오전에 다른 미팅이 있어서 혹시 토요일 오전 11시에 미팅가능할까요?\n아 네 알겠습니다. \n감사합니다.",
              "type": "text"
            }
          ]
        },
        {
          "role": "assistant",
          "content": [
            {
              "text": "[{\"date\": \"2024-06-01\",\n\"time\": \"11:00\",\n\"location\": \"\",\n\"participants\": \"김철수, 총장님\",\n\"contact_info\": \"\",\n\"task\": \"긴급 미팅\"\n}]",
              "type": "text"
            }
          ]
        },
        {
          "role": "user",
          "content": [
            {
              "text": "abc@gist.ac.kr to xyz@gist.ac.kr\n손영희 교수님께.안녕하세요 교수님. GIST 대학 21학번 권철수입니다.G-SURF 문의 메일에 답장이 없으시길래 혹시 바쁘셔서 못 보셨을까 다시 메일 보내드립니다.올해 여름방학에 G-SURF 진행 불가능하시더라도 답장 주시면 정말 감사하겠습니다.전기전자컴퓨터공학부 21학번 권철수 드림.\n\n안녕하세요 권철수 학생,답이 늦어서 미안해요.혹시 관련하여 잠깐 미팅이 가능할까요?급하지 않으면 내일 오전에 미팅을 하면 좋을 것 같은데요 (10시정도?)오피스로 와도 되고, 온라인 미팅도 가능해요https://us06web.zoom.us/abcxyz 손영희 드림\n\n손영희 교수님께.제가 이번주 목요일부터 일요일까지 본가에 와 있어서 온라인 미팅으로 뵈어야 할 것 같습니다.내일 오전 10시에 보내주신 링크로 접속하겠습니다.감사합니다.전기전자컴퓨터공학부 21학번 권철수 드림.",
              "type": "text"
            }
          ]
        },
        {
          "role": "assistant",
          "content": [
            {
              "text": "[{\n\"date\": \"2024-05-31\",\n\"time\": \"10:00\",\n\"location\": \"https://us06web.zoom.us/abcxyz\",\n\"participants\": \"권철수, 손영희\",\n\"contact_info\": [\"abc@gist.ac.kr\", \"xyz@gist.ac.kr\"],\n\"task\": \"G-SURF 관련 미팅\"\n}]",
              "type": "text"
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
      "max_tokens": 1024
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


  Future<void> _addScheduleToCalendar(Map<String, dynamic> schedule) async {
    if (_defaultCalendar == null) {
      return;
    }

    final location = tz.getLocation('Asia/Seoul'); // 타임존 설정

    final TZDateTime startDateTime = tz.TZDateTime.from(
      DateTime.parse(schedule['date'] + ' ' + schedule['time']),
      location,
    );
    final TZDateTime endDateTime = startDateTime.add(Duration(hours: 1));

    final Event event = Event(
      _defaultCalendar!.id,
      title: schedule['task'],
      description: schedule['participants'],
      start: startDateTime,
      end: endDateTime,
      location: schedule['location'],
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
    if (result?.isSuccess != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 추가에 실패했습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정이 성공적으로 추가되었습니다.')),
      );
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