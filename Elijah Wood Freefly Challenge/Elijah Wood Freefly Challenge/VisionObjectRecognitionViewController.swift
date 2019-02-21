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
    
    enum TrackingState {
        case tracking
        case stopped
    }
    
    enum ConnectionState {
        case connected
        case connecting
        case disconnected
    }
    
    private var visionProcessor: VisionTrackerProcessor!
    private var workQueue = DispatchQueue(label: "com.frodes.app", qos: .userInitiated)
    private var objectsToTrack = [TrackedPolyRect]()
    private var currentPixelBuffer: CVPixelBuffer?
    
    // State tracking
    private var trackingState: TrackingState = .stopped
    private var connectionState: ConnectionState = .disconnected
    
    // IBOutlets
    @IBOutlet weak var trackingView: TrackingImageView!
    @IBOutlet weak var connectionButton: UIButton!
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate VisionTrackerProcessor
        visionProcessor = VisionTrackerProcessor()
        visionProcessor.delegate = self
        
        // Format labels
        connectionLabel.layer.masksToBounds = true
        connectionLabel.layer.cornerRadius = 8.0
        
        // Hmm do I need this?
        displayFrame(objectsToTrack)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.QXR(_:)), name: QX.E_KEY, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        currentPixelBuffer = pixelBuffer
        
        if (trackingState == .tracking) {
            workQueue.sync {
                do {
                    try self.visionProcessor.processFrame(frame: pixelBuffer)
                } catch {
                    // handle error
                }
            }
            
            DispatchQueue.main.async {
                self.centerMoviToTrackingCenter()
            }
        }

    }
    
    override func initializeCaptureSession() {
        super.initializeCaptureSession()
        
        // start the capture
        startCaptureSession()
    }
    
    // MARK: Movi control
    // Aim is to keep the detected observation in the center
    func centerMoviToTrackingCenter() {
        // Ensure we are connected to the Movi
        if (connectionState == .connected) {
            // Roll and pan (+) = gimbal right
            // Roll and pan (-) = gimbal left
            // Tilt (+) = gimbal down
            // Tilt (-) = gimbal up
            // 0 - 10,000 speed
            
            // Defaults
            let speedWindow = CGPoint(x: 200, y: 200) // Window in which to apply speed ramp
            let movementWindow: CGFloat = 10 // Window in which we no longer attempt to center
            let maxSpeed: CGFloat = 10000 // Movi max speed
            
            // Get tracking delta
            var delta = getTrackingCenterDelta()
            
            // Apply accepted window (a la calculated backlash)
            if (abs(delta.x) <= movementWindow) {
                delta.x = 0
            }
            if (abs(delta.y) <= movementWindow) {
                delta.y = 0
            }
            
            let pan = Float(((delta.x)*maxSpeed/speedWindow.x))
            let tilt = -Float(((delta.y)*maxSpeed/speedWindow.y))
            
            #warning("How can we concurrently send pan and tilt rate data?")
            // Reccomended at 20hz, but we're running it slightly faster with the capture buffer
            QX.Control277.set(roll: pan, tilt: tilt, pan: pan, gimbalFlags: Float(QX.Control277.INPUT_CONTROL_RZ_RATE))
//            QX.Control277.set(roll: pan, tilt: tilt, pan: pan, gimbalFlags: Float(QX.Control277.INPUT_CONTROL_RY_RATE))
        }
    }
    
    // Return the delta between our display center and our detected observation center
    func getTrackingCenterDelta() -> CGPoint {
        return CGPoint(x: trackingView.scale(cornerPoint: visionProcessor.centerDetectedObservation).x - trackingView.center.x, y: trackingView.scale(cornerPoint: visionProcessor.centerDetectedObservation).y - trackingView.center.y)
    }
    
    // MARK: UIGestureRecognizer
    @IBAction func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        
        // Assure we are not currently tracking (thus limiting possible tracking objects to 1)
        if (trackingState == .tracking) { return }
        
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
                let rectColor = UIColor.green // Green = active tracking
                self.objectsToTrack.append(TrackedPolyRect(cgRect: selectedBBox, color: rectColor))
                
                displayFrame(objectsToTrack)
                
                if (trackingState == .stopped) {
                    startTracking()
                }
                
            }
        default:
            break
        }
    }
    
    func startTracking() {
        // Initialize processor
        visionProcessor.objectsToTrack = objectsToTrack
        self.trackingState = .tracking // Start track
    }
    
    func resetTracker() {
        if (connectionState == .connected) {
            // End control
            QX.Control277.deferr()
        }
        
        self.objectsToTrack.removeAll()
        displayFrame(objectsToTrack)
        
        self.trackingState = .stopped // Stop track
        self.visionProcessor.reset()
    }
    
    // MARK: IBActions
    @IBAction func reset(_ sender: Any) {
        resetTracker()
    }
    
    @IBAction func connect(_ sender: Any) {
        if (connectionState == .disconnected) {
            connectMovi()
        } else {
            disconnectMovi()
        }
    }
    
    func connectMovi() {
        // disconnect and wait for scan results
        qx?.btle.resetConnect("")
        
        connectionState = .connecting
        updateUIStatus()

        // Dispatch after 1 second... wait for scan results
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000)) {
            // try connecting to strongest signal
            var anyDevice = ""
            var rssi = -100
            for d in BTLE.getAvailableDevices() {
                print("Found device [\(d.key)] with rssi \(d.value.rssiValue) ")
                if (d.value.rssiValue > rssi)  {
                    anyDevice = d.key
                    rssi = d.value.rssiValue
                }
            }
            if (anyDevice != "") {
                // statusLabel.text = "Connecting to closest device [\(anyDevice)] with rssi \(rssi)"
                qx?.btle.resetConnect(anyDevice)
            } else {
                self.statusLabel.text = "No devices found, please try again."
                self.connectionState = .disconnected
                self.updateUIStatus()
            }
        }
       
    }
    
    func disconnectMovi() {
        qx?.btle.resetConnect("")
    }
    
    func updateUIStatus() {
        switch connectionState {
        case .connected:
            connectionLabel.text = "CONNECTED"
            connectionLabel.textColor = UIColor.green
            connectionButton.setTitle("DISCONNECT", for: .normal)
        case .connecting:
            connectionLabel.text = "CONNECTING"
            connectionLabel.textColor = UIColor.orange
            connectionButton.setTitle("CONNECT", for: .normal)
        case .disconnected:
            connectionLabel.text = "DISCONNECTED"
            connectionLabel.textColor = UIColor.red
            connectionButton.setTitle("CONNECT", for: .normal)
        }
        
    }
    
    // MARK: QX Reciever
    // QX Reciever processes QX events.  Add an observer using E_KEY, and construct the event class from the notification
    @objc func QXR(_ notification: NSNotification) {
        let e = QX.Event.init(notification)
        // print(e.toString())
        
        if (e.getFlavor() == QX.Event.Flavor.CONNECTED) {
            statusLabel.text = BTLE.getLastSelected()
            
            connectionState = .connected
            updateUIStatus()
        }
        
        if (e.getFlavor() == QX.Event.Flavor.LOGGED_ON) {
            // statusLabel.text = "Logged on with SN \(QX.sn) Comms \(QX.comms) HW \(QX.hw) Name \(BTLE.getLastSelected())"
        }
        
        if (e.getFlavor() == QX.Event.Flavor.DISCONNECTED) {
            statusLabel.text = ""
            
            connectionState = .disconnected
            updateUIStatus()
        }
 
    }
}

extension VisionObjectRecognitionViewController: VisionTrackerProcessorDelegate {
    func displayFrame(_ rects: [TrackedPolyRect]?) {
        DispatchQueue.main.async {
            
            guard let frame = self.currentPixelBuffer else {
                return
            }
            
            // Send current frame to TrackingView
            let ciImage = CIImage(cvPixelBuffer: frame)
            let uiImage = UIImage(ciImage: ciImage)
            self.trackingView.image = uiImage
            
            self.trackingView.polyRects = rects ?? self.objectsToTrack // Default
            self.trackingView.rubberbandingStart = CGPoint.zero
            self.trackingView.rubberbandingVector = CGPoint.zero
            
            self.trackingView.setNeedsDisplay()
            
        }
    }
}
