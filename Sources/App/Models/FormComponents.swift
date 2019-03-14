//
//  Form.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor

struct FormResponse: Codable, ResponseEncodable {

    private let version: String
    private let actions: [AnyEncodable]

    init(version: String = "1.0", action: [FormAction]) {
        self.version = version
        self.actions = action.map { AnyEncodable($0) }
    }

    static let initial = FormResponse(
        action: [
            SubmitAction(name: "card.form", text: "创建一个Card")
        ])
}

private struct AnyEncodable: Codable {
    var _encodeFunc: (Encoder) throws -> Void
    let codable: Codable

    init(_ codable: Codable) {
        func _encode(to encoder: Encoder) throws {
            try codable.encode(to: encoder)
        }
        self.codable = codable
        self._encodeFunc = _encode
    }
    func encode(to encoder: Encoder) throws {
        try _encodeFunc(encoder)
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try values.decode(String.self, forKey: CodingKeys.type)
        let type = ActionType.init(rawValue: typeString) ?? .unknown
        try self.init(type.classType.init(from: decoder))
    }
}

protocol FormAction: Codable {
    var type: ActionType { get }
}

struct SectionAction: FormAction {
    let type = ActionType.section
    fileprivate let text: Text

    init(value: String, markdown: Bool = false)  {
        text = Text(value: value, markdown: markdown)
    }


    fileprivate struct Text: Codable {
        let value: String
        let markdown: Bool?
    }
}

struct InputAtion: FormAction {
    let type = ActionType.input

    let name: String
    let label: String?
    let value: String?
    let hidden: Bool
    let placeholder: String?

    init(name: String,
         label: String? = nil,
         value: String? = nil,
         hidden: Bool = false,
         placeholder: String? = nil) {

        self.name = name
        self.label = label
        self.value = value
        self.hidden = hidden
        self.placeholder = placeholder
    }
}


struct SelectAction: FormAction {
    let type = ActionType.select
    let name: String
    let label: String?
    let placeholder: String?
    let multi: Bool
    let options: [String]?

    private init(type: ActionType,
                 name: String,
                 label: String? = nil,
                 placeholder: String?,
                 multi: Bool = false,
                 options: [String]? = nil) {
        self.name = name
        self.label = label
        self.placeholder = placeholder
        self.multi = multi
        self.options = options
    }

    static func custom(name: String,
                       label: String? = nil,
                       placeholder: String?,
                       multi: Bool = false,
                       options: [String]) -> SelectAction {
        return SelectAction(
            type: .select,
            name: name,
            label: label,
            placeholder: placeholder,
            multi: multi,
            options: options)
    }

    static func channel(name: String,
                        label: String? = nil,
                        placeholder: String?,
                        multi: Bool = false) -> SelectAction {
        return SelectAction(
            type: .channelSelect,
            name: name,
            label: label,
            placeholder: placeholder,
            multi: multi)
    }
}

struct SubmitAction: FormAction {
    let type = ActionType.submit
    let name: String
    let text: String
    let kind: Kind

    init(name: String, text: String, kind: Kind = .normal) {
        self.name = name
        self.text = text
        self.kind = kind
    }

    enum Kind: String, Codable {
        case normal, primary, danger
    }
}

enum ActionType: String, Codable {
    // static
    case section
    case context
    case image
    case divider

    // interactable
    case input
    case select
    case memberSelect = "member-select"
    case channelSelect = "channel-select"
    case dateSelect = "date-select"
    case checkbox = "checkbox"
    case submit

    case unknown

    var classType: Codable.Type {
        switch self {
        case .section:
            return SectionAction.self
        case .input:
            return InputAtion.self
        case .select, .channelSelect, .memberSelect:
            return SelectAction.self
        case .submit:
            return SubmitAction.self
        default:
            fatalError("TODO!!!")
        }
    }
}

