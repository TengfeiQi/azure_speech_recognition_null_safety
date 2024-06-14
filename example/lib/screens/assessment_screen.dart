import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:azure_speech_recognition_null_safety/azure_speech_recognition_null_safety.dart';
import 'dart:convert';

class AssessmentScreen extends StatefulWidget {
  @override
  AssessmentScreenState createState() {
    return AssessmentScreenState();
  }
}

class AssessmentScreenState extends State<AssessmentScreen> {
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
      '黄河涯',
      dotenv.get('AZURE_REGION'),
      lang: 'en-US',
      timeout: '1500',
    );
    _azureSpeechRecognition.setFinalTranscription((text) {
      if (text.isEmpty) return;
      setState(() {
        _recognizedText += " $text";
        _intermediateResult = '';
      });
      debugPrint('heiheihei');
    });
    _azureSpeechRecognition.setAssessmentResult((result) {
      print('shufajia');
      debugPrint('评估结果');
      debugPrint(result);
      Map<String, dynamic> resultData = jsonDecode(result);
      print(resultData['RecognitionStatus']);
      print(resultData['RecognitionStatus'].runtimeType);

      // if (resultData['RecognitionStatus']) {
      print(resultData['Duration']);
      print(resultData['DisplayText']);
      // debugPrint(resultData['SNR']);
      print(resultData['NBest'][0]['Confidence']);
      print(resultData['NBest'][0]['PronunciationAssessment']);
      print(resultData['NBest'][0]['Words']);
      // }
    });

    _azureSpeechRecognition.onExceptionHandler((exception) {
      debugPrint("Speech recognition exception: $exception");
    });

    _azureSpeechRecognition.setStartHandler(() {
      debugPrint("Speech recognition setStartHandler");
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
      debugPrint('哈哈哈哈哈');
    });
  }

  void stopContinuousStream() {
    AzureSpeechRecognition.stopContinuousRecognition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('语音评估'),
      ),
      body: Column(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _isMicOn = !_isMicOn;
              });
              stopContinuousStream();
            },
            icon: Icon(Icons.stop_rounded),
          ),
          SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() {
                _isMicOn = !_isMicOn;
              });

              String accessToken =
                  'eyJhbGciOiJFUzI1NiIsImtpZCI6ImtleTEiLCJ0eXAiOiJKV1QifQ.eyJyZWdpb24iOiJzb3V0aGVhc3Rhc2lhIiwic3Vic2NyaXB0aW9uLWlkIjoiYWMwN2Y5NDljZGE0NDUzN2E0ZWJhMTlmZDhiYTk3YmEiLCJwcm9kdWN0LWlkIjoiU3BlZWNoU2VydmljZXMuRjAiLCJjb2duaXRpdmUtc2VydmljZXMtZW5kcG9pbnQiOiJodHRwczovL2FwaS5jb2duaXRpdmUubWljcm9zb2Z0LmNvbS9pbnRlcm5hbC92MS4wLyIsImF6dXJlLXJlc291cmNlLWlkIjoiL3N1YnNjcmlwdGlvbnMvMGRjZjM5NmQtNTY5Yy00ZDY2LWJiYTItZGJlNDRjOTE2ZTFmL3Jlc291cmNlR3JvdXBzL3R0cy9wcm92aWRlcnMvTWljcm9zb2Z0LkNvZ25pdGl2ZVNlcnZpY2VzL2FjY291bnRzL21vb2RjaGF0Iiwic2NvcGUiOiJzcGVlY2hzZXJ2aWNlcyIsImF1ZCI6InVybjptcy5zcGVlY2hzZXJ2aWNlcy5zb3V0aGVhc3Rhc2lhIiwiZXhwIjoxNzE4MzM5OTUwLCJpc3MiOiJ1cm46bXMuY29nbml0aXZlc2VydmljZXMifQ.s1dm8DATVqLIownvL87bfd7O5YNMT36V6dxuTQ1_e8lcClgPQy71qPm2T9PvyLco9XdWmq2IV3VTrOdqfrGbWQ';
              AzureSpeechRecognition.continuousRecordingWithAssessment(
                lang: 'zh-CN',
                accessToken: accessToken,
                granularity: 'word', // word text
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
