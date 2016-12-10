//
//  NetServiceStreams.swift
//  NetService
//
//  Created by Rene Hexel on 10/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
//#if os(Linux)

import CoreFoundation
import Foundation

public class DNSSDNetServiceInputStream: InputStream {
    var cfStream: CFReadStream

    /// Initialise from a `CFReadStream`
    ///
    /// - Parameter stream: CoreFoundation read stream to initialise from
    public init(_ stream: CFReadStream) {
        cfStream = stream
        super.init(data: Data())
    }

    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        return CFReadStreamRead(cfStream, buffer, CFIndex(len))
    }

    public override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }

    public override var hasBytesAvailable: Bool {
        return CFReadStreamHasBytesAvailable(cfStream)
    }

    public override func open() {
        CFReadStreamOpen(cfStream)
    }

    public override func close() {
        CFReadStreamClose(cfStream)
    }

    public override var streamStatus: Status {
        let status = CFReadStreamGetStatus(cfStream)
        return Stream.Status(rawValue: unsafeBitCast(status, to: UInt.self))!
    }
}


public class DNSSDNetServiceOutputStream: OutputStream {
    var cfStream: CFWriteStream

    public init(_ stream: CFWriteStream) {
        cfStream = stream
        super.init(toMemory: ())
    }


    // writes the bytes from the specified buffer to the stream up to len bytes. Returns the number of bytes actually written.
    public override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        return  CFWriteStreamWrite(cfStream, buffer, len)
    }

    // returns YES if the stream can be written to or if it is impossible to tell without actually doing the write.
    public override var hasSpaceAvailable: Bool {
        return CFWriteStreamCanAcceptBytes(cfStream)
    }

    public override func open() {
        CFWriteStreamOpen(cfStream)
    }

    public override func close() {
        CFWriteStreamClose(cfStream)
    }

    public override var streamStatus: Status {
        let status = CFWriteStreamGetStatus(cfStream)
        return Stream.Status(rawValue: unsafeBitCast(status, to: UInt.self))!
    }

    public override func property(forKey key: PropertyKey) -> Any? {
        return key.rawValue.withCString {
            guard let k = CFStringCreateWithCString(kCFAllocatorDefault, $0, CFStringBuiltInEncodings.UTF8.rawValue) else {
                return nil
            }
            return CFWriteStreamCopyProperty(cfStream, CFStreamPropertyKey(rawValue: k))
        }
    }

    public override func setProperty(_ property: Any?, forKey key: PropertyKey) -> Bool {
        return key.rawValue.withCString {
            guard let k = CFStringCreateWithCString(kCFAllocatorDefault, $0, CFStringBuiltInEncodings.UTF8.rawValue) else {
                return false
            }
            return CFWriteStreamSetProperty(cfStream, CFStreamPropertyKey(rawValue: k), property as AnyObject)
        }
    }
}
