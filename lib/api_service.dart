import 'dart:convert';
import 'package:http/http.dart' as http;
import 'gpt_api.dart';

class ApiService {
  final String apiKey = gptApi;
  final String apiUrl = 'https://api.openai.com/v1/completions';


  Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo-instruct',
          'prompt': message,
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['text'].trim();
      } else {
        print('Failed to get response from GPT API: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to get response from GPT API');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to get response from GPT API');
    }
  }
}
