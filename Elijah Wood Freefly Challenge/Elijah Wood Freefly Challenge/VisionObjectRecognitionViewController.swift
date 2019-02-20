//
//  VisionObjectRecognitionViewController.swift
//  Elijah Wood Freefly Challenge
//
//  Created by Elijah Wood on 2/14/19.
//  Copyright © 2019 Frodes. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class VisionObjectRecognitionViewController: CaptureSessionBaseViewController {
    
    enum State {
        case tracking
        case stopped
    }
    
    @IBOutlet weak var trackingView: TrackingImageView!
    
    private var visionProcessor: VisionTrackerProcessor!
    private var workQueue = DispatchQueue(label: "com.frodes.app", qos: .userInitiated)
    private var objectsToTrack = [TrackedPolyRect]()

    private var currentPixelBuffer: CVPixelBuffer?
    
    private var currentState: State = .stopped
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        visionProcessor = VisionTrackerProcessor()
        visionProcessor.delegate = self
        
        // Hmm do I need this?
        resetTracker()
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        currentPixelBuffer = pixelBuffer
        
        if (currentState == .tracking) {
            workQueue.sync {
                do {
                    try self.visionProcessor.processFrame(frame: pixelBuffer)
                } catch {
                    // handle error
                }
            }
        }

    }
    
    override func initializeCaptureSession() {
        super.initializeCaptureSession()
        
        // start the capture
        startCaptureSession()
    }
    
    // MARK: UIGestureRecognizer
    @IBAction func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            // Initiate object selection
            let locationInView = gestureRecognizer.location(in: trackingView)
            trackingView.rubberbandingStart = locationInView // start new rubberbanding
        case .changed:
            // Process resizing of the object's bounding box
            let translation = gestureRecognizer.translation(in: trackingView)
            trackingView.rubberbandingVector = translation
            trackingView.setNeedsDisplay()
        case .ended:
            // Finish resizing of the object's boundong box
            let selectedBBox = trackingView.rubberbandingRectNormalized
            if selectedBBox.width > 0 && selectedBBox.height > 0 {
                let rectColor = TrackedObjectsPalette.color(atIndex: self.objectsToTrack.count)
                self.objectsToTrack.append(TrackedPolyRect(cgRect: selectedBBox, color: rectColor))
                
                displayFrame(objectsToTrack)
                
                if (currentState == .stopped) {
                    startTracking()
                }
                
            }
        default:
            break
        }
    }
    
    @IBAction func reset(_ sender: Any) {
        resetTracker()
    }
    
    func startTracking() {
        // initialize processor
        visionProcessor.objectsToTrack = objectsToTrack
        self.currentState = .tracking // Start track

//        workQueue.async {
//            do {
//                try self.visionProcessor.readAndDisplayFirstFrame(frame: self.currentPixelBuffer!, performRectanglesDetection: true)
//            } catch {
//                self.handleError(error)
//            }
//        }
    }
    
    func resetTracker() {
        self.objectsToTrack.removeAll()
//        self.visionProcessor.reset()
//        self.currentState = .stopped // Stop track
        displayFrame(objectsToTrack)
    }
}

extension VisionObjectRecognitionViewController: VisionTrackerProcessorDelegate {
    func displayFrame(_ rects: [TrackedPolyRect]?) {
        DispatchQueue.main.async {
            
            let ciImage = CIImage(cvPixelBuffer: self.currentPixelBuffer!)
            let uiImage = UIImage(ciImage: ciImage)
            self.trackingView.image = uiImage
            
            self.trackingView.polyRects = rects ?? self.objectsToTrack // Default
            self.trackingView.rubberbandingStart = CGPoint.zero
            self.trackingView.rubberbandingVector = CGPoint.zero
            
            self.trackingView.setNeedsDisplay()
        }
    }
    
//    func displayFrameCounter(_ frame: Int) {
//        DispatchQueue.main.async {
////            self.frameCounterLabel.text = "Frame: \(frame)"
//        }
//    }
    
//    func didFinishTracking() {
//        workQueue.async {
////            self.displayFirstVideoFrame()
//        }
//        DispatchQueue.main.async {
////            self.state = .stopped
//        }
//    }
}
