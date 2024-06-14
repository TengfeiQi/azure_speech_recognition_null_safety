import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:azure_speech_recognition_null_safety/azure_speech_recognition_null_safety.dart';

class ContinuousRecognitionScreen extends StatefulWidget {
  @override
  ContinuousRecognitionScreenState createState() {
    return ContinuousRecognitionScreenState();
  }
}

class ContinuousRecognitionScreenState
    extends State<ContinuousRecognitionScreen> {
  bool _isMicOn = false;
  String _intermediateResult = '';
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    final AzureSpeechRecognition _azureSpeechRecognition =
        AzureSpeechRecognition();
    AzureSpeechRecognition.initialize(
      // dotenv.get('AZURE_KEY'),
      dotenv.get('AZURE_REGION'),
      lang: 'zh-CN',
      timeout: '1500',
    );
    _azureSpeechRecognition.setFinalTranscription((text) {
      if (text.isEmpty) return;
      setState(() {
        _recognizedText += " $text";
        _intermediateResult = '';
      });
    });
    _azureSpeechRecognition.onExceptionHandler((exception) {
      debugPrint("Speech recognition exception: $exception");
    });
    _azureSpeechRecognition.setRecognitionStartedHandler(() {
      debugPrint("Speech recognition has started.");
    });
    _azureSpeechRecognition.setRecognitionStoppedHandler(() {
      debugPrint("Speech recognition has stopped.");
    });
    _azureSpeechRecognition.setRecognitionResultHandler((text) {
      setState(() {
        _intermediateResult = text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Continuous Recognition ppp'),
      ),
      body: Column(
        children: [
          SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() {
                _isMicOn = !_isMicOn;
              });
              String accessToken =
                  'eyJhbGciOiJFUzI1NiIsImtpZCI6ImtleTEiLCJ0eXAiOiJKV1QifQ.eyJyZWdpb24iOiJzb3V0aGVhc3Rhc2lhIiwic3Vic2NyaXB0aW9uLWlkIjoiYWMwN2Y5NDljZGE0NDUzN2E0ZWJhMTlmZDhiYTk3YmEiLCJwcm9kdWN0LWlkIjoiU3BlZWNoU2VydmljZXMuRjAiLCJjb2duaXRpdmUtc2VydmljZXMtZW5kcG9pbnQiOiJodHRwczovL2FwaS5jb2duaXRpdmUubWljcm9zb2Z0LmNvbS9pbnRlcm5hbC92MS4wLyIsImF6dXJlLXJlc291cmNlLWlkIjoiL3N1YnNjcmlwdGlvbnMvMGRjZjM5NmQtNTY5Yy00ZDY2LWJiYTItZGJlNDRjOTE2ZTFmL3Jlc291cmNlR3JvdXBzL3R0cy9wcm92aWRlcnMvTWljcm9zb2Z0LkNvZ25pdGl2ZVNlcnZpY2VzL2FjY291bnRzL21vb2RjaGF0Iiwic2NvcGUiOiJzcGVlY2hzZXJ2aWNlcyIsImF1ZCI6InVybjptcy5zcGVlY2hzZXJ2aWNlcy5zb3V0aGVhc3Rhc2lhIiwiZXhwIjoxNzE4MzQxMTIxLCJpc3MiOiJ1cm46bXMuY29nbml0aXZlc2VydmljZXMifQ.z3J8CgtvrWoXkd5Uzc4Oby2xCZKd2MfTr-KmTwqYh27E0yhd9wySUrTDmPMocWopqXV7l3UwCXFK_OYs_4khEA';
              AzureSpeechRecognition.continuousRecording(
                accessToken: accessToken,
                lang: 'zh-CN',
              );
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isMicOn ? Colors.green : Colors.red,
              ),
              child: Icon(
                _isMicOn ? Icons.mic : Icons.mic_off,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('Recognizing: $_intermediateResult'),
          SizedBox(height: 20),
          Expanded(
            child: TextField(
              readOnly: true,
              maxLines: null,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Transcription',
              ),
              controller: TextEditingController(text: _recognizedText),
            ),
          ),
        ],
      ),
    );
  }
}
