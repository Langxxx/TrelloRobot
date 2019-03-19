//
//  TrelloBoard.swift
//  App
//
//  Created by didi on 2019/3/19.
//

import Vapor
import FluentMySQL


struct TrelloBoard: RequestDecodable, Decodable {
    let id: String
    let name: String
    let url: String
}
