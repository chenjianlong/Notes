//
//  AudioAttachmentViewController.swift
//  Notes-iOS
//
//  Created by chenjianlong on 2017/10/19.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit
import AVFoundation

class AudioAttachmentViewController: UIViewController, AttachmentViewer, AVAudioPlayerDelegate {
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    
    var audioPlayer : AVAudioPlayer?
    var audioRecorder : AVAudioRecorder?

    var attachmentFile: FileWrapper?
    var document: Document?
    
    @IBAction func recordTapped(_ sender: Any) {
        beginRecording()
    }
    
    @IBAction func playTapped(_ sender: Any) {
        beginPlaying()
    }
    
    @IBAction func stopTapped(_ sender: Any) {
        stopRecording()
        stopPlaying()
    }
    
    func updateButtionState() {
        if self.audioRecorder?.isRecording == true ||
            self.audioPlayer?.isPlaying == true {
            // playing or recording
            self.recordButton.isHidden = true
            self.playButton.isHidden = true
            self.stopButton.isHidden = false
        } else if self.audioPlayer != nil {
            self.recordButton.isHidden = true
            self.stopButton.isHidden = true
            self.playButton.isHidden = false
        } else {
            // not in recording
            self.playButton.isHidden = true
            self.stopButton.isHidden = true
            self.recordButton.isHidden = false
        }
    }
    
    func beginRecording() {
        AVAudioSession.sharedInstance().requestRecordPermission {
            (hasPermission) -> Void in
            guard hasPermission else {
                let title = "Microphone access required"
                let message = "We need the microphone to record audio."
                let cancelButton = "Cancel"
                let settingsButton = "Settings"
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: cancelButton, style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: settingsButton, style: .default, handler: {
                    (action) in
                    if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                    }
                }))
                
                self.present(alert, animated: true, completion: nil)
                return
            }
        }
        
        let fileName = self.attachmentFile?.preferredFilename ?? "Recording \(Int(arc4random())).wav"
        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            self.audioRecorder = try AVAudioRecorder(url: temporaryURL, settings: [:])
            self.audioRecorder?.record()
        } catch let error as NSError {
            NSLog("Failed to start recording: \(error)")
        }
        
        self.updateButtionState()
    }
    
    func stopRecording() {
        guard let recorder = self.audioRecorder else {
            return
        }
        
        recorder.stop()
        self.audioPlayer = try? AVAudioPlayer(contentsOf: recorder.url)
        updateButtionState()
    }
    
    func beginPlaying() {
        self.audioPlayer?.delegate = self
        self.audioPlayer?.play()
        updateButtionState()
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        updateButtionState()
    }
    
    func prepareAudioPlayer() {
        guard let data = self.attachmentFile?.regularFileContents else {
            return
        }
        
        do {
            self.audioPlayer = try AVAudioPlayer(data: data)
        } catch let error as NSError {
            NSLog("Failed to prepare audio player: \(error)")
        }
        
        self.updateButtionState()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        updateButtionState()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if attachmentFile != nil {
            prepareAudioPlayer()
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        } catch let error as NSError {
            NSLog("Error preparing for recording! \(error)")
        }
        
        updateButtionState()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let recorder = self.audioRecorder {
            do {
                attachmentFile = try self.document?.addAttachmentAtURL(url: recorder.url)
                prepareAudioPlayer()
            } catch let error as NSError {
                NSLog("Failed to attach recording: \(error)")
            }
        }
    }
}
