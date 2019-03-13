//
//  BCMessage.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor


final class BCMessage: Content {
    let subdomain: String
    let vchannel: String
    let sender: String
    let username: String
    let token: String
    let text: String
    let key: String
}
