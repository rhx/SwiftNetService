//
//  NetService.swift
//  NetService
//
//  Created by René Hexel on 8/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
import CDNS_SD
import Foundation

let timerInterval = TimeInterval(0.25)

/// Swift implementation of the ZeroConf NetService API
open class SwiftNetService {
    /// Delegate receiving resolution, monitoring, or publishing events.
    weak open var delegate: SwiftNetServiceDelegate?

    /// Name of the service discovered or published.
    open var name: String { return _name }
    var _name: String

    /// Type of the service discovered or published.
    open var type: String { return _type }
    var _type: String

    /// Domain of the service discovered or published.
    open var domain: String { return _domain }
    var _domain: String

    /// Name of the computer hosting the service
    open var hostName: String?

    /// Port associated with the resolved service or `-1` if not resolved yet.
    open var port: Int { return _port }
    var _port: Int

    /// Addresses associated with the service returned as an
    /// array of Data containing a single `sockaddr` each.
    open var adresses: [Data]! { return [] }

    /// Pointer to the underlying DNS service
    var sd: DNSServiceRef?

    /// Runloop to run on
    var runLoop: RunLoop?

    /// Runloop mode to run in
    var runLoopMode = RunLoopMode.defaultRunLoopMode

    /// Timer associated with the service
    var timer: Timer! {
        get {
            if _timer == nil {
                weak var weakSelf: SwiftNetService? = self
                _timer = Timer(fire: Date(timeIntervalSinceNow: timerInterval), interval: timerInterval, repeats: true) {
                    guard let this = weakSelf else {
                        $0.invalidate()
                        return
                    }
                    this.fire($0)
                }
            }
            return _timer
        }
        set { _timer = newValue }
    }
    var _timer: Timer?

    /// Last DNSService error received
    var lastError = Int(kDNSServiceErr_NoError)

    /// Error dictionary associated with the last error
    var errorDictionary: [String : NSNumber] {
        return [:]
    }

    /// Designated intialiser for publishing the availability of a service
    /// on the network.
    ///
    /// - Parameters:
    ///   - domain: Service domain.  Pass an empty string for all domains.
    ///   - type: The type of the service, such as "_ssh._tcp".
    ///   - name: Hostname for the service.
    ///   - port: Listening port.  Use `-1` for auto-selecting a port.
    public init(domain: String, type: String, name: String, port: Int32 = -1) {
        _domain = domain
        _type = type
        _name = name
        _port = Int(port)
    }

    /// Deallocate service ref
    deinit {
        if let sd = sd {
            DNSServiceRefDeallocate(sd)
        }
    }

    open func schedule(in aRunLoop: RunLoop, forMode mode: RunLoopMode = .defaultRunLoopMode) {
        runLoop = aRunLoop
        runLoopMode = mode
        _ = timer               // make sure timer is set up
    }

    open func remove(from aRunLoop: RunLoop, forMode mode: RunLoopMode = .defaultRunLoopMode) {
        if let timer = _timer {
            _timer = nil
            timer.fireDate = Date()
            timer.invalidate()
        }
        runLoop = nil
    }

    /// Timer callback
    ///
    /// - Parameter timer: the timer that fired
    func fire(_ timer: Timer) {
        guard let sd = sd else {
            return
        }
        let fd = DNSServiceRefSockFD(sd)
        guard fd >= 0 else {
            return
        }
        let ev = Int16(POLLIN)
        var pollFD = pollfd(fd: fd, events: ev, revents: 0)
        guard poll(&pollFD, 1, 0) > 0 else {
            return
        }
        lastError = Int(DNSServiceProcessResult(sd))
    }

    /// Publish the net service.  This function returns immediately.
    ///
    /// - Parameter options: publishing options
    open func publish(options: SwiftNetService.Options = []) {
        if let sd = sd {
            DNSServiceRefDeallocate(sd)
            self.sd = nil
        }
        let this = Unmanaged.passRetained(self).toOpaque()
        let port = UInt16(_port < 0 ? 0 : _port).bigEndian
        lastError = Int(DNSServiceRegister(&sd, 0, 0, _name, _type, _domain, nil, port, 0, nil, { (sdRef: DNSServiceRef?, flags: DNSServiceFlags, err: DNSServiceErrorType, name: UnsafePointer<Int8>?, regType: UnsafePointer<Int8>?, domain: UnsafePointer<Int8>?, context: UnsafeMutableRawPointer?) in
            guard let context = context else { fatalError("DNSServiceRegister callback without context") }
            let this = Unmanaged<SwiftNetService>.fromOpaque(context).takeRetainedValue()
            if let name = name, let n = String(validatingUTF8: name) { this._name = n }
            if let type = regType, let t = String(validatingUTF8: type) { this._type = t }
            if let domain = domain, let d = String(validatingUTF8: domain) { this._domain = d }
            this.lastError = Int(err)
            guard this.lastError == kDNSServiceErr_NoError else {
                this.delegate?.netService(this, didNotPublish: this.errorDictionary)
                return
            }
            this.delegate?.netServiceDidPublish(this)
        }, this))
        guard lastError == kDNSServiceErr_NoError else {
            delegate?.netService(self, didNotPublish: errorDictionary)
            return
        }
    }

    /// Netservice publishing options.
    public struct Options: OptionSet {
        public typealias RawValue = UInt

        /// Raw, unsigned integer value of the option set
        public var rawValue: UInt

        /// Designated initialiser
        ///
        /// - Parameter rawValue: raw value of option combinations.
        public init(rawValue: RawValue) { self.rawValue = rawValue }

        /// Suppress renaming in the event of a collision.
        public static var noAutoRename: Options {
            return Options(rawValue: 1 << 0)
        }

        /// Start a TCP listener on the specified port
        public static var listenForConnections: Options {
            return Options(rawValue: 1 << 0)
        }
    }

    /// Start a service resolution with a given timeout
    ///
    /// - Parameter timeout: maximum duration of the service resolution
    open func resolve(withTimeout timeout: TimeInterval = 5) {
        if let sd = sd {
            DNSServiceRefDeallocate(sd)
            self.sd = nil
        }
        let this = Unmanaged.passRetained(self).toOpaque()
        lastError = Int(DNSServiceResolve(&sd, 0, 0, _name, _type, _domain, { (sdRef: DNSServiceRef?, flags: DNSServiceFlags, interfaceIndex: UInt32, err: DNSServiceErrorType, name: UnsafePointer<Int8>?, host: UnsafePointer<Int8>?, port: UInt16, len: UInt16, txt: UnsafePointer<UInt8>?, context: UnsafeMutableRawPointer?) in
            guard let context = context else { fatalError("DNSServiceResolve callback without context") }
            let this = Unmanaged<SwiftNetService>.fromOpaque(context).takeRetainedValue()
            if let name = name, let n = String(validatingUTF8: name) { this._name = n }
            if let host = host, let h = String(validatingUTF8: host) { this.hostName = h }
            this.lastError = Int(err)
            guard this.lastError == kDNSServiceErr_NoError else {
                this.delegate?.netService(this, didNotResolve: this.errorDictionary)
                return
            }
            this.delegate?.netServiceDidResolveAddress(this)
        }, this))
        guard lastError == kDNSServiceErr_NoError else {
            delegate?.netService(self, didNotResolve: errorDictionary)
            return
        }
        weak var weakSelf: SwiftNetService? = self
        _ = Timer(fire: Date(timeIntervalSinceNow: timeout), interval: timeout, repeats: false) {
            guard let this = weakSelf else {
                $0.invalidate()
                return
            }
            if let sd = this.sd {
                DNSServiceRefDeallocate(sd)
                this.sd = nil
            }
            this.delegate?.netService(self, didNotResolve: [:])
        }
    }

    /// Net services error code dictionary key
    open static let errorCode = "NSNetServicesErrorCode"
    /// Net services error domain dictionary key
    open static let errorDomain = "NSNetServicesErrorDomain"
}
