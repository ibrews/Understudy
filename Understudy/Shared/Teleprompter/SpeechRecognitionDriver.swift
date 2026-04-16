//
//  SpeechRecognitionDriver.swift
//  Understudy
//
//  Wraps `SFSpeechRecognizer` for live on-device recognition. Feeds
//  recognized text into `VoiceMatcher` and updates `TeleprompterState`.
//  Works on iOS 17+ and visionOS 1+ (both have Speech framework).
//
//  Lifecycle:
//    1. Caller asks for authorization (once; system dialog).
//    2. start() begins an AVAudioEngine capture + SFSpeechRecognitionTask.
//    3. Every partial result fires processSpoken() which runs VoiceMatcher
//       and updates state.scrollProgress forward.
//    4. stop() tears down engine + task.
//
//  Intentionally on-device only — `requiresOnDeviceRecognition = true` so
//  we don't ship performer's lines to Apple's servers.
//

#if canImport(Speech)
import Foundation
import Speech
import AVFoundation

@MainActor
public final class SpeechRecognitionDriver {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public private(set) var isRunning: Bool = false
    public var onHeard: ((String) -> Void)?

    public init() {}

    /// Prompt the user for Speech + Microphone if not yet granted. Calls
    /// back with whether recognition can proceed.
    public func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                Task { @MainActor in completion(false) }
                return
            }
            #if os(iOS)
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in completion(granted) }
            }
            #else
            // visionOS: microphone permission is granted with the app's
            // NSMicrophoneUsageDescription entitlement; Speech is the
            // gating factor.
            Task { @MainActor in completion(true) }
            #endif
        }
    }

    public func start() {
        guard !isRunning else { return }
        guard let recognizer = recognizer, recognizer.isAvailable else { return }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13, visionOS 1, *) {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.onHeard?(transcript)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in self.stop() }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
        } catch {
            stop()
        }
    }

    public func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        isRunning = false
    }
}
#endif
