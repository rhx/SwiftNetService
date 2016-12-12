//
//  NetServiceListener.swift
//  NetService
//
//  Created by Rene Hexel on 10/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
import CoreFoundation
import Foundation

#if os(Linux)
    extension CFSocketCallBackType {
        static var acceptCallBack: CFSocketCallBackType {
            return CFSocketCallBackType(kCFSocketAcceptCallBack)
        }
    }
#endif

private func createSockaddr4(_ port: UInt16) -> sockaddr_in {
    #if os(Linux)
        return sockaddr_in(sin_family: sa_family_t(AF_INET), sin_port: port, sin_addr: in_addr(s_addr: INADDR_ANY), sin_zero: (0,0,0,0,0,0,0,0))
    #else
        return sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size), sin_family: sa_family_t(AF_INET), sin_port: port, sin_addr: in_addr(s_addr: INADDR_ANY), sin_zero: (0,0,0,0,0,0,0,0))
    #endif
}

private func createSockaddr6(_ port: UInt16) -> sockaddr_in6 {
    var addr = sockaddr_in6()
    let size = MemoryLayout<sockaddr_in6>.size
    memset(&addr, 0, size)
    #if !os(Linux)
        addr.sin6_len = UInt8(size)
    #endif
    addr.sin6_family = sa_family_t(AF_INET6)
    addr.sin6_port = port
    return addr
}

extension DNSSDNetService {
    /// Listen for incoming IPv4 and IPv6 connections
    func listenForConnections() {
        let callback: CFSocketCallBack = { (sock: CFSocket?, type: CFSocketCallBackType, address: CFData?, data: UnsafeRawPointer?, info: UnsafeMutableRawPointer?) in
            guard type == .acceptCallBack else { return }
            guard let info = info else { fatalError("CFSocketCreate callback without info") }
            let this = Unmanaged<DNSSDNetService>.fromOpaque(info).takeRetainedValue()
            guard let delegate = this.delegate else { return }
            guard let socket = data?.assumingMemoryBound(to: CFSocketNativeHandle.self).pointee else { return }
            var readStream: Unmanaged<CFReadStream>?
            var writeStream: Unmanaged<CFWriteStream>?
            CFStreamCreatePairWithSocket(kCFAllocatorDefault, socket, &readStream, &writeStream)
            guard let r = readStream?.takeRetainedValue(),
                  let w = writeStream?.takeRetainedValue() else { return }
            let inputStream = DNSSDNetServiceInputStream(r)
            let outputStream = DNSSDNetServiceOutputStream(w)
            delegate.netService(this, didAcceptConnectionWith: inputStream, outputStream: outputStream)
        }
        let this = Unmanaged.passUnretained(self).toOpaque()
        var context = CFSocketContext(version: 0, info: this, retain: {
            guard let this = $0 else { return $0 }
            _ = Unmanaged<DNSSDNetService>.fromOpaque(this).retain()
            return $0
        }, release: {
            guard let this = $0 else { return }
            Unmanaged<DNSSDNetService>.fromOpaque(this).release()
        }, copyDescription: nil)
        let tcp = Int32(IPPROTO_TCP)
        #if os(Linux)
            let stream = Int32(SOCK_STREAM.rawValue)
            let accept = CFOptionFlags(kCFSocketAcceptCallBack)
        #else
            let stream = Int32(SOCK_STREAM)
            let accept = CFOptionFlags(CFSocketCallBackType.acceptCallBack.rawValue)
        #endif
        guard let v4socket = CFSocketCreate(kCFAllocatorDefault, PF_INET,  stream, tcp, accept, callback, &context) else {
            cancel(domain: NSPOSIXErrorDomain, error: errno)
            return
        }
        ipv4Socket = v4socket
        var ip4addr = createSockaddr4((port < 0 ? 0 : UInt16(port)).bigEndian)
        withUnsafeMutablePointer(to: &ip4addr) {
            let size = MemoryLayout<sockaddr_in>.size
            $0.withMemoryRebound(to: UInt8.self, capacity: size) {
                let ip4data = CFDataCreate(kCFAllocatorDefault, $0, size)
                CFSocketSetAddress(v4socket, ip4data)
            }
        }
        if let v6socket = CFSocketCreate(kCFAllocatorDefault, PF_INET6, stream, tcp, accept, callback, &context) {
            ipv6Socket = v6socket
            var ip6addr = createSockaddr6(ip4addr.sin_port)
            withUnsafeMutablePointer(to: &ip6addr) {
                let size = MemoryLayout<sockaddr_in6>.size
                $0.withMemoryRebound(to: UInt8.self, capacity: size) {
                    let ip6data = CFDataCreate(kCFAllocatorDefault, $0, size)
                    CFSocketSetAddress(v6socket, ip6data)
                }
            }
        }
        if port <= 0 {
            if UInt16(1).bigEndian != 1 {
                _port = Int(ip4addr.sin_port.byteSwapped)
            } else {
                _port = Int(ip4addr.sin_port)
            }
        }
        schedule(in: runLoop == nil ? RunLoop.current : runLoop!, forMode: runLoop == nil ? .defaultRunLoopMode : runLoopMode)
    }

    func addSocketsToRunLoop() {
        guard let runLoop = runLoop?.getCFRunLoop() else { return }
        #if os(Linux)
            let mode = kCFRunLoopCommonModes
        #else
            let mode = CFRunLoopMode.commonModes!
        #endif
        if let ipv4Socket = ipv4Socket {
            let source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv4Socket, 0);
            CFRunLoopAddSource(runLoop, source, mode)
        }
        if let ipv6Socket = ipv6Socket {
            let source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv6Socket, 0);
            CFRunLoopAddSource(runLoop, source, mode)
        }
    }

    func invaldidateSockets() {
        if let ipv4Socket = ipv4Socket { CFSocketInvalidate(ipv4Socket) }
        if let ipv6Socket = ipv6Socket { CFSocketInvalidate(ipv6Socket) }
    }
}
