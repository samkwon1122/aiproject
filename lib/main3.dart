import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Calendar Event Adder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _eventTitleController = TextEditingController();
  final _eventDescriptionController = TextEditingController();
  DateTime _eventStartTime = DateTime.now();
  DateTime _eventEndTime = DateTime.now().add(Duration(hours: 1));
  GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      calendar.CalendarApi.calendarScope,
    ],
  );

  Future<void> _addEventToGoogleCalendar() async {
    final authHeaders = await _googleSignIn.currentUser!.authHeaders;
    final authenticateClient = GoogleHttpClient(authHeaders);
    final calendarApi = calendar.CalendarApi(authenticateClient);

    var event = calendar.Event()
      ..summary = _eventTitleController.text
      ..description = _eventDescriptionController.text
      ..start = (calendar.EventDateTime()
        ..dateTime = _eventStartTime
        ..timeZone = "GMT+00:00")
      ..end = (calendar.EventDateTime()
        ..dateTime = _eventEndTime
        ..timeZone = "GMT+00:00");

    try {
      await calendarApi.events.insert(event, "primary");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Event added to Google Calendar")));
    } catch (e) {
      print("Error creating event $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to add event to Google Calendar")));
    }
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Event to Google Calendar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _eventTitleController,
              decoration: InputDecoration(labelText: "Event Title"),
            ),
            TextField(
              controller: _eventDescriptionController,
              decoration: InputDecoration(labelText: "Event Description"),
            ),
            Row(
              children: [
                Text("Start Time: "),
                Expanded(
                  child: TextButton(
                    child: Text(_eventStartTime.toString()),
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _eventStartTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != _eventStartTime)
                        setState(() {
                          _eventStartTime = picked;
                        });
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text("End Time: "),
                Expanded(
                  child: TextButton(
                    child: Text(_eventEndTime.toString()),
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _eventEndTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != _eventEndTime)
                        setState(() {
                          _eventEndTime = picked;
                        });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text("Sign in with Google"),
              onPressed: _handleSignIn,
            ),
            ElevatedButton(
              child: Text("Add Event"),
              onPressed: _addEventToGoogleCalendar,
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
