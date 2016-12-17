//
//  NetServiceStreams.swift
//  NetService
//
//  Created by Rene Hexel on 10/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
import CoreFoundation
import Foundation
import Dispatch

#if os(Linux)
    private let utf8 = CFStringEncoding(kCFStringEncodingUTF8)
    private func CFStreamPropertyKey(rawValue: CFString) -> CFString {
        return rawValue
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

    func closeAll() {
        close(Int32(self))
    }
}

public class DNSSDNetServiceInputStream: InputStream {
    var sock: CFSocketNativeHandle
    var dispatchSource: DispatchSourceRead?
    var status = Status.open

    /// Initialise from a `CFSocketNativeHandle`
    ///
    /// - Parameter socket: Already connected socket to initialise from
    public init(_ socket: CFSocketNativeHandle) {
        sock = socket
        super.init(data: Data())
    }

    deinit {
        sock.closeAll()
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

    /// Schedule the input stream in the given run loop
    ///
    /// - Parameters:
    ///   - runLoop: needs to be `RunLoop.main`
    ///   - mode: runloop mode to use (ignored)
    public override func schedule(in runLoop: RunLoop, forMode mode: RunLoopMode = .defaultRunLoopMode) {
        guard runLoop == RunLoop.main else {
            print("Alternate run loops are not supported")
            return
        }
        guard dispatchSource == nil else { return }
        let source = DispatchSource.makeReadSource(fileDescriptor: Int32(sock))
        dispatchSource = source
        source.setEventHandler { [weak self] in
            guard let source = self else {
                print("nil self, bailing out")
                return
            }
            print("Dispatch read source event triggered")
        }
        source.resume()
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
