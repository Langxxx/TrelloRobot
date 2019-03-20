//
//  TrelloBoard.swift
//  App
//
//  Created by didi on 2019/3/19.
//

import Vapor
import FluentMySQL

struct TrelloBoardResponseData: RequestDecodable, Decodable {
    let id: String
    let name: String
    let url: String

    let lists: [TrelloList]?
}

final class TrelloBoard: MySQLStringModel, Migration {
    var id: String?
    let name: String
    let url: String

    init(id: String, name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }
}

extension TrelloBoard {
    var lists: Children<TrelloBoard, TrelloList> {
        return children(\.idBoard)
    }

    var members: Children<TrelloBoard, TrelloMember> {
        return children(\.idBoard)
    }
}
