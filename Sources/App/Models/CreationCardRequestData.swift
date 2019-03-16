//
//  CardCreationRequest.swift
//  App
//
//  Created by didi on 2019/3/15.
//

import Vapor


class CreationCardRequestData: Codable {
    let name: String
    let idList: String
    let desc: String?
    let idMembers: String?

    var token: String?
    var key: String?

    enum ContainerKeys: String, CodingKey {
        case data
    }

    enum CodingKeys: String, CodingKey {
        case name, idList, desc, idMembers, token, key
    }

    required public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: ContainerKeys.self)
        let values = try data.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let lists = try values.decode([String].self, forKey: .idList)
        guard let listID = lists.first else {
            throw VaporError(identifier: Constants.errorID, reason: "miss list name")
        }
        self.idList = listID
        self.name = try values.decode(String.self, forKey: .name)
        self.desc = try values.decode(String?.self, forKey: .desc)
        self.idMembers = try values.decode([String]?.self, forKey: .idMembers)?.joined(separator: ",")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(idList, forKey: .idList)
        try container.encode(desc, forKey: .desc)
        try container.encode(idMembers, forKey: .idMembers)

        guard let token = self.token else {
            throw VaporError(identifier: Constants.errorID, reason: "miss token")
        }

        guard let key = self.key else {
            throw VaporError(identifier: Constants.errorID, reason: "miss key")
        }

        try container.encode(token, forKey: .token)
        try container.encode(key, forKey: .key)
    }

}
