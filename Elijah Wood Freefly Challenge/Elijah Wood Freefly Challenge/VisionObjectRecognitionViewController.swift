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
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        currentPixelBuffer = pixelBuffer
        
        if (currentState == .tracking) {
            do {
                try visionProcessor.performTracking(frame: pixelBuffer, type: .object)
            } catch {
                // handle error
            }
        }
        
//        print("frame processed")

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
//            if trackingView.isPointWithinDrawingArea(locationInView) {
                trackingView.rubberbandingStart = locationInView // start new rubberbanding
            print(locationInView)
//            }
        case .changed:
            // Process resizing of the object's bounding box
            let translation = gestureRecognizer.translation(in: trackingView)
//            let endPoint = trackingView.rubberbandingStart.applying(CGAffineTransform(translationX: translation.x, y: translation.y))
//            guard trackingView.isPointWithinDrawingArea(endPoint) else {
//                return
//            }
            trackingView.rubberbandingVector = translation
            trackingView.setNeedsDisplay()
        case .ended:
            // Finish resizing of the object's boundong box
            let selectedBBox = trackingView.rubberbandingRectNormalized
            if selectedBBox.width > 0 && selectedBBox.height > 0 {
                let rectColor = TrackedObjectsPalette.color(atIndex: self.objectsToTrack.count)
                self.objectsToTrack.append(TrackedPolyRect(cgRect: selectedBBox, color: rectColor))
                
                displayFrame(objectsToTrack)
                
                #warning("create method here for start sequence")
                if (currentState == .stopped) {
                    
                    currentState = .tracking
                    #warning("state management & thread? wtf - want to run processing in background thread")
                    
                    visionProcessor.objectsToTrack = objectsToTrack
                    workQueue.async {
                        do {
                            try self.visionProcessor.readAndDisplayFirstFrame(frame: self.currentPixelBuffer!, performRectanglesDetection: false)
                        } catch {
                            // handle
                        }
                    }
                    

                    
                }


                
                #warning ("Start track frame now")
            }
        default:
            break
        }
    }
    
    @IBAction func reset(_ sender: Any) {
        self.objectsToTrack.removeAll()
        displayFrame(objectsToTrack)
    }
}

extension VisionObjectRecognitionViewController: VisionTrackerProcessorDelegate {
    func displayFrame(_ rects: [TrackedPolyRect]?) {
        DispatchQueue.main.async {
            
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
    
    func didFinishTracking() {
        workQueue.async {
//            self.displayFirstVideoFrame()
        }
        DispatchQueue.main.async {
//            self.state = .stopped
        }
    }
}
