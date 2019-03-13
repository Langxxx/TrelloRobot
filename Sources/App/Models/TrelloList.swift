//
//  TrelloList.swift
//  App
//
//  Created by didi on 2019/3/11.
//

import Vapor
import FluentMySQL


final class TrelloList: MySQLStringModel, Migration {
    var id: String?
    var name: String
    var closed: Bool
    var idBoard: String
    var pos: Int
}

extension TrelloList: Content {
    
}
