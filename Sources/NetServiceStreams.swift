//
//  NetServiceStreams.swift
//  NetService
//
//  Created by Rene Hexel on 10/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
import CoreFoundation
import Foundation

#if os(Linux)
    private let utf8 = CFStringEncoding(kCFStringEncodingUTF8)
    private func CFStreamPropertyKey(rawValue: CFString) -> CFString {
        return rawValue
    }

    /// Set bind the given socket to the given address and listen for connections
    ///
    /// - Parameters:
    ///   - s: `CFSocket` to bind
    ///   - address: IP address to bind to (Data containing a `struct sockaddr*`)
    /// - Returns: `0` if successful, an error code otherwise
    @discardableResult
    func CFSocketSetAddress(_ s: CFSocket, _ address: CFData!) -> CFSocketError {
        let len = socklen_t(CFDataGetLength(address))
        guard address != nil,
              len >= socklen_t(MemoryLayout<sockaddr_in>.size),
              CFSocketIsValid(s) else {
                return CFSocketError(kCFSocketError)
        }
        let sock = CFSocketGetNative(s)
        guard let a = CFDataGetBytePtr(address) else { return CFSocketError(kCFSocketError) }
        let addr = UnsafeRawPointer(a).assumingMemoryBound(to: sockaddr.self)
        guard bind(sock, addr, len) == 0,
            listen(sock, 256) == 0 else { return CFSocketError(errno) }
        return CFSocketError(kCFSocketSuccess)
    }
#else
    private let utf8 = CFStringBuiltInEncodings.UTF8.rawValue
#endif

extension CFSocketNativeHandle {
    func get(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        return Int(read(Int32(self), buffer, ssize_t(len)))
    }

    func put(_ buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        return Int(write(Int32(self), buffer, ssize_t(len)))
    }

    func closeReadingEnd() {
        shutdown(Int32(self), Int32(SHUT_RD))
    }

    func closeWritingEnd() {
        shutdown(Int32(self), Int32(SHUT_WR))
    }

    func has(events: Int16 = Int16(POLLIN)) -> Bool {
        var fd = pollfd(fd: Int32(self), events: events, revents: 0)
        return poll(&fd, 1, 0) > 0
    }
}

public class DNSSDNetServiceInputStream: InputStream {
    var sock: CFSocketNativeHandle
    var status = Status.open

    /// Initialise from a `CFSocketNativeHandle`
    ///
    /// - Parameter socket: Already connected socket to initialise from
    public init(_ socket: CFSocketNativeHandle) {
        sock = socket
        super.init(data: Data())
    }

    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        return sock.get(buffer, maxLength: len)
    }

    public override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }

    public override var hasBytesAvailable: Bool {
        return sock.has(events: Int16(POLLIN))
    }

    public override func open() {
    }

    public override func close() {
        sock.closeReadingEnd()
        status = Status.closed
    }

    public override var streamStatus: Status {
        return status
    }
}


public class DNSSDNetServiceOutputStream: OutputStream {
    var sock: CFSocketNativeHandle
    var status = Status.open
    var properties = Dictionary<PropertyKey, PropertyValue>()

    #if os(Linux)
        public typealias PropertyValue = AnyObject

        public required init(toMemory: ()) {
            sock = -1
            super.init(toMemory: ())
        }
    #else
        public typealias PropertyValue = Any
    #endif

    public init(_ socket: CFSocketNativeHandle) {
        sock = socket
        super.init(toMemory: ())
    }


    // writes the bytes from the specified buffer to the stream up to len bytes. Returns the number of bytes actually written.
    public override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        return sock.put(buffer, maxLength: len)
    }

    // returns YES if the stream can be written to or if it is impossible to tell without actually doing the write.
    public override var hasSpaceAvailable: Bool {
        return sock.has(events: Int16(POLLOUT))
    }

    public override func open() {
    }

    public override func close() {
        sock.closeReadingEnd()
        status = Status.closed
    }

    public override var streamStatus: Status {
        return status
    }

    public override func property(forKey key: PropertyKey) -> PropertyValue? {
        return properties[key]
    }

    public override func setProperty(_ property: PropertyValue?, forKey key: PropertyKey) -> Bool {
        let rv = super.setProperty(property, forKey: key)
        properties[key] = property
        return rv
    }
}
