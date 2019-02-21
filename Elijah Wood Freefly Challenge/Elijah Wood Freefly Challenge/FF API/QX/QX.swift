/*-----------------------------------------------------------------
 MIT License
 
 Copyright (c) 2018 Freefly Systems
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 Filename: "QX.java"
 
 Convenience class manages connection, sends data to device and raises
 managed events when data is returned.
 
 -----------------------------------------------------------------*/

import Foundation

class QX {
    
    public enum BTN : Int {
        case NONE
        case RELEASE
        case PRESS
        case LONG_PRESS
    }
    
    public enum LogStates : Int {
        case LOGGED_OFF
        case LOG_STATE_PENDING
        case LOGGED_ON
    }
    
    public let btle = BTLE();
    
    // Parameter names for Movi buttons
    public static let SWIFT = "Swift";
    public static let BTN_TRIGGER = "Fromo Button Trigger";
    public static let BTN_TOP = "Fromo Button Record";
    public static let BTN_UP = "Fromo Button Up";
    public static let BTN_DOWN = "Fromo Button Down";
    public static let BTN_LEFT = "Fromo Button Left";
    public static let BTN_RIGHT = "Fromo Button Right";
    public static let BTN_CENTER = "Fromo Button Center";
    
    public static var stream34 = false; // Set true to receive Autotune updates
    public static var sn = ""; // Contains Serial number of current or last connected Movi
    public static var comms = 0; // Contains comms revision number of current or last connected
    public static var hw = 0; // Contains hardware type (Movi CR is 6)
    
    public static var logonState = LogStates.LOGGED_OFF; // True when device recognized
    public static var connected = false; // True when btle connection succeeds
    
    public static let E_KEY : NSNotification.Name = NSNotification.Name("EventKey");
    public static let C_KEY = "ConnecitonKey";
    public static let A_KEY = "AttribKey";
    
    private static let RESET_LOCALS = false;
    private var sThread : Timer? = nil;
    private var sThreadSlice = 0;
    private static var control : [Float]  = [0];
    private static var oneInstance = false;
    
    init() {
        if (QX.oneInstance) { NSException(name:NSExceptionName(rawValue: "QX is a singleton!"), reason:"", userInfo:nil).raise() }
        QX.oneInstance = true;
        
        QX_Init();
        sThread = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.ManagerThread), userInfo: nil, repeats: true)
    }
    
    public func finish() {
        btle.stopThread();
        sThread?.invalidate()
        QX.oneInstance = false;
    }
    
    public static func isLoggedOn() -> Bool {
        return (logonState == QX.LogStates.LOGGED_ON);
    }
    
    
    
    /**
     * Configure and send attribute 1126 for Timelapse control
     *
     * @param pCmd      Programming command - see selectionOptions
     * @param aCmd      Action command - see selectionOptions
     * @param index     Index of the KF to program or take action on
     * @param panDegs   pointing direction
     * @param panRevs   pointing direction
     * @param tiltDegs  pointing direction
     * @param rollDegs  pointing direction
     * @param kfSeconds length in seconds of keyframe (last keyframe seconds ignored)
     * @param pd1       pan diff when approaching current kf
     * @param pw1       pan weight when approaching current kf
     * @param pd2       pan diff when leaving current kf
     * @param pw2       pan weight when leaving current kf
     * @param td1       tilt diff when approaching current kf
     * @param tw1       tilt weight when approaching current kf
     * @param td2       tilt diff when leaving current kf
     * @param tw2       tilt diff when approaching current kf
     * @param rd1       roll diff when approaching current kf
     * @param rw1       roll weight when approaching current kf
     * @param rd2       roll diff when leaving current kf
     * @param rw2       roll diff when approaching current kf
     */
    
    public static func sendControl1126( pCmd : String, aCmd : String, index : Float, panDegs : Float, panRevs : Float, tiltDegs : Float, rollDegs : Float, kfSeconds : Float, pd1 : Float,
                                        pw1 : Float, pd2 : Float, pw2 : Float, td1 : Float, tw1 : Float, td2 : Float, tw2 : Float, rd1 : Float, rw1 : Float, rd2 : Float, rw2 : Float) {
        
        let program = ["", "NOTHING", "ADD_KF", "REPLACE_KF", "INSERT_KF", "ADD_KF_HERE", "REPLACE_KF_HERE", "INSERT_KF_HERE", "RESET_TIME", "DEL_KF", "DEL_ALL_KFs", "STREAM_KF", "STREAM_NEXT_KF"]
        let action = ["", "NOTHING", "MOVE_TO_KF", "MOVE_FIRST_KF", "MOVE_LAST_KF", "START_TL", "START_PREVIEW", "CANCEL"]
        let p = program.index(of: pCmd)
        let a = action.index(of: aCmd)
        if let p = p, let a = a {
            let f : [Float] = [ 1126, index, panDegs, panRevs, tiltDegs, rollDegs, kfSeconds, pd1, pw1, pd2, pw2, td1, tw1, td2, tw2, rd1, rw1, rd2, rw2, 0, Float(p - 1), Float(a - 1)]
            QX_ChangeAttributeAbsolute(1126, f);
        } else {
            print("sendControl1126 command or action syntax error [\(pCmd)][\(aCmd)]")
        }
    }
    
    /**
     * Convenience - diff and weight are shared between all controls
     */
    public static func sendControl1126( pCmd : String, aCmd : String,  index : Float,  panDegs : Float,  panRevs : Float,  tiltDegs : Float,  rollDegs : Float,  kfSeconds : Float,  sharedDiff : Float,  sharedWeight : Float) {
        sendControl1126(pCmd: pCmd, aCmd: aCmd, index: index, panDegs: panDegs, panRevs: panRevs, tiltDegs: tiltDegs, rollDegs: rollDegs, kfSeconds: kfSeconds, pd1: sharedDiff, pw1: sharedWeight, pd2: sharedDiff, pw2: sharedWeight, td1: sharedDiff, tw1: sharedWeight, td2: sharedDiff, tw2: sharedWeight, rd1: sharedDiff, rw1: sharedWeight, rd2: sharedDiff, rw2: sharedWeight);
    }
    
    /**
     * "Parameter like" values stored to Android device allows QX compatible UI development
     */
    public class Locals {
        
        public static func raiseEvent(_ key : String) {
            broadcastQxEvent([QX.A_KEY,key],data: [0,get(key)]);
        }
        
        public static func get(_ key : String) -> Float {
            if let val = UserDefaults.standard.object(forKey: key) {
                return Float(val as! Float)
            }
            NSException(name:NSExceptionName(rawValue: "Default value not set for local param " + key), reason:"", userInfo:nil).raise()
            return 0
        }
        
        public static func changeAbsolute(_ key : String,_ val : Float) {
            var f = val
            if (f > get( "MAX_" + key)) { f = get( "MAX_" + key) }
            if (f < get( "MIN_" + key)) { f = get( "MIN_" + key) }
            changeAbsoluteUnchecked( key, f);
        }
        
        // int for math safety
        public static func changeRelative(_ key : String, i : Int) {
            let val  = Int( get(key)) + i;
            changeAbsolute(key, Float(val));
        }
        
        public static func setDefault( key : String, val : Float, min : Float,  max : Float) {
            if let _ = UserDefaults.standard.object(forKey: key) {
                if (!(QX.RESET_LOCALS)) { return }
            }
            changeAbsoluteUnchecked( key, val);
            changeAbsoluteUnchecked( "MIN_" + key, min);
            changeAbsoluteUnchecked( "MAX_" + key, max);
        }
        
        private static func changeAbsoluteUnchecked(_ key : String, _ f : Float) {
            UserDefaults.standard.set(f, forKey: key)
            UserDefaults.standard.synchronize()
            raiseEvent(key);
        }
        
    }
    
    /**
     * Management class for attribute 277 allows adjustment of pan/tilt/roll while streaming
     */
    
    public class Control277 {
        public static let INPUT_CONTROL_RZ_DEFER = 0x00; // Pan
        public static let INPUT_CONTROL_RZ_RATE = 0x01;
        public static let INPUT_CONTROL_RZ_ABS = 0x02;
        public static let INPUT_CONTROL_RZ_ABS_MAJ = 0x03;
        public static let INPUT_CONTROL_RY_DEFER = 0x00; // Tilt
        public static let INPUT_CONTROL_RY_RATE = 0x04;
        public static let INPUT_CONTROL_RY_ABS = 0x08;
        public static let INPUT_CONTROL_RY_ABS_MAJ = 0x0C;
        public static let INPUT_CONTROL_RX_DEFER = 0x00; // Roll
        public static let INPUT_CONTROL_RX_RATE = 0x10;
        public static let INPUT_CONTROL_RX_ABS = 0x20;
        public static let INPUT_CONTROL_RX_ABS_MAJ = 0x30;
        public static let INPUT_CONTROL_QUATERNION = 0x80;
        public static let INPUT_CONTROL_KILL = 0x40;
        
        /**
         * Stream control attribute to Movi
         *
         * @param roll        Approx range -32767 to + 32767
         * @param tilt        Approx range -32767 to + 32767
         * @param pan         Approx range -32767 to + 32767
         * @param gimbalFlags Use INPUT_CONTROL flags
         */
        public static func set(roll : Float, tilt : Float, pan : Float, gimbalFlags : Float) {
            QX.control = [ 277, 0, 0, gimbalFlags, roll, tilt, pan, 1, 0, 0, 0, 0, 0];
        }
        
        public static func deferr() {
            Control277.set(roll: 0, tilt: 0, pan: 0, gimbalFlags: 0);
        }
    }
    
    /**
     * Send a broadcast containing attribute information received from the Movi or Local parameter
     */
    static func broadcastQxEvent(_ paramNames : [String], data : [Float]) {
        var dict = [String: Float]()
        for i in 0...paramNames.count - 1  {
            dict.updateValue(data[i], forKey: paramNames[i])
        }
        NotificationCenter.default.post(name: QX.E_KEY, object: nil, userInfo: dict)
    }
    
    
    
    
    /**
     * Class abstracts all QX events to a single object
     */
    public class Event {
        
        public enum Flavor : Int {
            case DISCONNECTED
            case CONNECTED
            case LOGGED_ON
            case LIST_CHANGE
            case ATTRIBUTE_RX
        }
        
        private var eType = Flavor.DISCONNECTED;
        private var data = [String: Float]()
        
        /*
         * Constructor must be called with a notification containing event data
         */
        public init(_ notification: NSNotification) {
            data = notification.userInfo as! [String : Float]
            if let _ = data[QX.A_KEY] { eType = Flavor.ATTRIBUTE_RX }
            if let i = data[QX.C_KEY] { eType = Flavor.init(rawValue: Int(i))! }
        }
        
        public func getFlavor() -> Flavor {
            return eType;
        }
        
        public func isFlavor(_ t : Flavor) -> Bool {
            return (t == eType);
        }
        
        public func valueNull(_ key : String) -> Float? {
            return data[key];
        }
        
        public func value(_ key : String) -> Float {
            return (valueNull(key) == nil) ? 0 : valueNull(key)!;
        }
        
        public func valueString(_ key : String, _ formatString : String) -> String {
            return (valueNull(key) == nil) ? "" : String(format: formatString, valueNull(key)!);
        }
        
        public func attributeNull() -> Float? {
            return valueNull(A_KEY);
        }
        
        public func attribute() -> Float {
            return (attributeNull() == nil) ? 0 : Float( attributeNull()!);
        }
        
        public func isAttribute(_ attrib : Float) -> Bool {
            return (attribute() == attrib);
        }
        
        public func isConnectionEvent() -> Bool {
            return (eType == Flavor.CONNECTED || eType == Flavor.LOGGED_ON || eType == Flavor.DISCONNECTED);
        }
        
        public func isButtonEvent(_ key : String, _ type : BTN) -> Bool {
            if (isAttribute(309)) {
                if let f = valueNull(key) { return (Int(f) == type.rawValue); }
            }
            return false;
        }
        
        public func toString() -> String {
            var msg = "Event type \(getFlavor()) "
            if (eType == Flavor.ATTRIBUTE_RX) { for d in data { msg += "[\(d.key) \(d.value)]" } }
            return msg
        }
    }
    
    
    
    /**
     * Thread manages logon process and control stream
     */
    @objc private func ManagerThread() {
        
        if (QX.connected && QX.logonState == QX.LogStates.LOGGED_OFF) {
            sThreadSlice -= 1
            if (sThreadSlice  < 1) {
                sThreadSlice = 20;
                print( "trying to log on... ");
                QX_RequestAttr(121);
                QX.logonState = QX.LogStates.LOG_STATE_PENDING;
            }
        } else if (QX.logonState == QX.LogStates.LOG_STATE_PENDING) {
            QX.logonState = QX.LogStates.LOGGED_OFF;
        } else if (QX.logonState == QX.LogStates.LOGGED_ON) {
            // manage control attrib and streaming
            if (QX.control[0] == 277) { QX_ChangeAttributeAbsolute(277, QX.control); }
            if (QX.stream34) { QX_RequestAttr(34); }
        }
    }
    
    
}



// ----------------------  C callbacks and helpers ---------------------------

func QX_ChangeAttributeAbsolute(_ attribute : CLong, _ values : [Float]) {
    var v = values
    v.withUnsafeMutableBufferPointer {unsafeBufferPointer in
        let vv = unsafeBufferPointer.baseAddress
        QX_ChangeAttributeAbsoluteUnsafe(attribute, vv)
    }
}

@_cdecl("bridgeCSattributeRxEvent")
func bridgeCSattributeRxEvent(_ namesPointer: UnsafePointer<CChar>!, valuesPointer: UnsafePointer<Float>!) {
    var namesArray = String(cString: namesPointer).components(separatedBy: ",")
    namesArray.insert(QX.A_KEY, at:0)
    let valuesArray : [Float] = Array( UnsafeBufferPointer(start: valuesPointer, count: namesArray.count + 1 ))
    
    // log on or broadcast
    if(valuesArray[0] == 121 && valuesArray[4] == 6 && !(QX.isLoggedOn()) ) {
        
        // Ensure Movi is not running a timelapse
        QX.sendControl1126(pCmd: "NOTHING", aCmd: "CANCEL", index: 0, panDegs: 0, panRevs: 0, tiltDegs: 0, rollDegs: 0, kfSeconds: 0, sharedDiff: 0, sharedWeight: 0);
        
        // Update status & data
        QX.logonState = QX.LogStates.LOGGED_ON;
        let snM = Int(valuesArray[1]);
        let snL = Int(valuesArray[2]);
        QX.comms = Int(valuesArray[3]);
        QX.hw = Int(valuesArray[4]);
        QX.sn = String(format: "%08X",  (snM << 16) + snL);
        
        BTLE.raiseEvent(QX.Event.Flavor.LOGGED_ON);
        
        print("Logged on! HW \(QX.hw) Comms \(QX.comms) SN \(QX.sn)")
    } else {
        QX.broadcastQxEvent(namesArray, data: valuesArray)
    }
    
}



@_cdecl("bridgeCSsendByte")
func bridgeCSsendByte(x: Int)  {
    if let qx = qx { qx.btle.sendByte(UInt8(x)) }
}





