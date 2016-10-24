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





//
//  RichMedia.swift
//  Tracker
//

import Foundation

public class RichMedia : BusinessObject {
    
    private var _isBuffering: Bool?
    private var _isEmbedded: Bool?
    
    /// Rich media broadcast type
    public enum BroadcastMode: String {
        case Clip = "clip"
        case Live = "live"
    }
    
    /// Rich media hit status
    @objc public enum RichMediaAction: Int {
        case Play = 0
        case Pause = 1
        case Stop = 2
        case Move = 3
        case Refresh = 4
    }
    
    /// Player instance
    var player: MediaPlayer
    
    /// Refresh timer
    var timer: NSTimer?
    
    /// Media is buffering
    public var isBuffering: Bool = false {
        didSet {
            _isBuffering = isBuffering
        }
    }
    
    /// Media is embedded in app
    public var isEmbedded: Bool = false {
        didSet {
            _isEmbedded = isEmbedded
        }
    }
    
    /// Media is live or clip
    var broadcastMode: BroadcastMode = BroadcastMode.Clip
    
    /// Media name
    public var name: String = ""
    
    /// First chapter
    public var chapter1: String?
    
    /// Second chapter
    public var chapter2: String?
    
    /// Third chapter
    public var chapter3: String?
    
    /// Level 2
    public var level2: Int = 0
    
    /// Refresh Duration
    var refreshDuration: Int = 5
    
    /// Action
    public var action: RichMediaAction = RichMediaAction.Play
    
    /// Web domain 
    public var webdomain: String?
   
    init(player: MediaPlayer) {
        self.player = player
        
        super.init(tracker: player.tracker)
    }
    
    private func getActionEnumRawValue(value: Int) -> String {
        switch value {
        case 0:
            return "play"
        case 1:
            return "pause"
        case 2:
            return "stop"
        case 3:
            return "move"
        case 4:
            return "refresh"
        default:
            return "play"
        }
    }
    
    /// Set parameters in buffer
    override func setEvent() {
        let encodingOption = ParamOption()
        encodingOption.encode = true
        
        self.tracker.setParam("p", value: buildMediaName(), options: encodingOption)
        
        self.tracker.setParam("plyr", value: player.playerId)
        
        self.tracker.setParam("m6", value: broadcastMode.rawValue)
        
        self.tracker.setParam("a", value: getActionEnumRawValue(action.rawValue))
        
        if let optIsEmbedded = self._isEmbedded {
            self.tracker.setParam("m5", value: optIsEmbedded ? "ext" : "int")
        }
        
        if self.level2 > 0 {
            self.tracker.setParam("s2", value: level2)
        }
        
        if(action == RichMediaAction.Play) {
            if let optIsBuffering = self._isBuffering {
                self.tracker.setParam("buf", value: optIsBuffering ? 1 : 0)
            }
            
            if let optIsEmbedded = self._isEmbedded {
                if (optIsEmbedded) {
                    if let optWebDomain = self.webdomain {
                        self.tracker.setParam("m9", value: optWebDomain)
                    }
                } else {
                    if TechnicalContext.screenName != "" {
                        self.tracker.setParam("prich", value: TechnicalContext.screenName, options: encodingOption)
                    }
                    
                    if TechnicalContext.level2 > 0 {
                        self.tracker.setParam("s2rich", value: TechnicalContext.level2)
                    }
                }
            }
            
        }
    }
    
    /// Media name building
    func buildMediaName() -> String {
        var mediaName = chapter1 == nil ? "" : chapter1! + "::"
        mediaName = chapter2 ==  nil ? mediaName : mediaName + chapter2! + "::"
        mediaName = chapter3 ==  nil ? mediaName : mediaName + chapter3! + "::"
        mediaName += name
        
        return mediaName
    }
    
    /**
    Send hit when media is played
    Refresh is enabled with default duration
    */
    public func sendPlay() {
        self.action = RichMediaAction.Play
        
        self.tracker.dispatcher.dispatch([self])
        
        self.initRefresh()
    }
    
    /**
    Send hit when media is played
    Refresh is enabled if resfreshDuration is not equal to 0
    - parameter resfreshDuration: duration between refresh hits
    */
    public func sendPlay(refreshDuration: Int) {
        
        self.action = RichMediaAction.Play
        
        self.tracker.dispatcher.dispatch([self])
        
        if (refreshDuration != 0) {
            if (refreshDuration > 5) {
                self.refreshDuration = refreshDuration
            }
            self.initRefresh()
        }
        
    }
    
    /**
    Send hit when media is paused
    */
    public func sendPause(){
        
        if let timer = self.timer {
            if timer.valid {
                timer.invalidate()
                self.timer = nil
            }
        }
        
        self.action = RichMediaAction.Pause
        
        self.tracker.dispatcher.dispatch([self])
    }
    
    /**
    Send hit when media is stopped
    */
    public func sendStop() {
        
        if let timer = self.timer {
            if timer.valid {
                timer.invalidate()
                self.timer = nil
            }
        }
        
        self.action = RichMediaAction.Stop
        
        self.tracker.dispatcher.dispatch([self])
    }
    
    /**
    Send hit when media cursor position is moved
    */
    public func sendMove() {
        self.action  = RichMediaAction.Move
        
        self.tracker.dispatcher.dispatch([self])
    }
    
    /// Start the refresh timer
    func initRefresh() {
        if self.timer == nil {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(
                NSTimeInterval(self.refreshDuration), target: self, selector: #selector(RichMedia.sendRefresh), userInfo: nil, repeats: true)
        }
        
    }
    
    /// Medthod called on the timer tick
    @objc func sendRefresh() {
        self.action = RichMediaAction.Refresh
        
        self.tracker.dispatcher.dispatch([self])
    }
    
}
