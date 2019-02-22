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

class CaptureSessionBaseViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak private var previewView: UIView!
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let captureOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
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
        guard
            let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
            captureSession.canAddInput(videoDeviceInput)
            else { return }
        
        // Connect device to AVCaptureSession
        captureSession.addInput(videoDeviceInput)

        // Should we optimize for Vision efficiency?
        
        // Add output to AVCaptureSession
        guard captureSession.canAddOutput(captureOutput) else {
            print("Could not add video data output to the session")
            return
        }

        captureSession.addOutput(captureOutput)

        // Add a video data output
        captureOutput.alwaysDiscardsLateVideoFrames = true
        captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        captureOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        // End configuration
        captureSession.commitConfiguration()
        
        // Preview View
        // Need to make sure visual aligns properly with the image track
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.connection?.videoOrientation = .landscapeRight // Set locked orientation
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // This information is used elsewhere to align the track, syncronize this in the future...
        previewLayer.frame = self.view.bounds
        previewView.layer.addSublayer(previewLayer)
    
    }

    // MARK: Control functions
    func startCaptureSession() {
        captureSession.startRunning()
    }
    
    // Eventually ability to record simultaneously using AVAssetWriter
    func startRecording() {
    }
    
    func stopRecording() {
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Subclass
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
}
