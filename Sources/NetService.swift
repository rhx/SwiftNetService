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
open class DNSSDNetService {
    /// Dictionary containing error information
    public typealias ErrorDictionary = [ String : Any ]

    /// Delegate receiving resolution, monitoring, or publishing events.
    weak open var delegate: DNSSDNetServiceDelegate?

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

    /// The service is currently resolving
    var isResolving = false

    /// The service is currently publishing
    var isPublishing = false

    /// Addresses associated with the service returned as an
    /// array of Data containing a single `sockaddr` each.
    open var adresses: [Data]! { return [] }

    /// TXT record data
    var txtRecord: Data?

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
                weak var weakSelf: DNSSDNetService? = self
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
        set {
            _timer?.fireDate = Date()
            _timer?.invalidate()
            _timer = newValue
        }
    }
    var _timer: Timer?

    /// Last DNSService error received
    var lastError = Int(kDNSServiceErr_NoError)

    /// Error dictionary associated with the last error
    var errorDictionary: ErrorDictionary {
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

    /// Return the TXT record associated with the net service
    ///
    /// - Returns: TXT record or `nil`
    open func txtRecordData() -> Data? { return txtRecord }

    /// Update the TXT record of the net service
    ///
    /// - Parameter recordData: new Data to publish or `nil` to remove
    /// - Returns: `true` unless an error was detected
    open func setTXTRecord(_ recordData: Data?) -> Bool {
        txtRecord = recordData
        return true
    }

    /// Schedule the net service in the given run loop.
    ///
    /// - Parameters:
    ///   - aRunLoop: run loop to schedule this net service in
    ///   - mode: run loop mode
    open func schedule(in aRunLoop: RunLoop, forMode mode: RunLoopMode = .defaultRunLoopMode) {
        runLoop = aRunLoop
        runLoopMode = mode
        startMonitoring()
    }

    /// Remove the net service from the given run loop
    ///
    /// - Parameters:
    ///   - aRunLoop: run loop to remove the net service from
    ///   - mode: run loop mode
    open func remove(from aRunLoop: RunLoop, forMode mode: RunLoopMode = .defaultRunLoopMode) {
        stopMonitoring()
        runLoop = nil
    }

    /// Start monitoring for TXT record updates
    open func startMonitoring() {
        _ = timer               // Set up timer
    }

    /// Stop monitoring for events such as TXT record updates
    open func stopMonitoring() {
        timer = nil
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
    open func publish(options: DNSSDNetService.Options = []) {
        stop()
        let this = Unmanaged.passRetained(self).toOpaque()
        let port = UInt16(_port < 0 ? 0 : _port).bigEndian
        lastError = Int(DNSServiceRegister(&sd, 0, 0, _name, _type, _domain, nil, port, 0, nil, { (sdRef: DNSServiceRef?, flags: DNSServiceFlags, err: DNSServiceErrorType, name: UnsafePointer<Int8>?, regType: UnsafePointer<Int8>?, domain: UnsafePointer<Int8>?, context: UnsafeMutableRawPointer?) in
            guard let context = context else { fatalError("DNSServiceRegister callback without context") }
            let this = Unmanaged<DNSSDNetService>.fromOpaque(context).takeRetainedValue()
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
        isPublishing = true
        delegate?.netServiceWillPublish(self)
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
        stop()
        let this = Unmanaged.passRetained(self).toOpaque()
        lastError = Int(DNSServiceResolve(&sd, 0, 0, _name, _type, _domain, { (sdRef: DNSServiceRef?, flags: DNSServiceFlags, interfaceIndex: UInt32, err: DNSServiceErrorType, name: UnsafePointer<Int8>?, host: UnsafePointer<Int8>?, port: UInt16, len: UInt16, txt: UnsafePointer<UInt8>?, context: UnsafeMutableRawPointer?) in
            guard let context = context else { fatalError("DNSServiceResolve callback without context") }
            let this = Unmanaged<DNSSDNetService>.fromOpaque(context).takeRetainedValue()
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
        weak var weakSelf: DNSSDNetService? = self
        _ = Timer(fire: Date(timeIntervalSinceNow: timeout), interval: timeout, repeats: false) {
            guard let this = weakSelf else {
                $0.invalidate()
                return
            }
            if let sd = this.sd {
                DNSServiceRefDeallocate(sd)
                this.sd = nil
            }
            let dict: DNSSDNetService.ErrorDictionary = [
                DNSSDNetService.errorDomain : DNSSDNetService.netServiceErrorDomain,
                DNSSDNetService.errorCode   : DNSSDNetService.ErrorCode.timeoutError
            ]
            this.delegate?.netService(self, didNotResolve: dict)
        }
        isResolving = true
        delegate?.netServiceWillResolve(self)
    }

    /// Halt a service that is publishing or resolving
    open func stop() {
        if let sd = sd {
            DNSServiceRefDeallocate(sd)
            self.sd = nil
            let dict: DNSSDNetService.ErrorDictionary = [
                DNSSDNetService.errorDomain : DNSSDNetService.netServiceErrorDomain,
                DNSSDNetService.errorCode   : DNSSDNetService.ErrorCode.cancelledError
            ]
            if isResolving {
                isResolving = false
                delegate?.netService(self, didNotResolve: dict)
            }
            if isPublishing {
                isPublishing = false
                delegate?.netService(self, didNotPublish: dict)
            }
        }
    }

    /// Create TXT record data from a dictionary of key/value pairs
    ///
    /// - Parameter txtDictionary: dictionary of keys and values for TXT records
    /// - Returns: TXT record data or `nil` if no conversion is possible
    open class func data(fromTXTRecord txtDictionary: [String : Data]) -> Data! {
        let txt: String? = txtDictionary.reduce("") {
            guard let txt = $0, let val = String(data: $1.value, encoding: .utf8) else { return nil }
            return txt + (txt.isEmpty ? "" : "\n") + $1.key + "=" + val
        }
        return txt?.data(using: .utf8)
    }

    /// Return a doctionary of key/value paris extracted from the TXT record data provided
    ///
    /// - Parameter txtData: record to parse
    /// - Returns: dictionary of key/value pairs
    open class func dictionary(fromTXTRecord txtData: Data) -> [String : Data] {
        guard let s = String(data: txtData, encoding: .utf8) else {
                return [:]
        }
        let records = NSString(string: s).components(separatedBy: "\n")
        let kvs = records.map { (r: String) -> (String, String) in
            let kv = NSString(string: r).components(separatedBy: "=")
            guard kv.count > 1 else { return (r, "") }
            return (kv[0], kv[1])
        }
        var dict: [String : Data] = [:]
        for kv in kvs {
            guard let val = kv.1.data(using: .utf8) else { continue }
            dict[kv.0] = val
        }
        return dict
    }

    // MARK: - Error Codes
    public enum ErrorCode: Int {
        /// An unknown error occurred
        case unknownError = -72000
        /// Name already in use
        case collisionError = -72001
        /// Service could not be found
        case notFoundError = -72002
        /// Cannot process the request at this time
        case activityInProgress = -72003
        /// An invalid argument was used creating this instance
        case badArgumentError = -72004
        /// Client cancelled the action
        case cancelledError = -72005
        /// Improperly configured service
        case invalidError = -72006
        /// A timeout occurred publishing or resolving a service
        case timeoutError = -72007
    }
    /// Net services error code dictionary key
    open static let errorCode = "NSNetServicesErrorCode"
    /// Net services error domain dictionary key
    open static let errorDomain = "NSNetServicesErrorDomain"
    /// NSNetService error domain
    open static let netServiceErrorDomain = "NSNetService"
}
