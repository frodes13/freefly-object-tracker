
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
 
 -----------------------------------------------------------------*/


import Foundation;
import CoreBluetooth;

// Struct for managing and passing Freefly device connection information
struct FreeflyDevice {
    private let RSSI_TIMEOUT : Int = 4 // in seconds
    private let MIN_DBM : Int = -70 // Min accepted (discard lower)
    private let MAX_DBM : Int = -50 // Max expected (for UI)
    
    var name : String
    var peripheral : CBPeripheral
    var rssiValue : Int
    var timeout : Int = 0
    
    func isTimingOut() -> Bool { return (timeout == RSSI_TIMEOUT) }
    func isActive() -> Bool { return (timeout < RSSI_TIMEOUT) }
    func isRssiOk() -> Bool { return (rssiValue >= MIN_DBM && rssiValue < 127) } // discard low/garbage levels
    func getRssiAsScale(scaleMax : Int) -> Int { return map(rssiValue, in_min: MIN_DBM, in_max: MAX_DBM, out_min: 0, out_max: scaleMax) }
}


// Timing
private let TICK1 : Double = 0.001 // state machine call rate in seconds
private let TIMEOUT_TICK : Double = 1 // (seconds) Toggle rate for RSSI update and connection fail check (2x)
private let CON_FAIL_TICK_OFFSET : Double = TIMEOUT_TICK + 1 // Timer tick offset for conneciton fail

@objc class BTLE :NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // Turn debug logging
    fileprivate let DBG_VERBOSE = false
    
    // Constants
    fileprivate static let PERSIST_NAME : String = "PERSIST_NAME"
    fileprivate static let NUM_OF_CHLS :Int = 6
    fileprivate let UART_SERVICE_UUID : CBUUID = CBUUID(string: "ffff0001-0c0b-0a09-0807-060504030201")
    fileprivate let UART_CH_CHAR_UUIDS : [CBUUID] = [
        CBUUID(string: "ffff0002-0c0b-0a09-0807-060504030201"),
        CBUUID(string: "ffff0003-0c0b-0a09-0807-060504030201"),
        CBUUID(string: "ffff0004-0c0b-0a09-0807-060504030201"),
        CBUUID(string: "ffff0005-0c0b-0a09-0807-060504030201"),
        CBUUID(string: "ffff0006-0c0b-0a09-0807-060504030201"),
        CBUUID(string: "ffff0007-0c0b-0a09-0807-060504030201")
    ]
    
    // Device Scan/State info
    fileprivate static var ScanDeviceNames : [String:FreeflyDevice] = [String:FreeflyDevice]()
    fileprivate var UART_CH_characteristics : [CBCharacteristic] = [CBCharacteristic]()
    fileprivate var State : BLE_FSS_States_e = BLE_FSS_States_e.fss_State_Reset
    fileprivate var active : Bool = false;
    fileprivate var wasActive : Bool = false;
    fileprivate var sharedCount : Double = 0
    
    // State Enumeration
    fileprivate enum BLE_FSS_States_e : Int
    {
        case fss_State_Reset = 0,
        fss_State_Wait_4_Connect,
        fss_State_BleRx_WaitforAllChls,
        fss_State_BleRx_Assemble,
        fss_State_BleTx
    }
    
    // iOS objects
    fileprivate var centralManager : CBCentralManager!
    fileprivate var connectingPeripheral : CBPeripheral!
    fileprivate var timer : Timer = Timer.init()
    //fileprivate var timerCount : Int = 0;
    
    // FILOs for Serial Data
    fileprivate let BleTx : FirstInLastOut<UInt8>  = FirstInLastOut.init()
    fileprivate let BleRx : FirstInLastOut<UInt8>  = FirstInLastOut.init()
    
    // Tx Management
    fileprivate var TxNumChls : UInt8 = 0          // Number of Channels (1 to 6)
    fileprivate var Tx_Msg_ChlFlags : [UInt8] = [UInt8](repeating: 0, count: NUM_OF_CHLS)
    fileprivate var Tx_BuildMsgsDone : Bool = false
    fileprivate var TxBuf : [Array] = [Array](repeating: [UInt8](repeating: 0, count: 21), count: NUM_OF_CHLS)
    fileprivate var TxBufLen : [UInt8] = [UInt8](repeating: 0, count: NUM_OF_CHLS) //byte[] TxBufLen = new byte[NUM_OF_CHLS];
    fileprivate var TxTimout : Int = 0;
    
    // Rx Management
    fileprivate var RxNumChls : UInt8 = 0        // Number of Channels (1 to 6)
    fileprivate var Rx_Msg_ChlFlags :[UInt8] = [UInt8](repeating: 0, count: NUM_OF_CHLS)
    fileprivate var RxBuf : [Array] = [Array](repeating: [UInt8](repeating: 0, count: 20), count: NUM_OF_CHLS)
    fileprivate var RxBufLen : [Int] = [Int](repeating: 0, count: NUM_OF_CHLS)
    
    
    
    
    //========================== Public calls from UI ===============================
    
    //
    // Add a byte to the TX stream
    //
    func sendByte(_ b : UInt8) {
        objc_sync_enter(self) //thread safety
        BleTx.add(b)
        objc_sync_exit(self)
    }
    
    //
    // Send a broadcast containing connection event
    //
    static func raiseEvent(_ ef : QX.Event.Flavor) {
        let dict:[String: Float] = [QX.C_KEY: Float(ef.rawValue)]
        NotificationCenter.default.post(name: QX.E_KEY, object: nil, userInfo: dict)
        if(ef == QX.Event.Flavor.DISCONNECTED) {
            QX.connected = false
            QX.logonState = QX.LogStates.LOGGED_OFF
        }
    }
    
    //
    //  Get a copy of the list of active scanned device names
    //  Static func is safe to call from UI even if backend is not initialized.
    //
    static func getAvailableDevices() -> [String:FreeflyDevice] {
        
        var list = [String : FreeflyDevice]()
        for device in ScanDeviceNames {
            if (device.value.isActive()) { list.updateValue(device.value, forKey: device.key) }
        }
        return list;
    }
    
    //
    //  Get last selected device name
    //  static func is safe to call from UI even if backend is not initialized.
    //
    static func getLastSelected() -> String {
        if let val = UserDefaults.standard.object(forKey: PERSIST_NAME) {
            return String(val as! String)
        }
        return ""
    }
    
    //
    //  Kill thread and do any cleanup - called on S.finish
    //
    func stopThread() {
        
        // ensure we are not scanning for devices
        centralManager.stopScan()
        
        clearConnectingPeripheralSilent()
        
        timer.invalidate()
        print("FFS stopThread")
    }
    
    //
    // Call to initiate disconnect/re-connect
    //
    func resetConnection() {
        print("FFS resetConnection")
        clearConnectingPeripheral()
    }
    
    //
    // Select Device for Connection from the overall device list (nil disconnects)
    //
    func resetConnect(_ newDevice : String)
    {
        print("FFS resetConnection with \(newDevice)")
        
        setPersistantDeviceName(newDevice)
        
        if (newDevice == "") {
            clearConnectingPeripheral();
        } else {
            // if it is in our list
            if let device = BTLE.ScanDeviceNames[newDevice] {
                
                sharedCount = CON_FAIL_TICK_OFFSET
                centralManager.stopScan() // stop looking for devices
                
                connectingPeripheral = device.peripheral  // connect
                connectingPeripheral.delegate = self
                centralManager.connect(connectingPeripheral, options: nil)
            }
        }
    }
    
    
    private func setPersistantDeviceName(_ name : String) {
        UserDefaults.standard.set(name, forKey: BTLE.PERSIST_NAME)
        UserDefaults.standard.synchronize()
    }
    
    
    //===========================   BTLE & FSS Calls  ===============================
    
    //
    //  Start the timer and get centralManaer on startup
    //
    override init() {
        super.init()
        timer = Timer.scheduledTimer(timeInterval: TICK1, target: self, selector: #selector(self.timerTick), userInfo: nil, repeats: true)
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    // central call for clean connectivity close
    fileprivate func clearConnectingPeripheral() {
        
        clearConnectingPeripheralSilent()
        
        BTLE.raiseEvent(QX.Event.Flavor.DISCONNECTED)
        
        // Start looking for next time (wait 3 seconds to prevent UI threadding issues)
        Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.startPeripheralServiceScan), userInfo: nil, repeats: false)
    }
    
    // disconnect without message to ui or starting new scan
    fileprivate func clearConnectingPeripheralSilent() {
        
        active = false
        
        if(connectingPeripheral == nil) { return }
        
        usleep(5000) //5 ms to ensure current operation is complete
        
        for characteristic :CBCharacteristic in UART_CH_characteristics {
            connectingPeripheral.setNotifyValue(false , for: characteristic)
        }
        
        centralManager.cancelPeripheralConnection(connectingPeripheral)
    }
    
    //
    // Called when Manager launches or BT switched on/off
    //
    func centralManagerDidUpdateState(_ central: CBCentralManager){
        
        if(DBG_VERBOSE) { print("centralManagerDidUpdateState") }
        if (centralManager.state == .poweredOff) {
            active = false
            print(" central.state == .PoweredOff ")
            return
        } else {
            startPeripheralServiceScan()
        }
    }
    
    // Start looking for freefly devices
    @objc fileprivate func startPeripheralServiceScan() {
        // scan for all devices
        // centralManager.scanForPeripheralsWithServices(nil, options: [ CBCentralManagerScanOptionAllowDuplicatesKey: false ] )
        // scan for freefly devices
        centralManager.scanForPeripherals(withServices: [UART_SERVICE_UUID], options: [ CBCentralManagerScanOptionAllowDuplicatesKey: false ] )
        
        if(DBG_VERBOSE) { print("scanning request sent") }
    }
    
    //
    // Timer for state machine, debug, and rssi workaround
    //
    @objc func timerTick() {
        
        // toggle scan on even seconds to ensure RSSI values are updated
        if (!(active)) {
            if (sharedCount > CON_FAIL_TICK_OFFSET) {
                if(sharedCount > CON_FAIL_TICK_OFFSET + (TIMEOUT_TICK)) {
                    sharedCount = 0
                    if(DBG_VERBOSE) {
                        print(" --- Conneciton delayed.  IOS Sometimes takes 3:20 to connect.  Restarting manager for faster response.")
                    }
                    centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
                    resetConnection()
                }
            } else if(sharedCount > TIMEOUT_TICK && centralManager.isScanning) {
                sharedCount = 0
                centralManager.stopScan()
                startPeripheralServiceScan()
                
                // update timeout
                for  d in BTLE.ScanDeviceNames.values {
                    let newD = FreeflyDevice(name: d.name ,peripheral: d.peripheral,rssiValue: d.rssiValue, timeout: d.timeout + 1)
                    BTLE.ScanDeviceNames.updateValue(newD, forKey: d.name)
                    if (newD.isTimingOut()) { BTLE.raiseEvent(QX.Event.Flavor.LIST_CHANGE) }
                    //print(" \(d.name) \(d.timeout) \(d.rssiValue)")
                }
                
            }
            sharedCount += TICK1
        }
        
        BLE_FSS_SM()
        
    }
    
    
    
    //
    // Peripherals found - store in list or connect if appropriate
    //
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if(DBG_VERBOSE) { print ("didDiscoverPeripheral [\(peripheral.name as Optional)] RSSI \(RSSI) ") }
        
        let device = FreeflyDevice(name: peripheral.name!,peripheral: peripheral,rssiValue: RSSI.intValue, timeout: 0)
        if (device.isRssiOk()) {
            BTLE.ScanDeviceNames.updateValue(device , forKey: peripheral.name!)
        }
        
        if (!(active)) {
            
            // let the conneciton UI know
            BTLE.raiseEvent(QX.Event.Flavor.LIST_CHANGE)
            
            // connect if this is the saved device
            if (BTLE.getLastSelected() == peripheral.name) {
                print("last sel \(BTLE.getLastSelected())  \(peripheral.name)")
                resetConnect(peripheral.name!)
            }
        }
    }
    
    //
    // Peripheral active - Get the Service
    //
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil) // get peripherals services
    }
    
    //
    // Periperal disconnected
    //
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        print("didDisconnectPeripheral error=\(error?.localizedDescription as Optional)")
        
        BTLE.raiseEvent(QX.Event.Flavor.DISCONNECTED)
        
    }
    
    //
    // Ask for characteristics
    //
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if(DBG_VERBOSE) { print("peripheral didDiscoverServices [\(peripheral.services as Optional)] with error=[\(error?.localizedDescription as Optional)]") }
        
        if (error != nil) {
            active = false
        }
        else {
            for service in (peripheral.services as [CBService]?)!{
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    //
    // Store discovered characteristics
    //
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if(DBG_VERBOSE)  { print("peripheral didDiscoverCharacteristicsForService [\(service.uuid)] with error=[\(error?.localizedDescription as Optional)]") }
        
        if (error != nil) {
            active = false
        } else {
            for i in 0 ..< BTLE.NUM_OF_CHLS {
                for characteristic in service.characteristics! {
                    if characteristic.uuid == UART_CH_CHAR_UUIDS[i] {
                        
                        if(DBG_VERBOSE) { print("storing characteristic \(characteristic.uuid) in UART_CH_characteristics[\(i)] ") }
                        
                        // Store the Characteristic
                        UART_CH_characteristics.insert(characteristic, at: i)
                        
                        // Register
                        peripheral.delegate = self
                        
                        // Setup Nofitication for RX
                        peripheral.setNotifyValue(true, for: characteristic as CBCharacteristic)
                    }
                }
            }
            QX.connected = true
            BTLE.raiseEvent(QX.Event.Flavor.CONNECTED)
            State = BLE_FSS_States_e.fss_State_Reset
            active = true
        }
    }
    
    //
    // Notification state changed
    //
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        if (characteristic.isNotifying) {
            print("Notification began on %@", characteristic.uuid);
        }
    }
    
    //
    // Send Data via Notification
    //
    private func fss_send(_ data : [UInt8] , len : Int , ch : Int)
    {
        if (!(active)) { return }
        
        // Create a Buffer from the data
        let cb : CBCharacteristic = UART_CH_characteristics[ch]  //WriteValueAsync(Buf, GattWriteOption.WriteWithoutResponse);
        let nsdata = Data(bytes: UnsafePointer<UInt8>(data as [UInt8]), count: len)
        connectingPeripheral?.writeValue(nsdata, for: cb, type: CBCharacteristicWriteType.withoutResponse)
        
        // Send Flag
        Tx_Msg_ChlFlags[ch] = 1;
    }
    
    //
    // Result of send attempt (only works with CBCharacteristicWriteType.withresponse)
    //
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if(DBG_VERBOSE) { print ("didWriteValueForCharacteristic \(characteristic.uuid) result \(error?.localizedDescription as Optional)") }
        
    }
    
    //
    // BTLE values recieved - send for processing
    //
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if(DBG_VERBOSE) { print("didUpdateValueForCharacteristic \(characteristic.value!) ID \(characteristic.uuid)"); }
        
        // Get the Channel #
        for ch in 0 ..< BTLE.NUM_OF_CHLS
        {
            if (characteristic.uuid == UART_CH_CHAR_UUIDS[ch])
            {
                
                if (characteristic.value == nil) {
                    objc_sync_exit(self)
                    return
                }
                
                let data : Data = characteristic.value!
                
                // Put the length in an array
                RxBufLen[ch] = data.count
                
                // Put Char Value in Array
                for i in 0 ..< data.count  {
                    var d: UInt8 = 0
                    (data as NSData).getBytes(&d, range: NSRange(location: i, length: 1))
                    RxBuf[ch][i] = d
                }
                
                if (ch == 0) { RxNumChls = UInt8(RxBuf[0][0]) }
                
                // Set Flag
                Rx_Msg_ChlFlags[ch] = 1;
                break;
            }
        }
        
        objc_sync_exit(self)
    }
    
    //
    // Reset the Tx Counters and State
    //
    fileprivate func fss_tx_vars_reset()
    {
        TxNumChls = 0;
        for ch in 0 ..< BTLE.NUM_OF_CHLS
        {
            TxBufLen[ch] = 0;
            Tx_Msg_ChlFlags[ch] = 0;
        }
    }
    
    //
    // Reset the Rx Counters and State
    //
    fileprivate func fss_rx_vars_reset()
    {
        RxNumChls = 0;
        for ch in 0 ..< BTLE.NUM_OF_CHLS
        {
            RxBufLen[ch] = 0;
            Rx_Msg_ChlFlags[ch] = 0;
        }
    }
    
    //
    // BLE State Machine: Call this function in a task loop to handle FSS Comms
    //
    fileprivate func BLE_FSS_SM()
    {
        
        objc_sync_enter(self)
        
        // Overall State Machine - Handle Connections and RX/TX Control
        switch (State)
        {
        //===================================
        case BLE_FSS_States_e.fss_State_Reset:
            fss_tx_vars_reset();
            fss_rx_vars_reset();
            
            State = BLE_FSS_States_e.fss_State_Wait_4_Connect;
            break;
            
        //===================================
        case BLE_FSS_States_e.fss_State_Wait_4_Connect:
            
            // When active, Start in the Tx State
            if (active)
            {
                State = BLE_FSS_States_e.fss_State_BleTx;
            }
            break;
            
        //===================================
        case BLE_FSS_States_e.fss_State_BleRx_WaitforAllChls:
            
            // Rx a group of BLE messages once the number of channels is known, and all channels have been received
            if (RxNumChls > 0)
            {
                var all_rxd = 1;
                for i in 0 ..< Int(RxNumChls)
                {
                    if (Rx_Msg_ChlFlags[i] != 1)
                    {
                        all_rxd = 0;
                    }
                }
                if (all_rxd == 1)
                {
                    State = BLE_FSS_States_e.fss_State_BleRx_Assemble;
                }
            }
            
            // If Connection is lost, reset
            if (active == false)
            {
                State = BLE_FSS_States_e.fss_State_Reset;
            }
            break;
            
        //===================================
        case BLE_FSS_States_e.fss_State_BleRx_Assemble:
            
            // Reassembles data recieved in parallel back to serial, and puts it into the UART Tx Buffer
            
            // Handle the first message's data:
            for i in 1 ..< RxBufLen[0]
            {
                BleRx.add(RxBuf[0][i]);   // Buffer Rx Data
            }
            
            // Handle the additional channels data:
            for ch : Int in 1  ..< Int(RxNumChls)
            {
                
                for i : Int in 0 ..< RxBufLen[ch]
                {
                    BleRx.add(RxBuf[ch][i]);   // Buffer Rx Data
                }
            }
            
            // Send data to QX_Lib
            while (!(BleRx.isEmpty())) {
                QX_RxData( BleRx.get()! )
            }
            
            fss_tx_vars_reset();   // Reset the Counters and States
            
            State = BLE_FSS_States_e.fss_State_BleTx;     // change state back to Tx
            
            // If Connection is lost, reset
            if (active == false)
            {
                State = BLE_FSS_States_e.fss_State_Reset;
            }
            
            break;   // Rx Finished!
            
        //===================================
        case BLE_FSS_States_e.fss_State_BleTx:
            
            fss_rx_vars_reset();   // Reset the Counters and States
            
            TxBufLen[0] = 1;       // Length is at least 1 since byte 0 is the channel byte
            TxNumChls = 1;         // Always Send at Least 1 Message
            Tx_BuildMsgsDone = false;    // Flag for notifying buffer empty
            
            // Build the First Notify Message (up to 19 bytes)
            for n : Int in 1 ..< 20
            {
                if (BleTx.size() > 0)
                {
                    TxBuf[0][n] = BleTx.get()!;
                    TxBufLen[0] += 1;
                }
                else
                {
                    Tx_BuildMsgsDone = true;
                    break;
                }
            }
            
            // Keep adding data if availible
            if (Tx_BuildMsgsDone == false)
            {
                // Build Up to 5 Additional Messages (6 total)
                for ch in 1 ..< BTLE.NUM_OF_CHLS
                {
                    // Up to 20 Bytes per Message
                    for n in 0 ..< 20
                    {
                        if (BleTx.size() > 0)
                        {
                            TxBuf[ch][n] = BleTx.get()!;
                            TxBufLen[ch] += 1;
                        }
                        else
                        {
                            Tx_BuildMsgsDone = true;
                            break;
                        }
                    }
                    
                    // If the message has data, we will send this channel
                    if (TxBufLen[ch] > 0)
                    {
                        TxNumChls += 1;
                    }
                    
                    // No more data left, don't add more channels
                    if (Tx_BuildMsgsDone)
                    {
                        break;
                    }
                }
            }
            
            // Add the final message count into the first byte of the first message
            TxBuf[0][0] = TxNumChls;
            
            // Send 1 to 6 Messages (Keep sending until they succeed or the connection is lost)
            TxTimout = 0;
            for ch in 0 ..< Int(TxNumChls)
            {
                
                //print("sending=", ch)
                fss_send(TxBuf[Int(ch)], len: Int(TxBufLen[ch]), ch: ch);
                if (active == false)     // If disconnected, give up
                {
                    break;
                }
            }
            
            State = BLE_FSS_States_e.fss_State_BleRx_WaitforAllChls;   // change state back to Rx
            
            // If Connection is lost, reset
            if (active == false)
            {
                State = BLE_FSS_States_e.fss_State_Reset;
            }
            
            break;   // Tx Finished!
            
        }   // End of State Machine Switch
        
        objc_sync_exit(self)
        
    }   // End of BLE_FSS_SM function
}


// Map a value between ranges
func map(_ x:Int, in_min:Int, in_max:Int, out_min:Int, out_max:Int) -> Int{
    return Int(map(Float(x), in_min: Float(in_min), in_max: Float(in_max), out_min: Float(out_min), out_max: Float(out_max), clamped: false))
}

func map(_ x:Float, in_min:Float, in_max:Float, out_min:Float, out_max:Float, clamped:Bool) -> Float{
    var output = (((x - in_min) * (out_max - out_min) / (in_max - in_min)) + out_min)
    if clamped {
        if out_max < output {
            output = out_max
        }else if output < out_min{
            output = out_min
        }
    }
    return output
}

// FILO for storing bytes
class FirstInLastOut<T> {
    
    public typealias Element = T
    fileprivate var s : Int = 0
    fileprivate var first: Item<Element>
    fileprivate var last: Item<Element>
    
    public init () {
        last = Item(nil)
        first = last
    }
    
    func size() -> Int {
        return s
    }
    
    func add (_ value: Element) {
        last.next = Item(value)
        last = last.next!
        s += 1
    }
    
    func get () -> Element? {
        if let new = first.next {
            s -= 1
            first = new
            return new.value
        } else {
            return nil
        }
    }
    
    func isEmpty() -> Bool {
        return first === last
    }
    
    
}

class Item<T> {
    let value: T!
    var next: Item?
    init(_ new: T?) {
        self.value = new
    }
}







