//
//  TrelloList.swift
//  App
//
//  Created by didi on 2019/3/11.
//

import Foundation
import Vapor
import FluentSQLite


final class TrelloList: SQLiteStringModel {
    var id: String?
    var name: String
    var closed: Bool
    var idBoard: String
    var pos: Int32
}

extension TrelloList: Content {
}
