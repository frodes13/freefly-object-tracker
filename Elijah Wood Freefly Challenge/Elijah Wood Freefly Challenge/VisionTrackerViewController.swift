//
//  VisionTrackerViewController.swift
//  Elijah Wood Freefly Challenge
//
//  Created by Elijah Wood on 2/14/19.
//  Copyright © 2019 Frodes. All rights reserved.
//

import UIKit
import AVFoundation

class VisionTrackerViewController: CaptureSessionBaseViewController {
    
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
    private var currentMoviButtonState: MoviRXButtonStates = MoviRXButtonStates() // Temp
    
    // MOVI Control 277 Manager
    private var Control277ManagerThread: Timer?
    private var currentMoviPosition: MoviMoveRate = MoviMoveRate(mPan: 0.0, mTilt: 0.0)
    
    // State tracking
    private var trackingState: TrackingState = .stopped
    private var connectionState: ConnectionState = .disconnected
    private var isThirds = false
    
    // IBOutlets
    @IBOutlet weak var trackingView: TrackingImageView!
    @IBOutlet weak var connectionButton: UIButton!
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var thirdsButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate VisionTrackerProcessor
        visionProcessor = VisionTrackerProcessor()
        visionProcessor.delegate = self
        
        // Format labels
        connectionLabel.layer.masksToBounds = true
        connectionLabel.layer.cornerRadius = 8.0
        
        // Prep display
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
            workQueue.async {
                do {
                    try self.visionProcessor.processFrame(frame: pixelBuffer)
                } catch {
                    // handle error
                }
            }
            
            // Main Thread
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
    
    // MARK: Movi Control
    // Aim is to keep the detected observation in the center
    /// - Tag: CenterMoviToTrackingCenter
    func centerMoviToTrackingCenter() {
        // Ensure we are connected to the Movi
        if (connectionState == .connected && visionProcessor.centerDetectionActive) {
            // Roll and pan (+) = gimbal right
            // Roll and pan (-) = gimbal left
            // Tilt (+) = gimbal down
            // Tilt (-) = gimbal up
            // 0 - 10,000 speed
            
            // Defaults
            let speedWindow = CGPoint(x: 300, y: 300) // Window in which to apply LINEAR speed ramp
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
            let tilt = -Float(((delta.y)*maxSpeed/speedWindow.y)) // Invert
            
            // Debug
            //print("PT Rate: \(pan), \(tilt)")
            
            // Update Movi Position
            currentMoviPosition = MoviMoveRate(mPan: pan, mTilt: tilt)
        }
    }
    
    // Return the delta between our display center and our detected observation center
    func getTrackingCenterDelta() -> CGPoint {
        
        var delta = CGPoint(x: trackingView.scale(cornerPoint: visionProcessor.centerDetectedObservation).x - trackingView.center.x, y: trackingView.scale(cornerPoint: visionProcessor.centerDetectedObservation).y - trackingView.center.y)

        // This is just a quick feature idea that will lock the track to rule of thirds on the Y axis, instead of center
        if (isThirds) {
            let frameY = delta.y - (trackingView.frame.height/2)
            let third = trackingView.frame.height*(2/3)
            
            delta.y = frameY + third
        }
        
        return delta
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
                let rectColor = MOVI_ORANGE_COLOR // Active tracking
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
    
    // MARK: Tracking Functions
    func startTracking() {
        // Initialize processor
        visionProcessor.objectsToTrack = objectsToTrack
        self.trackingState = .tracking // Start track
        
        // 20hz Control277
        Control277ManagerThread = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { (Timer) in
            // Reccomended at 20hz
            // Bitwise OR to concurrently send pan / tilt messages
            // Limit to pan / tilt
            let gimbalFlags = QX.Control277.INPUT_CONTROL_RZ_RATE | QX.Control277.INPUT_CONTROL_RY_RATE
            QX.Control277.set(roll: self.currentMoviPosition.pan, tilt: self.currentMoviPosition.tilt, pan: self.currentMoviPosition.pan, gimbalFlags: Float(gimbalFlags))
        })
    }
    
    func resetTracker() {
        trackingState = .stopped // Stop track
        Control277ManagerThread?.invalidate()
        currentMoviPosition = MoviMoveRate(mPan: 0.0, mTilt: 0.0)
        
        objectsToTrack.removeAll()
        displayFrame(objectsToTrack)
        
        workQueue.async {
            self.visionProcessor.reset()
        }

        if (self.connectionState == .connected) {
            // End control
            QX.Control277.deferr()
            setMoviToMajesticMode()
        }
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
    
    @IBAction func thirds(_ sender: Any) {
        isThirds = !isThirds
        thirdsButton.setTitleColor(isThirds ? UIColor.green : UIColor.white , for: .normal)
    }
    
    // MARK: Movi API Functions
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
    
    func setMoviToMajesticMode() {
        QX_ChangeValueAbsolute(454, strdup("Active Method top level"), 0);
    }
    
    func setButton(_ e : QX.Event) {
        
        let buttonState = MoviRXButtonStates(e) // Initialize with event
        
        // Only run if there's a change
        if (buttonState.isEqual(currentMoviButtonState)) {
            return
        }
        
        if (buttonState.BTN_TOP == QX.BTN.PRESS) {
            thirds(self)
        }
        
        if (buttonState.BTN_TRIGGER == QX.BTN.PRESS) {
            resetTracker()
        }
        
        if (buttonState.BTN_CENTER == QX.BTN.PRESS) {
            
        }
        
        // Set new current state
        currentMoviButtonState = buttonState
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
    
    // MARK: Movi API QX Reciever
    // QX Reciever processes QX events.  Add an observer using E_KEY, and construct the event class from the notification
    @objc func QXR(_ notification: NSNotification) {
        let e = QX.Event.init(notification)
//         print(e.toString())
        
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
 
        // Display Movi button presses
        setButton(e)
    }
}

extension VisionTrackerViewController: VisionTrackerProcessorDelegate {
    func displayFrame(_ rects: [TrackedPolyRect]?) {
        DispatchQueue.main.async {
            
            guard let frame = self.currentPixelBuffer else {
                return
            }
            
            // Send current frame to TrackingView
            let ciImage = CIImage(cvPixelBuffer: frame)
            let uiImage = UIImage(ciImage: ciImage)
            self.trackingView.image = uiImage
            
            // Make some small adjustments based on TrackingState
            if (self.trackingState == .stopped) {
                self.trackingView.polyRects = [] // Default
            } else {
                self.trackingView.polyRects = rects ?? self.objectsToTrack // Default
            }
            
            self.trackingView.rubberbandingStart = CGPoint.zero
            self.trackingView.rubberbandingVector = CGPoint.zero
            
            self.trackingView.setNeedsDisplay()
            
        }
    }
}
