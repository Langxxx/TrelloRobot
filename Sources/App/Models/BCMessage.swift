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


struct BCFormRequest: Decodable, RequestDecodable {
    let messageKey: String
    let userID: String

    enum CodingKeys : String, CodingKey{
        case messageKey = "message_key"
        case userID = "user_id"
    }
}

final class BCMessageFormState: MySQLModel {
    var id: Int?

    var messageKey: String
    let userID: String
    private var stateValue: Int
    private var formString: String?

    init(messageKey: String,
         userID: String,
         state: State,
         form: FormResponse) throws {

        self.messageKey = messageKey
        self.userID = userID
        self.stateValue = state.rawValue

        let formData = try JSONEncoder().encode(form)
        formString = String(data: formData, encoding: .utf8)
    }

    var state: State {
        get {
            return State(rawValue: stateValue) ?? .unknown
        }
        set {
            stateValue = newValue.rawValue
        }
    }

    var form: FormResponse? {
        get {
            guard let data = formString?.data(using: .utf8) else {
                return nil
            }
            do {
                let form = try JSONDecoder().decode(FormResponse.self, from: data)
                return form
            } catch {
                return nil
            }
        }
        set {
            guard let formData = try? JSONEncoder().encode(newValue) else {
                return
            }
            formString = String(data: formData, encoding: .utf8)
        }
    }

    enum State: Int, Codable {
        case unknown = 0
        case initial = 1
        case cardCreating
        case cardCreated
    }
}

extension BCMessageFormState: MySQLMigration {
    static func prepare(on conn: MySQLConnection) -> Future<Void> {
        return MySQLDatabase.create(BCMessageFormState.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.formString, type: .text)
            builder.field(for: \.messageKey)
            builder.field(for: \.userID)
            builder.field(for: \.stateValue)

            builder.unique(on: \.messageKey, \.userID)
        }
    }
}
