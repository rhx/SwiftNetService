//
//  NetService.swift
//  NetService
//
//  Created by René Hexel on 8/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
import CDNS_SD
import Foundation

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

    /// Port associated with the resolved service or `-1` if not resolved yet.
    open var port: Int { return _port }
    var _port: Int

    /// Addresses associated with the service returned as an
    /// array of Data containing a single `sockaddr` each.
    open var adresses: [Data]! { return [] }

    /// Pointer to the underlying DNS service
    var sd: DNSServiceRef?

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

    /// Publish the net service.  This function returns immediately.
    ///
    /// - Parameter options: publishing options
    open func publish(options: SwiftNetService.Options = []) {
        let this = Unmanaged.passRetained(self).toOpaque()
        let port = UInt16(_port < 0 ? 0 : _port).bigEndian
        let rv = DNSServiceRegister(&sd, 0, 0, _name, _type, _domain, nil, port, 0, nil, { (sdRef: DNSServiceRef?, flags: DNSServiceFlags, err: DNSServiceErrorType, name: UnsafePointer<Int8>?, regType: UnsafePointer<Int8>?, domain: UnsafePointer<Int8>?, context: UnsafeMutableRawPointer?) in
            guard let context = context else { fatalError("DNSServiceRegister callback without context") }
            let this = Unmanaged<SwiftNetService>.fromOpaque(context).takeRetainedValue()
            if let name = name, let n = String(validatingUTF8: name) { this._name = n }
            if let type = regType, let t = String(validatingUTF8: type) { this._type = t }
            if let domain = domain, let d = String(validatingUTF8: domain) { this._domain = d }
        }, this)
        if Int(rv) != kDNSServiceErr_NoError {
            print("Error \(rv) registering service '\(name)' of type '\(type)' in domain '\(domain)'")
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
}
