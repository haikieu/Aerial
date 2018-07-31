//
//  AerialView.swift
//  Aerial
//
//  Created by John Coates on 10/22/15.
//  Copyright © 2015 John Coates. All rights reserved.
//

import Foundation
import ScreenSaver
import AVFoundation
import AVKit

@objc(AerialView)
class AerialView: ScreenSaverView {
    var playerLayer: AVPlayerLayer!
    var preferencesController: PreferencesWindowController?
    static var players: [AVPlayer] = [AVPlayer]()
    static var previewPlayer: AVPlayer?
    static var previewView: AerialView?
    
    var player: AVPlayer?
    var textView : NSTextView?
    var timer : Timer?
    
    static var sharingPlayers: Bool {
        let preferences = Preferences.sharedInstance
        return !preferences.differentAerialsOnEachDisplay
    }
    
    static var sharedViews: [AerialView] = []
    
    // MARK: - Shared Player
    
    static var singlePlayerAlreadySetup: Bool = false
    class var sharedPlayer: AVPlayer {
        struct Static {
            static let instance: AVPlayer = AVPlayer()
            static var _player: AVPlayer?
            static var player: AVPlayer {
                if let activePlayer = _player {
                    return activePlayer
                }

                _player = AVPlayer()
                return _player!
            }
        }
        
        return Static.player
    }
    
    // MARK: - Init / Setup
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        
        self.animationTimeInterval = 1.0 / 30.0
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    deinit {
        debugLog("deinit AerialView")
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        
        // set player item to nil if not preview player
        if player != AerialView.previewPlayer {
            player?.rate = 0
            player?.replaceCurrentItem(with: nil)
        }
        
        guard let player = self.player else {
            return
        }
        
        // Remove from player index
        
        let indexMaybe = AerialView.players.index(of: player)
        
        guard let index = indexMaybe else {
            return
        }
        
        AerialView.players.remove(at: index)
    }
    
    func setupPlayerLayer(withPlayer player: AVPlayer) {
        self.layer = CALayer()
        guard let layer = self.layer else {
            NSLog("Aerial Errror: Couldn't create CALayer")
            return
        }
        self.wantsLayer = true
        layer.backgroundColor = NSColor.black.cgColor
        layer.needsDisplayOnBoundsChange = true
        layer.frame = self.bounds
//        layer.backgroundColor = NSColor.greenColor().CGColor
        
        debugLog("setting up player layer with frame: \(self.bounds) / \(self.frame)")
        
        playerLayer = AVPlayerLayer(player: player)
        if #available(OSX 10.10, *) {
            playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        }
        playerLayer.autoresizingMask = [CAAutoresizingMask.layerWidthSizable, CAAutoresizingMask.layerHeightSizable]
        playerLayer.frame = layer.bounds
        layer.addSublayer(playerLayer)
    }
    
    func setup() {
        var localPlayer: AVPlayer?
        
        let notPreview = !isPreview
        
        if notPreview {
            // check if we should share preview's player
            let noPlayers = (AerialView.players.count == 0)
            let previewPlayerExists = (AerialView.previewPlayer != nil)
            if noPlayers && previewPlayerExists {
                localPlayer = AerialView.previewPlayer
            }
        } else {
            AerialView.previewView = self
        }
        
        if AerialView.sharingPlayers {
            AerialView.sharedViews.append(self)
        }
        
        if localPlayer == nil {
            if AerialView.sharingPlayers {
                if AerialView.previewPlayer != nil {
                    localPlayer = AerialView.previewPlayer
                } else {
                    localPlayer = AerialView.sharedPlayer
                }
            } else {
                localPlayer = AVPlayer()
            }
        }
        
        guard let player = localPlayer else {
            NSLog("Aerial Error: Couldn't create AVPlayer!")
            return
        }
        
        self.player = player
        
        if self.isPreview {
            AerialView.previewPlayer = player
        } else if !AerialView.sharingPlayers {
            // add to player list
            AerialView.players.append(player)
        }
        
        setupPlayerLayer(withPlayer: player)
        
        if AerialView.sharingPlayers && AerialView.singlePlayerAlreadySetup {
            self.playerLayer.player = AerialView.sharedViews[0].player
            return
        }
        
        AerialView.singlePlayerAlreadySetup = true
        
        ManifestLoader.instance.addCallback { videos in
            self.playNextVideo()
        }
        
        setupTextView()
        setTimer()
    }
    
    func setupTextView() {
        let frame = CGRect.init(origin: CGPoint.zero, size: CGSize.init(width: self.frame.width, height: 25))
        self.textView = NSTextView.init(frame: frame)
        self.addSubview(textView!)
        self.textView?.backgroundColor = NSColor.black.withAlphaComponent(0.5)
        self.textView?.alignment = .center
        self.textView?.textColor = NSColor.white.withAlphaComponent(0.9)
        self.textView?.autoresizingMask = [.viewWidthSizable]
        self.textView?.font = NSFont.labelFont(ofSize: 20)
        self.textView?.sizeToFit()
        self.textView?.isEditable = false
        self.textView?.isSelectable = false
        self.textView?.string = getRandomQuote()
    }
    
    static var quotes : [String] = [
        "To become proficient at anything we do actually need to repeat it until our brain and muscles reach a state of automation",
        "Stop doubting yourself... be bold",
        "if you keep doing something you like, you’ll only get better",
        "Don’t put off until tomorrow what we can do today",
        "Later equals never"
    ]
    
    func setTimer() {
        if #available(OSX 10.12, *) {
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { (timer) in
                self.timerIntervalTask(timer)
            })
        } else {
            // Fallback on earlier versions
        }
    }
    
    func timerIntervalTask(_ timer: Timer) {
        self.textView?.string = getRandomQuote()
    }
    var lastRandomSeed : Int = -1
    func getRandomQuote() -> String {
        
        var randomSeed : Int = -1
        
        repeat {
            randomSeed = Int.random(0..<AerialView.quotes.count)
        } while lastRandomSeed == randomSeed
        lastRandomSeed = randomSeed
        
        return AerialView.quotes[randomSeed]
    }
    
    // MARK: - AVPlayerItem Notifications
    
    func playerItemFailedtoPlayToEnd(_ aNotification: Notification) {
        NSLog("AVPlayerItemFailedToPlayToEndTimeNotification \(aNotification)")
        
        playNextVideo()
    }
    
    func playerItemNewErrorLogEntryNotification(_ aNotification: Notification) {
        NSLog("AVPlayerItemNewErrorLogEntryNotification \(aNotification)")
    }
    
    func playerItemPlaybackStalledNotification(_ aNotification: Notification) {
        NSLog("AVPlayerItemPlaybackStalledNotification \(aNotification)")
    }
    
    func playerItemDidReachEnd(_ aNotification: Notification) {
        debugLog("played did reach end")
        debugLog("notification: \(aNotification)")
        playNextVideo()

        debugLog("playing next video for player \(player)")
    }
    
    // MARK: - Playing Videos
    
    func playNextVideo() {
        let notificationCenter = NotificationCenter.default
        
        // remove old entries
        notificationCenter.removeObserver(self)
        
        let player = AVPlayer()
        // play another video
        let oldPlayer = self.player
        self.player = player
        self.playerLayer.player = self.player
        
        if self.isPreview {
            AerialView.previewPlayer = player
        }
        
        debugLog("Setting player for all player layers in \(AerialView.sharedViews)")
        for view in AerialView.sharedViews {
            view.playerLayer.player = player
        }
        
        if oldPlayer == AerialView.previewPlayer {
            AerialView.previewView?.playerLayer.player = self.player
        }
        
        let randomVideo = ManifestLoader.instance.randomVideo()
        
        guard let video = randomVideo else {
            NSLog("Aerial: Error grabbing random video!")
            return
        }
        let videoURL = video.url
        
        let asset = CachedOrCachingAsset(videoURL)
//        let asset = AVAsset(URL: videoURL)
        
        let item = AVPlayerItem(asset: asset)
        
        player.replaceCurrentItem(with: item)
        
        debugLog("playing video: \(video.url)")
        if player.rate == 0 {
            player.play()
        }
        
        guard let currentItem = player.currentItem else {
            NSLog("Aerial Error: No current item!")
            return
        }
        
        debugLog("observing current item \(currentItem)")
        notificationCenter.addObserver(self,
                                       selector: #selector(AerialView.playerItemDidReachEnd(_:)),
                                       name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                       object: currentItem)
        notificationCenter.addObserver(self,
                                       selector: #selector(AerialView.playerItemNewErrorLogEntryNotification(_:)),
                                       name: NSNotification.Name.AVPlayerItemNewErrorLogEntry,
                                       object: currentItem)
        notificationCenter.addObserver(self,
                                       selector: #selector(AerialView.playerItemFailedtoPlayToEnd(_:)),
                                       name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime,
                                       object: currentItem)
        notificationCenter.addObserver(self,
                                       selector: #selector(AerialView.playerItemPlaybackStalledNotification(_:)),
                                       name: NSNotification.Name.AVPlayerItemPlaybackStalled,
                                       object: currentItem)
        player.actionAtItemEnd = AVPlayerActionAtItemEnd.none
    }
    
    // MARK: - Preferences
    
    override func hasConfigureSheet() -> Bool {
        return true
    }
    
    override func configureSheet() -> NSWindow? {
        if let controller = preferencesController {
            return controller.window
        }
        
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
    
        preferencesController = controller
        return controller.window
    }
}

extension Int {
    
    static func random(_ range:Range<Int>) -> Int {
        return range.lowerBound + Int(arc4random_uniform(UInt32(range.upperBound - range.lowerBound)))
    }
}
