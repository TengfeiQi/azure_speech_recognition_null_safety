import Flutter
import UIKit
import MicrosoftCognitiveServicesSpeech
import Flutter.FlutterBinaryMessenger
import AVFoundation

@available(iOS 13.0, *)
struct SimpleRecognitionTask {
    var task: Task<Void, Never>
    var isCanceled: Bool
}

// 优化后的版本
// https://light.tinymaker.net/chat?id=72e96f2f-ccb7-4a58-a918-a177c904f9d6
@available(iOS 13.0, *)
public class SwiftAzureSpeechRecognitionPlugin: NSObject, FlutterPlugin {
    var azureChannel: FlutterMethodChannel
    var continousListeningStarted: Bool = false
    var continousSpeechRecognizer: SPXSpeechRecognizer? = nil
    var simpleRecognitionTasks: Dictionary<String, SimpleRecognitionTask> = [:]
    // private let recognitionQueue = DispatchQueue(label: "com.azure.speech.recognition")
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        guard let taskQueueProvider = registrar.messenger().makeBackgroundTaskQueue else {
            // 处理解包失败的情况，例如记录日志或返回错误
            print("🔥🔥🔥🔥🔥🔥 处理解包失败")
            return
        }
        let taskQueue = taskQueueProvider()

        let channel = FlutterMethodChannel(
            name: "azure_speech_recognition", 
            binaryMessenger: registrar.messenger(),
            codec: FlutterStandardMethodCodec.sharedInstance(), 
            taskQueue: taskQueue
        )
        let instance: SwiftAzureSpeechRecognitionPlugin = SwiftAzureSpeechRecognitionPlugin(azureChannel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    init(azureChannel: FlutterMethodChannel) {
        self.azureChannel = azureChannel
    }

    // 添加清理方法
    private func cleanup() {
        continousSpeechRecognizer = nil
        continousListeningStarted = false
        simpleRecognitionTasks.removeAll()
    }

    // 在 deinit 中确保资源释放
    deinit {
        cleanup()
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? Dictionary<String, Any>
        // let speechSubscriptionKey = args?["subscriptionKey"] as? String ?? ""
        let accessToken = args?["accessToken"] as? String ?? ""
        let serviceRegion = args?["region"] as? String ?? ""
        let lang = args?["language"] as? String ?? ""
        let timeoutMs = args?["timeout"] as? String ?? ""
        let referenceText = args?["referenceText"] as? String ?? ""
        let phonemeAlphabet = args?["phonemeAlphabet"] as? String ?? "IPA"
        let granularityString = args?["granularity"] as? String ?? "phoneme"
        let enableMiscue = args?["enableMiscue"] as? Bool ?? false
        let nBestPhonemeCount = args?["nBestPhonemeCount"] as? Int
        var granularity: SPXPronunciationAssessmentGranularity
        if (granularityString == "text") {
            granularity = SPXPronunciationAssessmentGranularity.fullText
        }
        else if (granularityString == "word") {
            granularity = SPXPronunciationAssessmentGranularity.word
        }
        else {
            granularity = SPXPronunciationAssessmentGranularity.phoneme
        }
        if (call.method == "simpleVoice") {
            print("Called simpleVoice")
            simpleSpeechRecognition(
                // speechSubscriptionKey: speechSubscriptionKey, 
                accessToken: accessToken,
                serviceRegion: serviceRegion, 
                lang: lang, 
                timeoutMs: timeoutMs
            )
            result(true)
        }
        else if (call.method == "simpleVoiceWithAssessment") {
            print("Called simpleVoiceWithAssessment")
            simpleSpeechRecognitionWithAssessment(
                referenceText: referenceText, 
                phonemeAlphabet: phonemeAlphabet,  
                granularity: granularity, 
                enableMiscue: enableMiscue, 
                accessToken: accessToken,
                // speechSubscriptionKey: speechSubscriptionKey, 
                serviceRegion: serviceRegion, 
                lang: lang, 
                timeoutMs: timeoutMs, 
                nBestPhonemeCount: nBestPhonemeCount
            )
            result(true)
        }
        else if (call.method == "isContinuousRecognitionOn") {
            print("Called isContinuousRecognitionOn: \(continousListeningStarted)")
            result(continousListeningStarted)
        }
        else if (call.method == "continuousStream") {
            print("Called continuousStream")
            continuousStream(
                // speechSubscriptionKey: speechSubscriptionKey, 
                accessToken: accessToken, 
                serviceRegion: serviceRegion, 
                lang: lang
            )
            result(true)
        }
        else if (call.method == "continuousStreamWithAssessment") {
            print("Called continuousStreamWithAssessment")
            continuousStreamWithAssessment(
                accessToken: accessToken,
                referenceText: referenceText, 
                phonemeAlphabet: phonemeAlphabet,  
                granularity: granularity, 
                enableMiscue: enableMiscue, 
                // speechSubscriptionKey: speechSubscriptionKey, 
                serviceRegion: serviceRegion, 
                lang: lang, 
                nBestPhonemeCount: nBestPhonemeCount
            )
            result(true)
        }
        else if (call.method == "stopContinuousStream") {
            stopContinuousStream(flutterResult: result)
        }
        else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func cancelActiveSimpleRecognitionTasks() {
        print("Cancelling any active tasks")
        for taskId in simpleRecognitionTasks.keys {
            print("Cancelling task \(taskId)")
            simpleRecognitionTasks[taskId]?.task.cancel()
            simpleRecognitionTasks[taskId]?.isCanceled = true
        }
    }
    
    // speechSubscriptionKey : String, 
    private func simpleSpeechRecognition(
        accessToken: String, 
        serviceRegion : String, 
        lang: String, 
        timeoutMs: String
    ) {
        print("Created new recognition task")
        cancelActiveSimpleRecognitionTasks()
        let taskId = UUID().uuidString;
        let task = Task {
            print("Started recognition with task ID \(taskId)")
            var speechConfig: SPXSpeechConfiguration?
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // Request access to the microphone
                try audioSession.setCategory(AVAudioSession.Category.record, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.allowBluetooth)
                try audioSession.setActive(true)
                print("Setting custom audio session")
                // Initialize speech recognizer and specify correct subscription key and service region
                // try speechConfig = SPXSpeechConfiguration(authorizationToken: accessToken, subscription: speechSubscriptionKey, region: serviceRegion)
                try speechConfig = SPXSpeechConfiguration(authorizationToken: accessToken, region: serviceRegion)
            } catch {
                print("error \(error) happened")
                speechConfig = nil
            }
            speechConfig?.speechRecognitionLanguage = lang
            speechConfig?.setPropertyTo(timeoutMs, by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
            
            let audioConfig = SPXAudioConfiguration()
            let reco = try! SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)
            
            reco.addRecognizingEventHandler() {reco, evt in
                if (self.simpleRecognitionTasks[taskId]?.isCanceled ?? false) { // Discard intermediate results if the task was cancelled
                    print("Ignoring partial result. TaskID: \(taskId)")
                }
                else {
                    print("Intermediate result: \(evt.result.text ?? "(no result)")\nTaskID: \(taskId)")
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onSpeech", arguments: evt.result.text)
                    }
                }
            }
            
            let result = try! reco.recognizeOnce()
            if (Task.isCancelled) {
                print("Ignoring final result. TaskID: \(taskId)")
            } else {
                print("Final result: \(result.text ?? "(no result)")\nReason: \(result.reason.rawValue)\nTaskID: \(taskId)")
                if result.reason != SPXResultReason.recognizedSpeech {
                    let cancellationDetails = try! SPXCancellationDetails(fromCanceledRecognitionResult: result)
                    print("Cancelled: \(cancellationDetails.description), \(cancellationDetails.errorDetails)\nTaskID: \(taskId)")
                    print("Did you set the speech resource key and region values?")
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: "")
                    }
                }
                else {
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: result.text)
                    }
                }
                
            }
            self.simpleRecognitionTasks.removeValue(forKey: taskId)
        }
        simpleRecognitionTasks[taskId] = SimpleRecognitionTask(task: task, isCanceled: false)
    }
    
    // speechSubscriptionKey : String, 
    private func simpleSpeechRecognitionWithAssessment(
        referenceText: String, 
        phonemeAlphabet: String, 
        granularity: SPXPronunciationAssessmentGranularity, 
        enableMiscue: Bool, 
        accessToken: String, 
        serviceRegion : String, 
        lang: String, 
        timeoutMs: String, 
        nBestPhonemeCount: Int?
    ) {
        print("Created new recognition task")
        cancelActiveSimpleRecognitionTasks()
        let taskId = UUID().uuidString;
        let task = Task {
            print("Started recognition with task ID \(taskId)")
            var speechConfig: SPXSpeechConfiguration?
            var pronunciationAssessmentConfig: SPXPronunciationAssessmentConfiguration?
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // Request access to the microphone
                try audioSession.setCategory(AVAudioSession.Category.record, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.allowBluetooth)
                try audioSession.setActive(true)
                print("Setting custom audio session")
                // Initialize speech recognizer and specify correct subscription key and service region
                // try speechConfig = SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
                try speechConfig = SPXSpeechConfiguration(authorizationToken: accessToken, region: serviceRegion)
                try pronunciationAssessmentConfig = SPXPronunciationAssessmentConfiguration.init(
                    referenceText,
                    gradingSystem: SPXPronunciationAssessmentGradingSystem.hundredMark,
                    granularity: granularity,
                    enableMiscue: enableMiscue)
            } catch {
                print("error \(error) happened")
                speechConfig = nil
            }
            pronunciationAssessmentConfig?.phonemeAlphabet = phonemeAlphabet
            
            if nBestPhonemeCount != nil {
                pronunciationAssessmentConfig?.nbestPhonemeCount = nBestPhonemeCount!
            }

            

            // pronunciationAssessmentConfig?.enableProsodyAssessment = true
            // pronunciationAssessmentConfig?.enableContentAssessmentWithTopic("Talk about a book you've read recently")
            
            speechConfig?.speechRecognitionLanguage = lang
            speechConfig?.setPropertyTo(timeoutMs, by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
            
            let audioConfig = SPXAudioConfiguration()
            let reco = try! SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)
            try! pronunciationAssessmentConfig?.apply(to: reco)
            
            reco.addRecognizingEventHandler() {reco, evt in
                if (self.simpleRecognitionTasks[taskId]?.isCanceled ?? false) { // Discard intermediate results if the task was cancelled
                    print("Ignoring partial result. TaskID: \(taskId)")
                }
                else {
                    print("Intermediate result: \(evt.result.text ?? "(no result)")\nTaskID: \(taskId)")
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onSpeech", arguments: evt.result.text)
                    }
                }
            }
            
            let result = try! reco.recognizeOnce()
            if (Task.isCancelled) {
                print("Ignoring final result. TaskID: \(taskId)")
            } else {
                print("Final result: \(result.text ?? "(no result)")\nReason: \(result.reason.rawValue)\nTaskID: \(taskId)")
                let pronunciationAssessmentResultJson = result.properties?.getPropertyBy(SPXPropertyId.speechServiceResponseJsonResult)
                print("pronunciationAssessmentResultJson: \(pronunciationAssessmentResultJson ?? "(no result)")")
                if result.reason != SPXResultReason.recognizedSpeech {
                    let cancellationDetails = try! SPXCancellationDetails(fromCanceledRecognitionResult: result)
                    print("Cancelled: \(cancellationDetails.description), \(cancellationDetails.errorDetails)\nTaskID: \(taskId)")
                    print("Did you set the speech resource key and region values?")

                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: "")
                    }
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onAssessmentResult", arguments: "")
                    }
                }
                else {
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: result.text)
                    }
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onAssessmentResult", arguments: pronunciationAssessmentResultJson)
                    }
                }
                
            }
            self.simpleRecognitionTasks.removeValue(forKey: taskId)
        }
        simpleRecognitionTasks[taskId] = SimpleRecognitionTask(task: task, isCanceled: false)
    }
    
    private func stopContinuousStream(flutterResult: FlutterResult) {
        if (continousListeningStarted) {
            print("Stopping continous recognition")
            do {
                try continousSpeechRecognizer!.stopContinuousRecognition()
                DispatchQueue.main.async {
                    self.azureChannel.invokeMethod("speech.onRecognitionStopped", arguments: nil)
                }
                continousSpeechRecognizer = nil
                continousListeningStarted = false
                flutterResult(true)
            }
            catch {
                print("Error occurred stopping continous recognition")
            }
        }
    }
    
    private func continuousStream(accessToken: String, serviceRegion : String, lang: String) {
        if (continousListeningStarted) {
            print("Stopping continous recognition")
            do {
                try continousSpeechRecognizer!.stopContinuousRecognition()
                DispatchQueue.main.async {
                    self.azureChannel.invokeMethod("speech.onRecognitionStopped", arguments: nil)
                }
                continousSpeechRecognizer = nil
                continousListeningStarted = false
            }
            catch {
                // print("Error occurred stopping continous recognition")
                print("Error occurred stopping continous recognition: \(error)")
            }
        }
        else {
            print("Starting continous recognition")
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // Request access to the microphone
                try audioSession.setCategory(AVAudioSession.Category.record, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.allowBluetooth)
                try audioSession.setActive(true)
                print("Setting custom audio session")
            }
            catch {
                // print("An unexpected error occurred")
                print("An unexpected error occurred while setting audio session: \(error)")
            }
            
            // let speechConfig = try! SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
            // 新 token
            // let speechConfig = try! SPXSpeechConfiguration(authorizationToken: accessToken, region: serviceRegion)
            
            // speechConfig.speechRecognitionLanguage = lang
            
            // let audioConfig = SPXAudioConfiguration()
            
            // continousSpeechRecognizer = try! SPXSpeechRecognizer(speechConfiguration: speechConfig, audioConfiguration: audioConfig)
            // continousSpeechRecognizer!.addRecognizingEventHandler() {reco, evt in
            //     print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
            //     DispatchQueue.main.async {
            //         self.azureChannel.invokeMethod("speech.onSpeech", arguments: evt.result.text)
            //     }
            // }
            // continousSpeechRecognizer!.addRecognizedEventHandler({reco, evt in
            //     let res = evt.result.text
            //     print("final result \(res!)")
            //     DispatchQueue.main.async {
            //         self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: res)
            //     }
            // })
            // print("Listening...")
            // try! continousSpeechRecognizer!.startContinuousRecognition()
            // DispatchQueue.main.async {
            //     self.azureChannel.invokeMethod("speech.onRecognitionStarted", arguments: nil)
            // }
            // continousListeningStarted = true


            do {
                let speechConfig = try SPXSpeechConfiguration(authorizationToken: accessToken, region: serviceRegion)
                speechConfig.speechRecognitionLanguage = lang
                
                let audioConfig = SPXAudioConfiguration()
                
                continousSpeechRecognizer = try SPXSpeechRecognizer(speechConfiguration: speechConfig, audioConfiguration: audioConfig)
                continousSpeechRecognizer!.addRecognizingEventHandler() {reco, evt in
                    print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onSpeech", arguments: evt.result.text)
                    }
                }
                continousSpeechRecognizer!.addRecognizedEventHandler({reco, evt in
                    let res = evt.result.text
                    print("final result \(res ?? "(no result)")")
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: res)
                    }
                })
                print("Listening...")
                try continousSpeechRecognizer!.startContinuousRecognition()
                DispatchQueue.main.async {
                    self.azureChannel.invokeMethod("speech.onRecognitionStarted", arguments: nil)
                }
                continousListeningStarted = true
            }
            catch {
                print("An unexpected error occurred while starting continuous recognition: \(error)")
            }
        }
    }
    
    // speechSubscriptionKey : String, 
    private func continuousStreamWithAssessment(
        accessToken: String, 
        referenceText: String, 
        phonemeAlphabet: String, 
        granularity: SPXPronunciationAssessmentGranularity, 
        enableMiscue: Bool, 
        serviceRegion : String, 
        lang: String, 
        nBestPhonemeCount: Int?
    ) {
        print("Continuous recognition started: \(continousListeningStarted)")
        if (continousListeningStarted) {
            print("Stopping continous recognition")
            do {
                try continousSpeechRecognizer!.stopContinuousRecognition()
                DispatchQueue.main.async {
                    self.azureChannel.invokeMethod("speech.onRecognitionStopped", arguments: nil)
                }
                continousSpeechRecognizer = nil
                continousListeningStarted = false
            }
            catch {
                print("Error occurred stopping continous recognition")
            }
        }
        else {
            print("Starting continous recognition")
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // Request access to the microphone
                try audioSession.setCategory(AVAudioSession.Category.record, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.allowBluetooth)
                try audioSession.setActive(true)
                print("Setting custom audio session")
                
                // 原来
                // let speechConfig = try SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
                // 新用 Token
                // let accessToken = "eyJhbGciOiJFUzI1NiIsImtpZCI6ImtleTEiLCJ0eXAiOiJKV1QifQ.eyJyZWdpb24iOiJzb3V0aGVhc3Rhc2lhIiwic3Vic2NyaXB0aW9uLWlkIjoiYWMwN2Y5NDljZGE0NDUzN2E0ZWJhMTlmZDhiYTk3YmEiLCJwcm9kdWN0LWlkIjoiU3BlZWNoU2VydmljZXMuRjAiLCJjb2duaXRpdmUtc2VydmljZXMtZW5kcG9pbnQiOiJodHRwczovL2FwaS5jb2duaXRpdmUubWljcm9zb2Z0LmNvbS9pbnRlcm5hbC92MS4wLyIsImF6dXJlLXJlc291cmNlLWlkIjoiL3N1YnNjcmlwdGlvbnMvMGRjZjM5NmQtNTY5Yy00ZDY2LWJiYTItZGJlNDRjOTE2ZTFmL3Jlc291cmNlR3JvdXBzL3R0cy9wcm92aWRlcnMvTWljcm9zb2Z0LkNvZ25pdGl2ZVNlcnZpY2VzL2FjY291bnRzL21vb2RjaGF0Iiwic2NvcGUiOiJzcGVlY2hzZXJ2aWNlcyIsImF1ZCI6InVybjptcy5zcGVlY2hzZXJ2aWNlcy5zb3V0aGVhc3Rhc2lhIiwiZXhwIjoxNzE4MzM2NTY5LCJpc3MiOiJ1cm46bXMuY29nbml0aXZlc2VydmljZXMifQ.2R3Vb_za72Eu5M-gh6H-gDcscsNPCTnbWwRUbgQbaRjmxbOFjHWxz0Yj7WhjShf45kbCYyNkPzSnRAQ5d-lSxg"
                let speechConfig = try SPXSpeechConfiguration(authorizationToken: accessToken, region: serviceRegion)
                speechConfig.speechRecognitionLanguage = lang
                
                let pronunciationAssessmentConfig = try SPXPronunciationAssessmentConfiguration.init(
                    referenceText,
                    gradingSystem: SPXPronunciationAssessmentGradingSystem.hundredMark,
                    granularity: granularity,
                    enableMiscue: enableMiscue
                )
                pronunciationAssessmentConfig.phonemeAlphabet = phonemeAlphabet
                pronunciationAssessmentConfig.enableProsodyAssessment() 
                pronunciationAssessmentConfig.enableContentAssessment(withTopic: "greeting")
                
                if nBestPhonemeCount != nil {
                    pronunciationAssessmentConfig.nbestPhonemeCount = nBestPhonemeCount!
                }
                
                
                let audioConfig = SPXAudioConfiguration()
                
                continousSpeechRecognizer = try SPXSpeechRecognizer(speechConfiguration: speechConfig, audioConfiguration: audioConfig)
                try pronunciationAssessmentConfig.apply(to: continousSpeechRecognizer!)
                
                continousSpeechRecognizer!.addRecognizingEventHandler() {reco, evt in
                    print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onSpeech", arguments: evt.result.text)
                    }
                }
                continousSpeechRecognizer!.addRecognizedEventHandler({reco, evt in
                    let result = evt.result
                    print("Final result: \(result.text ?? "(no result)")\nReason: \(result.reason.rawValue)")
                    let pronunciationAssessmentResultJson = result.properties?.getPropertyBy(SPXPropertyId.speechServiceResponseJsonResult)
                    print("pronunciationAssessmentResultJson: \(pronunciationAssessmentResultJson ?? "(no result)")")
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: result.text)
                    }
                    DispatchQueue.main.async {
                        self.azureChannel.invokeMethod("speech.onAssessmentResult", arguments: pronunciationAssessmentResultJson)
                    }
                })
                print("Listening...")
                try continousSpeechRecognizer!.startContinuousRecognition()
                DispatchQueue.main.async {
                    self.azureChannel.invokeMethod("speech.onRecognitionStarted", arguments: nil)
                }
                continousListeningStarted = true
            }
            catch {
                print("An unexpected error occurred: \(error)")
            }
        }
    }
}
