import Flutter
import UIKit
import MicrosoftCognitiveServicesSpeech
import Flutter.FlutterBinaryMessenger
import AVFoundation

// MARK: - Constants
private struct Constants {
    static let channelName = "azure_speech_recognition"
    static let defaultTimeout = "5000"
    static let defaultLanguage = "en-US"
    static let defaultPhonemeAlphabet = "IPA"
}

// MARK: - Error Handling
enum RecognitionError: Error {
    case audioSessionError
    case configurationError
    case recognitionError
    case stopRecognitionError
    
    var description: String {
        switch self {
        case .audioSessionError: return "Audio Session initialization failed"
        case .configurationError: return "Speech configuration failed"
        case .recognitionError: return "Speech recognition failed"
        case .stopRecognitionError: return "Failed to stop recognition"
        }
    }
}

// MARK: - Recognition Task Structure
@available(iOS 13.0, *)
struct SimpleRecognitionTask {
    var task: Task<Void, Never>
    var isCanceled: Bool
}

// MARK: - Main Plugin Class
@available(iOS 13.0, *)
public class SwiftAzureSpeechRecognitionPlugin: NSObject, FlutterPlugin {
    // MARK: - Properties
    private let azureChannel: FlutterMethodChannel
    private var continousListeningStarted: Bool = false
    private var continousSpeechRecognizer: SPXSpeechRecognizer?
    private var simpleRecognitionTasks: [String: SimpleRecognitionTask] = [:]
    private let recognitionQueue = DispatchQueue(label: "com.azure.speech.recognition")
    
    // MARK: - Initialization
    public static func register(with registrar: FlutterPluginRegistrar) {
        guard let taskQueueProvider = registrar.messenger().makeBackgroundTaskQueue else {
            print("🔥🔥🔥🔥🔥🔥 Failed to create task queue")
            return
        }
        let taskQueue = taskQueueProvider()
        
        let channel = FlutterMethodChannel(
            name: Constants.channelName,
            binaryMessenger: registrar.messenger(),
            codec: FlutterStandardMethodCodec.sharedInstance(),
            taskQueue: taskQueue
        )
        let instance = SwiftAzureSpeechRecognitionPlugin(azureChannel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(azureChannel: FlutterMethodChannel) {
        self.azureChannel = azureChannel
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Private Helper Methods
    private func cleanup() {
        continousSpeechRecognizer = nil
        continousListeningStarted = false
        simpleRecognitionTasks.removeAll()
    }
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default, options: .allowBluetooth)
        try audioSession.setActive(true)
    }
    
    private func createSpeechConfig(accessToken: String, region: String, language: String) throws -> SPXSpeechConfiguration {
        let config = try SPXSpeechConfiguration(authorizationToken: accessToken, region: region)
        config.speechRecognitionLanguage = language
        return config
    }
    
    private func notifyListeners(method: String, arguments: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.azureChannel.invokeMethod(method, arguments: arguments)
        }
    }
    
    private func validateConfiguration(accessToken: String, region: String) -> Bool {
        guard !accessToken.isEmpty, !region.isEmpty else {
            print("Invalid configuration: accessToken or region is empty")
            return false
        }
        return true
    }
    
    private func updateRecognitionStatus(isStarted: Bool) {
        recognitionQueue.async {
            self.continousListeningStarted = isStarted
        }
    }

    // MARK: - Flutter Method Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments are required", details: nil))
            return
        }
        
        let accessToken = args["accessToken"] as? String ?? ""
        let serviceRegion = args["region"] as? String ?? ""
        let lang = args["language"] as? String ?? Constants.defaultLanguage
        let timeoutMs = args["timeout"] as? String ?? Constants.defaultTimeout
        let referenceText = args["referenceText"] as? String ?? ""
        let phonemeAlphabet = args["phonemeAlphabet"] as? String ?? Constants.defaultPhonemeAlphabet
        let granularityString = args["granularity"] as? String ?? "phoneme"
        let enableMiscue = args["enableMiscue"] as? Bool ?? false
        let nBestPhonemeCount = args["nBestPhonemeCount"] as? Int
        
        guard validateConfiguration(accessToken: accessToken, region: serviceRegion) else {
            result(FlutterError(code: "INVALID_CONFIG", message: "Invalid configuration", details: nil))
            return
        }
        
        let granularity = granularityString == "text" ? SPXPronunciationAssessmentGranularity.fullText :
                         granularityString == "word" ? SPXPronunciationAssessmentGranularity.word :
                         SPXPronunciationAssessmentGranularity.phoneme
        
        switch call.method {
        case "simpleVoice":
            simpleSpeechRecognition(accessToken: accessToken, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs)
            result(true)
            
        case "simpleVoiceWithAssessment":
            simpleSpeechRecognitionWithAssessment(
                referenceText: referenceText,
                phonemeAlphabet: phonemeAlphabet,
                granularity: granularity,
                enableMiscue: enableMiscue,
                accessToken: accessToken,
                serviceRegion: serviceRegion,
                lang: lang,
                timeoutMs: timeoutMs,
                nBestPhonemeCount: nBestPhonemeCount
            )
            result(true)
            
        case "isContinuousRecognitionOn":
            result(continousListeningStarted)
            
        case "continuousStream":
            continuousStream(accessToken: accessToken, serviceRegion: serviceRegion, lang: lang)
            result(true)
            
        case "continuousStreamWithAssessment":
            continuousStreamWithAssessment(
                accessToken: accessToken,
                referenceText: referenceText,
                phonemeAlphabet: phonemeAlphabet,
                granularity: granularity,
                enableMiscue: enableMiscue,
                serviceRegion: serviceRegion,
                lang: lang,
                nBestPhonemeCount: nBestPhonemeCount
            )
            result(true)
            
        case "stopContinuousStream":
            stopContinuousStream(flutterResult: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Simple Speech Recognition
    private func simpleSpeechRecognition(
        accessToken: String,
        serviceRegion: String,
        lang: String,
        timeoutMs: String
    ) {
        cancelActiveSimpleRecognitionTasks()
        let taskId = UUID().uuidString
        
        let task = Task {
            do {
                try setupAudioSession()
                let speechConfig = try createSpeechConfig(accessToken: accessToken, region: serviceRegion, language: lang)
                speechConfig.setPropertyTo(timeoutMs, by: .speechSegmentationSilenceTimeoutMs)
                
                let audioConfig = SPXAudioConfiguration()
                let recognizer = try SPXSpeechRecognizer(
                    speechConfiguration: speechConfig,
                    audioConfiguration: audioConfig
                )
                
                // 设置识别中的处理器
                setupRecognizingHandler(recognizer: recognizer, taskId: taskId)
                
                // 执行一次性识别
                let result = try recognizer.recognizeOnce()
                
                if !Task.isCancelled {
                    handleRecognitionResult(result)
                }
            } catch {
                handleRecognitionError(error)
            }
            
            simpleRecognitionTasks.removeValue(forKey: taskId)
        }
        
        simpleRecognitionTasks[taskId] = SimpleRecognitionTask(task: task, isCanceled: false)
    }
    
    // MARK: - Simple Speech Recognition With Assessment
    private func simpleSpeechRecognitionWithAssessment(
        referenceText: String,
        phonemeAlphabet: String,
        granularity: SPXPronunciationAssessmentGranularity,
        enableMiscue: Bool,
        accessToken: String,
        serviceRegion: String,
        lang: String,
        timeoutMs: String,
        nBestPhonemeCount: Int?
    ) {
        cancelActiveSimpleRecognitionTasks()
        let taskId = UUID().uuidString
        
        let task = Task {
            do {
                try setupAudioSession()
                let speechConfig = try createSpeechConfig(accessToken: accessToken, region: serviceRegion, language: lang)
                speechConfig.setPropertyTo(timeoutMs, by: .speechSegmentationSilenceTimeoutMs)
                
                let assessmentConfig = try createAssessmentConfig(
                    referenceText: referenceText,
                    phonemeAlphabet: phonemeAlphabet,
                    granularity: granularity,
                    enableMiscue: enableMiscue,
                    nBestPhonemeCount: nBestPhonemeCount
                )
                
                let audioConfig = SPXAudioConfiguration()
                let recognizer = try SPXSpeechRecognizer(
                    speechConfiguration: speechConfig,
                    audioConfiguration: audioConfig
                )
                
                try assessmentConfig.apply(to: recognizer)
                
                // 设置识别中的处理器
                setupRecognizingHandler(recognizer: recognizer, taskId: taskId)
                
                // 执行一次性识别带评估
                let result = try recognizer.recognizeOnce()
                
                if !Task.isCancelled {
                    handleAssessmentResult(result)
                }
            } catch {
                handleRecognitionError(error)
            }
            
            simpleRecognitionTasks.removeValue(forKey: taskId)
        }
        
        simpleRecognitionTasks[taskId] = SimpleRecognitionTask(task: task, isCanceled: false)
    }
    
    // MARK: - Continuous Recognition Methods
    private func continuousStream(
        accessToken: String,
        serviceRegion: String,
        lang: String
    ) {
        if continousListeningStarted {
            stopContinuousRecognition()
            return
        }
        
        do {
            try setupAudioSession()
            let speechConfig = try createSpeechConfig(accessToken: accessToken, region: serviceRegion, language: lang)
            let audioConfig = SPXAudioConfiguration()
            
            continousSpeechRecognizer = try SPXSpeechRecognizer(
                speechConfiguration: speechConfig,
                audioConfiguration: audioConfig
            )
            
            setupContinuousRecognitionHandlers()
            try startContinuousRecognition()
        } catch {
            handleRecognitionError(error)
        }
    }
    
    // MARK: - Continuous Recognition With Assessment
    private func continuousStreamWithAssessment(
        accessToken: String,
        referenceText: String,
        phonemeAlphabet: String,
        granularity: SPXPronunciationAssessmentGranularity,
        enableMiscue: Bool,
        serviceRegion: String,
        lang: String,
        nBestPhonemeCount: Int?
    ) {
        if continousListeningStarted {
            stopContinuousRecognition()
            return
        }
        
        do {
            try setupAudioSession()
            let speechConfig = try createSpeechConfig(accessToken: accessToken, region: serviceRegion, language: lang)
            let assessmentConfig = try createAssessmentConfig(
                referenceText: referenceText,
                phonemeAlphabet: phonemeAlphabet,
                granularity: granularity,
                enableMiscue: enableMiscue,
                nBestPhonemeCount: nBestPhonemeCount
            )
            
            let audioConfig = SPXAudioConfiguration()
            continousSpeechRecognizer = try SPXSpeechRecognizer(
                speechConfiguration: speechConfig,
                audioConfiguration: audioConfig
            )
            
            try assessmentConfig.apply(to: continousSpeechRecognizer!)
            setupContinuousAssessmentHandlers()
            try startContinuousRecognition()
        } catch {
            handleRecognitionError(error)
        }
    }
    
    // MARK: - Helper Methods
    private func createAssessmentConfig(
        referenceText: String,
        phonemeAlphabet: String,
        granularity: SPXPronunciationAssessmentGranularity,
        enableMiscue: Bool,
        nBestPhonemeCount: Int?
    ) throws -> SPXPronunciationAssessmentConfiguration {
        let config = try SPXPronunciationAssessmentConfiguration(
            referenceText,
            gradingSystem: .hundredMark,
            granularity: granularity,
            enableMiscue: enableMiscue
        )
        
        config.phonemeAlphabet = phonemeAlphabet
        if let nBestCount = nBestPhonemeCount {
            config.nbestPhonemeCount = nBestCount
        }
        
        return config
    }
    
    private func setupContinuousRecognitionHandlers() {
        continousSpeechRecognizer?.addRecognizingEventHandler { [weak self] _, evt in
            self?.notifyListeners(method: "speech.onSpeech", arguments: evt.result.text)
        }
        
        continousSpeechRecognizer?.addRecognizedEventHandler { [weak self] _, evt in
            self?.notifyListeners(method: "speech.onFinalResponse", arguments: evt.result.text)
        }
    }
    
    private func setupContinuousAssessmentHandlers() {
        setupContinuousRecognitionHandlers()
        
        continousSpeechRecognizer?.addRecognizedEventHandler { [weak self] _, evt in
            let pronunciationAssessmentResultJson = evt.result.properties?.getPropertyBy(.speechServiceResponseJsonResult)
            self?.notifyListeners(method: "speech.onAssessmentResult", arguments: pronunciationAssessmentResultJson)
        }
    }
    
    private func startContinuousRecognition() throws {
        try continousSpeechRecognizer?.startContinuousRecognition()
        notifyListeners(method: "speech.onRecognitionStarted", arguments: nil)
        updateRecognitionStatus(isStarted: true)
    }
    
    private func stopContinuousRecognition() {
        do {
            try continousSpeechRecognizer?.stopContinuousRecognition()
            notifyListeners(method: "speech.onRecognitionStopped", arguments: nil)
            cleanup()
        } catch {
            print("Error stopping continuous recognition: \(error)")
        }
    }
}