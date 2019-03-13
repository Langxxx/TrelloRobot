//
//  TrelloMember.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor
import FluentMySQL

final class BoardMembers: Content {
    let id: String
    let members: [TrelloMember]
}

final class TrelloMember: MySQLStringModel, Migration, Content {
    var id: String?
    var username: String
}
