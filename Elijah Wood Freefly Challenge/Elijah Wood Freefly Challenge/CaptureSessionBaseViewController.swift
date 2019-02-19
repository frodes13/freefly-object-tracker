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

    @IBOutlet weak var MLPredictionLabel: UILabel!
    @IBOutlet weak var MLPredictionIsCatLabel: UILabel!
    
    var bufferSize: CGSize = .zero
    
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
        
        var deviceInput: AVCaptureDeviceInput!

        // Instantiate AVCaptureSession
        
        // Find available capture devices
        let videoDeviceInput = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDeviceInput!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        // Optimize for Vision efficiency?
        captureSession.beginConfiguration()
//        captureSession.sessionPreset = .vga640x480 // Model image size is smaller.
        
        // Connect device to AVCaptureSession
        captureSession.addInput(deviceInput)
        captureSession.commitConfiguration()
        
        // Add output to AVCaptureSession
        if captureSession.canAddOutput(captureOutput) {
            captureSession.addOutput(captureOutput)
            
            // Add a video data output
            captureOutput.alwaysDiscardsLateVideoFrames = true
            captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            captureOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            captureSession.commitConfiguration()
            return
        }
        
//
//        let captureConnection = captureOutput.connection(with: .video)
//
//        // Always process the frames
//        captureConnection?.isEnabled = true
//        do {
//            try  videoDeviceInput!.lockForConfiguration()
//            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDeviceInput?.activeFormat.formatDescription)!)
//            bufferSize.width = CGFloat(dimensions.width)
//            bufferSize.height = CGFloat(dimensions.height)
//            videoDeviceInput!.unlockForConfiguration()
//        } catch {
//            print(error)
//        }
        
        
        captureSession.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        // Set locked orientation
        previewLayer.connection?.videoOrientation = .landscapeRight
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = self.view.bounds
        previewView.layer.addSublayer(previewLayer)
    
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Subclass
        
    }

    func startCaptureSession() {
        captureSession.startRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
}
