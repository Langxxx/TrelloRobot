//
//  TrelloMember.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor
import FluentMySQL

final class TrelloMemberResponse: Content {
    var id: String?
    var username: String
    var fullName: String

}

final class TrelloMember: MySQLModel, Migration, Content {
    var id: Int?

    var memberID: String
    var username: String
    var fullName: String
    var idBoard: String

    init(memberID: String, username: String, fullname: String, idBoard: String) {
        self.memberID = memberID
        self.username = username
        self.fullName = fullname
        self.idBoard = idBoard
    }
}
