//
//  RequestDecodable+Extension.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor

extension Decodable where Self: RequestDecodable {
    static func decode(from req: Request) throws -> EventLoopFuture<Self> {
        let content = try req.content.decode(Self.self)
        return content
    }
}


extension Encodable where Self: RequestEncodable {
    
}
