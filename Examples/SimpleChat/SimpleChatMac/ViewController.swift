//
//  ViewController.swift
//  SimpleChatMac
//
//  Created by Julian Asamer on 24/10/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, ChatRoomDelegate {
    @IBOutlet weak var displayName: NSTextField!
    @IBOutlet weak var messageTextField: NSTextField!
    
    dynamic let localPeer: LocalChatPeer
    dynamic var selectedPeer: ChatRoom?
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.localPeer = LocalChatPeer()
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        self.localPeer = LocalChatPeer()
        
        super.init(coder: coder)
        
        self.localPeer.chatRoomDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func start(sender: AnyObject) {
        self.localPeer.start(displayName.stringValue)
    }
    @IBAction func peerSelected(sender: NSComboBox) {
        if sender.indexOfSelectedItem == -1 {
            self.selectedPeer = nil
        } else {
            self.selectedPeer = self.localPeer.chatRooms[sender.indexOfSelectedItem]
        }
    }
    @IBAction func sendMessage(sender: AnyObject) {
        self.selectedPeer?.sendMessage(self.messageTextField.stringValue)
    }
    @IBAction func sendFile(sender: AnyObject) {
        if let path = getExistingFilePath() {
            self.selectedPeer?.sendFile(path)
        }
    }
    
    func getExistingFilePath() -> String? {
        let dialogue = NSOpenPanel()
        
        let result = dialogue.runModal()
        
        if result == NSFileHandlingPanelOKButton {
            let url = dialogue.URL
            return url?.path
        }
        
        return nil
    }
    func chatRoom(_: ChatRoom, pathForSavingFileWithName fileName: String) -> String? {
        let dialogue = NSSavePanel()
        dialogue.nameFieldStringValue = fileName
        let result = dialogue.runModal()
        
        if result == NSFileHandlingPanelOKButton {
            let url = dialogue.URL
            return url?.path
        }
        
        return nil
    }
    func chatRoom(_: ChatRoom, completedReceivingFileAtPath: String) {}
}

