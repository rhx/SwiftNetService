//
//  NetServiceDelegate.swift
//  NetService
//
//  Created by René Hexel on 8/12/16.
//  Copyright © 2016 René Hexel.  All rights reserved.
//
import Foundation

public protocol SwiftNetServiceDelegate: class {
}

protocol _NetServiceWillPublish {
    func netServiceWillPublish(_ sender: NetService)
}

protocol _NetServiceDidPublish {
    func netServiceDidPublish(_ sender: NetService)
}

protocol _NetServiceDidNotPublish {
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber])
}

protocol _NetServiceWillResolve {
    func netServiceWillResolve(_ sender: NetService)
}

protocol _NetServiceDidResolve {
    func netServiceDidResolveAddress(_ sender: NetService)
}

protocol _NetServiceDidNotResolve {
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber])
}

protocol _NetServiceDidStop {
    func netServiceDidStop(_ sender: NetService)
}

protocol _NetServiceDidUpdate {
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data)
}

protocol _NetServiceDidAccept {
    func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream)
}
