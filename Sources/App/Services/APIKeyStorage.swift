//
//  APIKeyStorage.swift
//  App
//
//  Created by didi on 2019/3/11.
//

import Vapor

struct APIKeyStorage: Service {
    let trelloKey: String
    let trelloToken: String
}
