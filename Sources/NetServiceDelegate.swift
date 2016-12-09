//
//  NetServiceDelegate.swift
//  NetService
//
//  Created by René Hexel on 8/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
import Foundation

public protocol SwiftNetServiceDelegate: class {
    /// Function that gets called when the netservice is about to publish a service
    ///
    /// - Parameter sender: `NetService` instance invoking this callback
    func netServiceWillPublish(_ sender: NetService)

    /// Function that gets called when the netservice has published a service
    ///
    /// - Parameter sender: `NetService` instance invoking this callback
    func netServiceDidPublish(_ sender: NetService)

    /// Function that gets called when the netservice failed to publish a service
    ///
    /// - Parameters:
    ///   - sender: `NetService` instance invoking this callback
    ///   - errorDict: dictionary containing the corresponding error information
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber])

    /// Function that gets called when the netservice is about to resolve a service
    ///
    /// - Parameter sender: `NetService` instance invoking this callback
    func netServiceWillResolve(_ sender: NetService)

    /// Function that gets called when the netservice has resolved a service
    ///
    /// - Parameter sender: `NetService` instance invoking this callback
    func netServiceDidResolveAddress(_ sender: NetService)

    /// Function that gets called when the netservice failed to resolve a service
    ///
    /// - Parameters:
    ///   - sender: `NetService` instance invoking this callback
    ///   - errorDict: dictionary containing the corresponding error information
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber])

    /// Function that gets called when the netservice has stopped
    ///
    /// - Parameter sender: `NetService` instance invoking this callback
    func netServiceDidStop(_ sender: NetService)

    /// Function that gets called when the netservice has updated its TXT record
    ///
    /// - Parameter sender: `NetService` instance invoking this callback
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data)

    /// - Parameters:
    ///   - sender: NetService` instance invoking this callback
    ///   - inputStream: input stream associated with the connection
    ///   - outputStream: output stream associated with the connection
    func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream)
}

/// Default implementations for the SwiftNetServiceDelegate callback functions
public extension SwiftNetServiceDelegate {
    func netServiceWillPublish(_ sender: NetService) {}
    func netServiceDidPublish(_ sender: NetService) {}
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {}
    func netServiceWillResolve(_ sender: NetService) {}
    func netServiceDidResolveAddress(_ sender: NetService) {}
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {}
    func netServiceDidStop(_ sender: NetService) {}
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {}
    func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {}
}
