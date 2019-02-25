//
//  CaptureSessionBaseViewController.swift
//  Elijah Wood Freefly Challenge
//
//  Created by Elijah Wood on 2/14/19.
//  Copyright © 2019 Frodes. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class CaptureSessionBaseViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    @IBOutlet weak private var previewView: UIView!
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    // AVCaptureSession
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let captureOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    
    // AVAssetWriter
    private(set) var isRecording = false
    private var writerIsInitialized = false
    private var videoWriter: AVAssetWriter!
    private var videoWriterInput: AVAssetWriterInput!
    private var audioWriterInput: AVAssetWriterInput!
    private var sessionAtSourceTime: CMTime?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeCaptureSession()
    }
    
    func initializeCaptureSession() {
        // Instantiate AVCaptureSession
        
        // Start configuration
        captureSession.beginConfiguration()
        
        // Find available capture devices
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let audioDevice = AVCaptureDevice.default(for: .audio)
        guard
            let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
            let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice!),
            captureSession.canAddInput(videoDeviceInput),
            captureSession.canAddInput(audioDeviceInput)
            else { return }
        
        // Connect device to AVCaptureSession
        captureSession.addInput(videoDeviceInput)
        captureSession.addInput(audioDeviceInput)

        // Should we optimize for Vision efficiency?
        
        captureOutput.alwaysDiscardsLateVideoFrames = true
        captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        
        // Add video output to AVCaptureSession
        guard captureSession.canAddOutput(captureOutput) else {
            print("Could not add video data output to the session")
            return
        }

        captureOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        captureSession.addOutput(captureOutput)

        // Add audio output to AVCaptureSession
        guard captureSession.canAddOutput(audioOutput) else {
            print("Could not add audio data output to the session")
            return
        }
        
        audioOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        captureSession.addOutput(audioOutput)

        // End configuration
        captureSession.commitConfiguration()
        
        // Preview View
        // Need to make sure visual aligns properly with the image track
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.connection?.videoOrientation = .landscapeRight // Set locked orientation
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // This information is used elsewhere to align the track, syncronize this in the future...
        previewLayer.frame = self.view.bounds
        previewView.layer.addSublayer(previewLayer)
        
        // Initialize AVAssetWriter
        initializeWriter()
    }

    // MARK: Control functions
    func startCaptureSession() {
        captureSession.startRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Subclass
        writeFromCapture(output, didOutput: sampleBuffer)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
    // MARK: AVAssetWriter
    func initializeWriter() {
        // Remove previous temp, if any
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            try FileManager.default.removeItem(at: documentsURL.appendingPathComponent("video_temp.mp4"))
        } catch {
            // Handle error
        }
        
        // Initialze VideoWriter
        do {
            videoWriter = try AVAssetWriter(url: documentsURL.appendingPathComponent("video_temp.mp4"), fileType: AVFileType.mp4)
        } catch {
            // Handle error
        }

        // Add video input
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2300000,
            ],
            ])
        
        videoWriterInput.expectsMediaDataInRealTime = true
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        
        // Add audio input
        audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 64000,
            ])
        
        audioWriterInput.expectsMediaDataInRealTime = true
        
        if videoWriter.canAdd(audioWriterInput) {
            videoWriter.add(audioWriterInput)
        }
        
        writerIsInitialized = true
    }
    
    // Write from AVCaptureOutput
    func writeFromCapture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        
        // Make sure we can write
        if (!canWrite()) {
            return
        }
        
        if (sessionAtSourceTime == nil) {
            // Start writing
            sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            videoWriter.startSession(atSourceTime: sessionAtSourceTime!)
        }
        
        if (output == captureOutput && videoWriterInput.isReadyForMoreMediaData) {
            // Write video buffer
            videoWriterInput.append(sampleBuffer)
        } else if (output == audioOutput && audioWriterInput.isReadyForMoreMediaData) {
            // Write audio buffer
            audioWriterInput.append(sampleBuffer)
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        if (!writerIsInitialized) {
            initializeWriter() // Re initialize
        }
        
        isRecording = true
        sessionAtSourceTime = nil
        videoWriter.startWriting() // Ready to write file
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        videoWriter.finishWriting { [weak self] in
            self?.sessionAtSourceTime = nil
            guard let url = self?.videoWriter.outputURL else { return }
            
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.relativePath) {
                UISaveVideoAtPathToSavedPhotosAlbum(url.relativePath, nil, nil, nil)
            }
            
            self?.writerIsInitialized = false
        }
    }
    
    private func canWrite() -> Bool {
        return isRecording
            && videoWriter != nil
            && videoWriter.status == .writing
    }
    
}
