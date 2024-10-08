import Foundation
import AVFoundation

class AudioPlayer: NSObject {
    private var seekToStart = true
    private var stopWhenCompleted = false
    private var timeObserverToken: Any?
    private var finishMode: FinishMode = FinishMode.stop
    private var updateFrequency = 200
    var plugin: SwiftAudioWaveformsPlugin
    var playerKey: String
    var flutterChannel: FlutterMethodChannel
    private var player: AVPlayer?
    
    init(plugin: SwiftAudioWaveformsPlugin, playerKey: String, channel: FlutterMethodChannel) {
        self.plugin = plugin
        self.playerKey = playerKey
        self.flutterChannel = channel
    }
    
    func preparePlayer(path: String?, volume: Double?, updateFrequency: Int?, result: @escaping FlutterResult) {
        if let path = path, !path.isEmpty {
            self.updateFrequency = updateFrequency ?? 200
            guard let audioUrl = URL(string: path) else {
                result(FlutterError(code: Constants.audioWaveforms, message: "Failed to initialise URL from provided audio file", details: "If path contains `file://` try removing it"))
                return
            }
            let playerItem = AVPlayerItem(url: audioUrl)
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = false
            player?.volume = Float(volume ?? 1.0)
            result(true)
        } else {
            result(FlutterError(code: Constants.audioWaveforms, message: "Audio file path can't be empty or null", details: nil))
        }
    }
    
    func startPlayer(result: @escaping FlutterResult, finishMode: Int?) {
        if let finishMode = finishMode {
            switch finishMode {
            case 0:
                self.finishMode = FinishMode.loop
            case 1:
                self.finishMode = FinishMode.pause
            default:
                self.finishMode = FinishMode.stop
            }
        } else {
            self.finishMode = FinishMode.stop
        }
        player?.play()
        // Set the rate if needed
        player?.rate = player?.rate ?? 1.0
        // Add observer for playback completion
        NotificationCenter.default.addObserver(self, selector: #selector(audioPlayerDidFinishPlaying(_:)), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        startListening()
        result(true)
    }
    
    @objc func audioPlayerDidFinishPlaying(_ notification: Notification) {
        var finishType = 2
        switch self.finishMode {
        case .loop:
            player?.seek(to: CMTime.zero)
            player?.play()
            finishType = 0
        case .pause:
            player?.pause()
            stopListening()
            finishType = 1
        case .stop:
            player?.pause()
            player?.seek(to: CMTime.zero)
            stopListening()
            finishType = 2
        }
        plugin.flutterChannel.invokeMethod(Constants.onDidFinishPlayingAudio, arguments: [Constants.finishType: finishType, Constants.playerKey: playerKey])
    }
    
    func pausePlayer(result: @escaping FlutterResult) {
        stopListening()
        player?.pause()
        result(true)
    }
    
    func stopPlayer(result: @escaping FlutterResult) {
        stopListening()
        player?.pause()
        player?.seek(to: CMTime.zero)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        result(true)
    }
    
    func release(result: @escaping FlutterResult) {
        stopListening()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        player = nil
        result(true)
    }
    
    func getDuration(_ type: DurationType, _ result: @escaping FlutterResult) throws {
        if type == .Current {
            let currentTime = player?.currentTime() ?? CMTime.zero
            let seconds = CMTimeGetSeconds(currentTime)
            if seconds.isFinite {
                let ms = seconds * 1000
                result(Int(ms))
            } else {
                result(0)
            }
        } else {
            if let duration = player?.currentItem?.asset.duration {
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite {
                    let ms = seconds * 1000
                    result(Int(ms))
                } else {
                    result(0)
                }
            } else {
                result(0)
            }
        }
    }
    
    func setVolume(_ volume: Double?, _ result: @escaping FlutterResult) {
        player?.volume = Float(volume ?? 1.0)
        result(true)
    }
    
    func setRate(_ rate: Double?, _ result: @escaping FlutterResult) {
        if let rate = rate {
            player?.rate = Float(rate)
            result(true)
        } else {
            result(false)
        }
    }
    
    func seekTo(_ time: Int?, _ result: @escaping FlutterResult) {
        if let time = time {
            let cmTime = CMTime(seconds: Double(time) / 1000, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: cmTime)
            result(true)
        } else {
            result(false)
        }
    }
    
    func startListening() {
        let interval = CMTime(seconds: Double(updateFrequency) / 1000, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                let ms = seconds * 1000
                self.flutterChannel.invokeMethod(Constants.onCurrentDuration, arguments: [Constants.current: Int(ms), Constants.playerKey: self.playerKey])
            } else {
                self.flutterChannel.invokeMethod(Constants.onCurrentDuration, arguments: [Constants.current: 0, Constants.playerKey: self.playerKey])
            }
        }
    }
    
    func stopListening() {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    deinit {
        stopListening()
        NotificationCenter.default.removeObserver(self)
    }
}
