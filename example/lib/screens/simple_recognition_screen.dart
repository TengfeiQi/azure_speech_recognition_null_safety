import 'package:azure_speech_recognition_null_safety/azure_speech_recognition_null_safety.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

class SimpleRecognitionScreen extends StatefulWidget {
  @override
  _SimpleRecognitionScreenState createState() =>
      _SimpleRecognitionScreenState();
}

class _SimpleRecognitionScreenState extends State<SimpleRecognitionScreen>
    with SingleTickerProviderStateMixin {
  String _centerText = 'Unknown';
  late AzureSpeechRecognition _speechAzure;
  // String subKey = dotenv.get("AZURE_KEY");
  String subKey = 'wahaha';
  String region = dotenv.get('AZURE_REGION');
  String lang = "en-US";
  String timeout = "2000";
  bool isRecording = false;
  late AnimationController controller;

  void activateSpeechRecognizer() {
    // MANDATORY INITIALIZATION
    AzureSpeechRecognition.initialize(
      region,
      lang: lang,
      timeout: timeout,
    );

    _speechAzure.setFinalTranscription((text) {
      // do what you want with your final transcription
      debugPrint("Setting final transcript");
      setState(() {
        _centerText = text;
        isRecording = false;
      });
    });

    _speechAzure.setRecognitionResultHandler((text) {
      debugPrint("Received partial result in recognizer: $text");
    });

    _speechAzure.setRecognitionStartedHandler(() {
      // called at the start of recognition (it could also not be used)
      debugPrint("Recognition started");
      setState(() {
        isRecording = true;
      });
    });
  }

  @override
  void initState() {
    _speechAzure = AzureSpeechRecognition();
    controller =
        AnimationController(vsync: this, duration: Duration(seconds: 2))
          ..repeat();
    activateSpeechRecognizer();
    super.initState();
  }

  Future _recognizeVoice() async {
    try {
      String accessToken =
          'eyJhbGciOiJFUzI1NiIsImtpZCI6ImtleTEiLCJ0eXAiOiJKV1QifQ.eyJyZWdpb24iOiJzb3V0aGVhc3Rhc2lhIiwic3Vic2NyaXB0aW9uLWlkIjoiYWMwN2Y5NDljZGE0NDUzN2E0ZWJhMTlmZDhiYTk3YmEiLCJwcm9kdWN0LWlkIjoiU3BlZWNoU2VydmljZXMuRjAiLCJjb2duaXRpdmUtc2VydmljZXMtZW5kcG9pbnQiOiJodHRwczovL2FwaS5jb2duaXRpdmUubWljcm9zb2Z0LmNvbS9pbnRlcm5hbC92MS4wLyIsImF6dXJlLXJlc291cmNlLWlkIjoiL3N1YnNjcmlwdGlvbnMvMGRjZjM5NmQtNTY5Yy00ZDY2LWJiYTItZGJlNDRjOTE2ZTFmL3Jlc291cmNlR3JvdXBzL3R0cy9wcm92aWRlcnMvTWljcm9zb2Z0LkNvZ25pdGl2ZVNlcnZpY2VzL2FjY291bnRzL21vb2RjaGF0Iiwic2NvcGUiOiJzcGVlY2hzZXJ2aWNlcyIsImF1ZCI6InVybjptcy5zcGVlY2hzZXJ2aWNlcy5zb3V0aGVhc3Rhc2lhIiwiZXhwIjoxNzE4MzM5OTUwLCJpc3MiOiJ1cm46bXMuY29nbml0aXZlc2VydmljZXMifQ.s1dm8DATVqLIownvL87bfd7O5YNMT36V6dxuTQ1_e8lcClgPQy71qPm2T9PvyLco9XdWmq2IV3VTrOdqfrGbWQ';
      AzureSpeechRecognition.simpleVoiceRecognition(
        accessToken: accessToken,
      ); //await platform.invokeMethod('azureVoice');
      print("Started recognition with subKey: $subKey");
    } on Exception catch (e) {
      print("Failed to get text '$e'.");
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Is recording: $isRecording'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 40,
            ),
            Center(
              child: AnimatedBuilder(
                child: FlutterLogo(size: 200),
                animation: controller,
                builder: (_, child) {
                  return Transform.rotate(
                    angle: controller.value * 2 * pi,
                    child: child,
                  );
                },
              ),
            ),
            SizedBox(
              height: 40,
            ),
            Text('Recognized text : $_centerText\n'),
            FloatingActionButton(
              onPressed: !isRecording ? _recognizeVoice : null,
              child: Icon(Icons.mic),
            ),
          ],
        ),
      ),
    );
  }
}
