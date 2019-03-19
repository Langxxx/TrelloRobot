//
//  TrelloAPIConfig.swift
//  App
//
//  Created by didi on 2019/3/18.
//

import Vapor
import FluentMySQL


final class TrelloAPIConfig: MySQLModel {
    var id: Int?

    let robotToken: String
    var key: String
    var token: String

    var idBoard: String?

    init(robotToken: String, key: String, token: String) {
        self.robotToken = robotToken
        self.key = key
        self.token = token
    }
}



extension TrelloAPIConfig: MySQLMigration {
    static func prepare(on conn: MySQLConnection) -> Future<Void> {
        return MySQLDatabase.create(TrelloAPIConfig.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.robotToken)
            builder.field(for: \.token)
            builder.field(for: \.key)
            builder.field(for: \.idBoard)

            builder.unique(on: \.token)
        }
    }
}


struct SetupKeyRequestData: Decodable {
    let key: String
    let token: String

    enum ContainerKeys: String, CodingKey {
        case data
    }

    enum CodingKeys: String, CodingKey {
        case key, token
    }

    init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: ContainerKeys.self)
        let values = try data.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        key = try values.decode(String.self, forKey: .key)
        token = try values.decode(String.self, forKey: .token)
    }
}

struct BindBoardRequestData: Decodable {
    let boardID: String

    enum ContainerKeys: String, CodingKey {
        case data
    }

    enum CodingKeys: String, CodingKey {
        case boardID
    }

    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: ContainerKeys.self)
        let values = try data.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let ids = try values.decode([String].self, forKey: .boardID)
        guard let id = ids.first else {
            throw VaporError(identifier: Constants.errorID, reason: "miss id")
        }
        self.boardID = id
    }
}
