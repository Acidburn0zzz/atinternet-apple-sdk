/*
 This SDK is licensed under the MIT license (MIT)
 Copyright (c) 2015- Applied Technologies Internet SAS (registration number B 403 261 258 - Trade and Companies Register of Bordeaux – France)
 
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
 */

import Foundation

/// Class reponsible for sending events
public class SocketSender {
    
    /// Websocket
    var socket: SRWebSocket?
    
    /// askforlive
    var timer: NSTimer?
    
    /// askforlive every RECONNECT_INTERVAL
    let RECONNECT_INTERVAL: Double = 2.0
    
    /// delegate to handle incoming msg
    var socketHandler: SocketDelegate
    
    /// URL of the ws
    let URL: String
    
    /// handler for the different scenarios of pairing
    let liveManager: LiveNetworkManager
    
    /// Buffer used to save the App and the current Screen displayed
    var buffer = EventBuffer()
    
    /**
     *  Buffer used to handle the App and the current screen displayed in case of reconnections
     *  note : The App can be different at different time (orientation)
     */
    struct EventBuffer {
        var currentScreen: String = ""
        var currentApp: String {
            return App().description
        }
    }
    
    /// queue managing events
    var queue:Array<String> = []
    
    /**
     init
     
     - parameter liveManager: a live manager
     - parameter token:       a valid token
     
     - returns: SocketSender (should be a single instance)
     */
    init(liveManager: LiveNetworkManager, token: String) {
        //self.URL = "ws://172.20.23.145:5000/"+token
        //self.URL = "ws://tagsmartsdk.eu-west-1.elasticbeanstalk.com:5000/"+token
        self.URL = SmartTrackerConfiguration.sharedInstance.ebsEndpoint+token
        self.liveManager = liveManager
        self.socketHandler = SocketDelegate(liveManager: liveManager)
    }
    
    /**
     open the socket
     */
    func open() {
        if isConnected() || ATInternet.sharedInstance.defaultTracker.enableLiveTagging == false || socket?.readyState == SRReadyState.CONNECTING {
            return
        }
        print(URL)
        let url = NSURL(string: URL)
        socket = SRWebSocket(URL:url)
        socket?.delegate = socketHandler
        socket?.open()
    }
    
    /**
     Close socket
     */
    func close() {
        if isConnected() {
            socket?.close()
        }
    }
    
    /**
     check if the socket is connected
     
     - returns: the state of the connexion
     */
    private func isConnected() -> Bool {
        return (socket != nil) && (socket?.readyState == SRReadyState.OPEN)
    }
    
    func sendBuffer() {
        //assert(isConnected())
        //assert(self.liveManager.networkStatus == .Connected)
        socket?.send(buffer.currentApp)
        socket?.send(buffer.currentScreen)
    }
    
    /**
     send all events in the buffer list
     */
    func sendAll() {
        //assert(isConnected())
        //assert(self.liveManager.networkStatus == .Connected)
        while queue.count > 0 {
            self.sendFirst()
        }
    }
    
    /**
     send a JSON message to the server
     
     - parameter json: the message as a String (JSON formatted)
     */
    func sendMessage(json: String) {
        let eventName = JSON.parse(json)["event"].string
        // keep a ref to the last screen
        if eventName == "viewDidAppear" {
            buffer.currentScreen = json
            if self.liveManager.networkStatus == .Disconnected {
                return
            }
        }
        
        self.queue.append(json)
        if self.liveManager.networkStatus == .Connected {
            self.sendAll()
        }
    }
    
    /**
     Send a message even if not paired
     
     - parameter json: the message
     */
    func sendMessageForce(json: String) {
        if isConnected() {
            socket?.send(json)
        }
    }
    
    /**
     Ask for live with a timer so the pairing looks in real time
     */
    func startAskingForLive() {
        timer?.invalidate()
        timer = NSTimer(timeInterval: RECONNECT_INTERVAL, target: self, selector: #selector(SocketSender.sendAskingForLive), userInfo: nil, repeats: true)
        timer?.fire()
        NSRunLoop.mainRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
    }
    
    /**
     AskForLive - we force it because not currently in live
     */
    @objc func sendAskingForLive() {
        sendMessageForce(DeviceAskingForLive().description)
    }
    
    /**
     Stop the askforlive timer
     */
    func stopAskingForLive() {
        timer?.invalidate()
    }
    
    /**
     Send the first message (act as a FIFO)
     */
    private func sendFirst() {
        let msg = queue.first
        socket?.send(msg)
        self.queue.removeAtIndex(0)
    }
}
