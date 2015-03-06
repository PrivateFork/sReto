//
//  InTransfer.swift
//  sReto
//
//  Created by Julian Asamer on 26/07/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import Foundation

/**
* An InTransfer represents a data transfer from a remote peer to the local peer. The connection class generates InTransfer instances when a remote peer sends data.
*/
@objc(RTInTransfer) public class InTransfer: Transfer {
    // MARK: Events
    
    // Called when the transfer completes with the full data received. Buffers the data in memory until the transfer is complete. Alternative to onPartialData. If both are set, onPartialData is used.
    public var onCompleteData: ((Transfer, NSData) -> ())? = nil
    // Called whenever data is received. This method may be called multiple times, i.e. the data is not the full transfer. Exclusive alternative to onCompleteData.
    public var onPartialData: ((Transfer, NSData) -> ())? = nil
    
    // MARK: Internal
    func updateWithReceivedData(data: NSData) {
        if let onPartialData = self.onPartialData {
            onPartialData(self, data)
        } else if let onCompleteData = self.onCompleteData {
            if self.dataBuffer == nil { self.dataBuffer = NSMutableData(capacity: self.length) }
            dataBuffer?.appendData(data)
        } else {
            log(.High, error: "You need to set either onCompleteData or onPartialData on incoming transfers (affected instance: \(self))")
        }
        if onCompleteData != nil && onPartialData != nil { log(.Medium, warning: "You set both onCompleteData and onPartialData in \(self). Only onPartialData will be used.") }

        self.updateProgress(data.length)
    }
    
    var dataBuffer: NSMutableData? = nil
    
    override public func cancel() {
        self.manager?.cancel(self)
    }
    override func confirmEnd() {
        self.dataBuffer = nil
        
        self.onCompleteData = nil
        self.onPartialData = nil
        
        super.confirmEnd()        
    }
    override func confirmCompletion() {
        if let data = self.dataBuffer { self.onCompleteData?(self, data) }
    
        super.confirmCompletion()
    }
}