//
//  RoutingPackets.swift
//  sReto
//
//  Created by Julian Asamer on 23/08/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import Foundation

/** This enum represents the possible purposes of a direct connection - either to transmit routing information, or to be part of a user-requested routed connection. */
enum ConnectionPurpose: Int32 {
    case Unknown = 0
    /** Used for connections that are used to transmit routing metadata. */
    case RoutingConnection = 1
    /** Used for user-requested connections that are routed. */
    case RoutedConnection = 2
}

/** 
* The LinkHandshake packet is the first packet exchanged over a direct connection; it is sent by the establishing peer. It contains that peer's identifier and 
* the purpose of the connection. It is used by the establishDirectConnection and handleDirectConnection methods in the Router class.
*/
struct LinkHandshake: Packet {
    let peerIdentifier: UUID
    let connectionPurpose: ConnectionPurpose

    static func getType() -> PacketType { return PacketType.LinkHandshake }
    static func getLength() -> Int { return sizeof(Int32) + sizeof(UUID)*2 + sizeof(ConnectionPurpose) }
    
    static func deserialize(data: DataReader) -> LinkHandshake? {
        if !Packets.check(data: data, expectedType: getType(), minimumLength: getLength()) { return nil }
        
        let peerIdentifier = data.getUUID()
        let connectionPurpose = ConnectionPurpose(rawValue: data.getInteger())
        
        return connectionPurpose.map { LinkHandshake(peerIdentifier: peerIdentifier, connectionPurpose: $0) }
    }
    
    func serialize() -> NSData {
        let data = DataWriter(length: self.dynamicType.getLength())
        data.add(self.dynamicType.getType().rawValue)
        data.add(self.peerIdentifier)
        data.add(self.connectionPurpose.rawValue)
        return data.getData()
    }
}

/**
* The MulticastHandshake contains information relevant to establish a routed multi- or unicast connection.
* It is sent to each peer that is part of the route.
* It contains the identifier of the peer that originally established the peer, the set of destinations of the connection, and the direct connections that
* still need to be established structured as a tree (the nextHopTree). When a peer receives a MulticastHandshake, the nextHopTree is always rooted at that tree. 
* That node is expected to establish connections to all nodes that are its children in the nextHopTree.
*/
struct MulticastHandshake: Packet {
    static func getType() -> PacketType { return PacketType.MulticastHandshake }
    static func getMinimumLength() -> Int { return sizeof(Int32) + sizeof(UUID) }
    
    let sourcePeerIdentifier: UUID
    let destinationIdentifiers: Set<UUID>
    let nextHopTree: Tree<UUID>
    
    static func deserialize(data: DataReader) -> MulticastHandshake? {
        if !Packets.check(data: data, expectedType: getType(), minimumLength: getMinimumLength()) { return nil }
        
        let sourcePeerIdentifier = data.getUUID()
        let destinationsCount = Int(data.getInteger())
        
        if destinationsCount == 0 {
            println("Invalid MulticastHandshake: no destinations specified.")
            return nil
        }
        if data.checkRemaining(destinationsCount * sizeof(UUID)) == false {
            println("Invalid MulticastHandshake: not enough data to read destinations.")
            return nil
        }
        var destinations: Set<UUID> = []
        for i in 0..<destinationsCount { destinations += data.getUUID() }
        
        if let nextHopTree = deserializeNextHopTree(data) {
            return MulticastHandshake(sourcePeerIdentifier: sourcePeerIdentifier, destinationIdentifiers: destinations, nextHopTree: nextHopTree)
        } else {
            return nil
        }
    }

    func serialize() -> NSData {
        let data = DataWriter(length: self.dynamicType.getMinimumLength() + sizeof(Int32) + destinationIdentifiers.count * sizeof(UUID) + nextHopTree.size * (sizeof(Int32) + sizeof(UUID)))
        data.add(self.dynamicType.getType().rawValue)
        data.add(self.sourcePeerIdentifier)
        data.add(Int32(self.destinationIdentifiers.count))
        for destination in self.destinationIdentifiers { data.add(destination) }
        
        serializeNextHopTree(data, nextHopTree: self.nextHopTree)
        
        return data.getData()
    }
    
    static func deserializeNextHopTree(data: DataReader) -> Tree<UUID>? {
        if !data.checkRemaining(sizeof(UUID) + sizeof(Int32)) {
            println("Invalid MulticastHandshake: not enough data to read tree.")
            return nil
        }
        
        let identifier = data.getUUID()
        let subtreeCount = data.getInteger()
        var subtrees: Set<Tree<UUID>> = []
        
        for i in 0..<subtreeCount {
            if let child = deserializeNextHopTree(data) {
                subtrees += child
            } else {
                return nil
            }
        }
        
        return Tree(value: identifier, subtrees: subtrees)
    }
    
    func serializeNextHopTree(data: DataWriter, nextHopTree: Tree<UUID>) {
        data.add(nextHopTree.value)
        data.add(Int32(nextHopTree.subtrees.count))
        
        for subtree in nextHopTree.subtrees { serializeNextHopTree(data, nextHopTree: subtree) }
    }
}

/**
* This packet is used when establishing multicast connectinos to ensure that all destinations are actually connected.
* It only contains the sender's identifier and is sent by all peers once the hop connection establishment phase is complete.
*/
struct RoutedConnectionEstablishedConfirmationPacket: Packet {
    static func getType() -> PacketType { return PacketType.RoutedConnectionEstablishedConfirmation }
    static func getLength() -> Int { return sizeof(Int32) + sizeof(UUID) }
    
    let source: UUID
    
    static func deserialize(data: DataReader) -> RoutedConnectionEstablishedConfirmationPacket? {
        if !Packets.check(data: data, expectedType: getType(), minimumLength: getLength()) { return nil }
        return RoutedConnectionEstablishedConfirmationPacket(source: data.getUUID())
    }
    
    func serialize() -> NSData {
        let data = DataWriter(length: self.dynamicType.getLength())
        data.add(self.dynamicType.getType().rawValue)
        data.add(self.source)
        return data.getData()
    }
}