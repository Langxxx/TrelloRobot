//
//  BCMessage.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor
import FluentMySQL

struct BCRequestMessage: RequestDecodable, Decodable {
    let subdomain: String
    let vchannel: String
    let sender: String
    let username: String
    let token: String
    let text: String
    let key: String
}

struct BCMessage: Encodable {
    let token: String
    let vchannelID: String
    let text: String
    let formURL: String
    let form: FormResponse?


    enum CodingKeys : String, CodingKey{
        case vchannelID = "vchannel_id"
        case formURL = "form_url"
        case token, text, form
    }

    init(msg: BCRequestMessage, text: String, formURL: String, form: FormResponse?) {
        self.token = msg.token
        self.vchannelID = msg.vchannel
        self.text = text
        self.formURL = formURL
        self.form = form
    }
}

struct BCResponseMessage: Decodable, RequestDecodable {
    let key: String
}

final class BCMessageFormState: MySQLStringModel, Migration {
    var id: String?
    private var stateValue: Int

    init(id: String, state: State) {
        self.id = id
        self.stateValue = state.rawValue
    }

    var state: State {
        return State(rawValue: stateValue) ?? .unknown
    }

    enum State: Int, Codable {
        case unknown = 0
        case initial = 1
    }
}
