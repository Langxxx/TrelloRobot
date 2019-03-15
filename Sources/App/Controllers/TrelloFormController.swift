//
//  TrelloFormController.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor
import FluentMySQL

final class TrelloFormController: RouteCollection {

    func boot(router: Router) throws {
        router.post(BCRequestMessage.self, at: "bearychat", use: newInitialForm)
        router.get("/list/select", use: getInitialForm)
        router.post("/list/select", use: actionCenter)
    }

}

fileprivate extension TrelloFormController {
    func newInitialForm(_ req: Request, message: BCRequestMessage) throws -> Future<HTTPStatus> {
        let logger = try req.make(Logger.self)
        let initialForm = TrelloFormController.initial
        return try req.client().post("http://api.stage.bearychat.com/v1/message.create") { request in
            let msg = BCMessage(
                msg: message,
                text: "创建一个任务",
                formURL: "http://chaojidiao.stage.bearychat.com:8866/list/select",
                form: initialForm)
            try request.content.encode(json: msg)
            logger.debug("-----+\(request.http.body)")
        }.do { resp in
            logger.debug("-----\(resp)")
        }.flatMap { resp in
            resp.content.get(String.self, at: "key")
        }.flatMap { key -> Future<BCMessageFormState> in
            let model = try BCMessageFormState(
                messageKey: key,
                userID: message.sender,
                state: .initial,
                form: initialForm)
            return model.create(on: req)
        }.do { model in
            logger.debug("-----\(model.messageKey)")
        }.transform(to: .ok)
    }
}


fileprivate extension TrelloFormController {
    func getInitialForm(_ req: Request) throws -> Future<FormResponse> {
        let logger = try req.make(Logger.self)
        let queryModel = try req.query.decode(BCFormRequest.self)
        return BCMessageFormState.query(on: req)
            .filter(\.messageKey == queryModel.messageKey)
            .filter(\.userID == queryModel.userID)
            .first()
            .flatMap { cache -> Future<FormResponse> in
                if let form = cache?.form {
                    logger.info("fetch cache....")
                    return Future.map(on: req) { form }
                }
                let form = TrelloFormController.initial
                let model = try BCMessageFormState(
                    messageKey: queryModel.messageKey,
                    userID: queryModel.userID,
                    state: .initial,
                    form: form)
                return model.create(on: req)
                    .flatMap { _ in Future.map(on: req) { form } }
            }

    }
}

fileprivate extension TrelloFormController {
    func actionCenter(_ req: Request) throws -> Future<FormResponse> {
        let actionValue = try req.content.syncGet(String.self, at: "action")
        let queryModel = try req.query.decode(BCFormRequest.self)
        guard let action = Action(rawValue: actionValue) else {
            throw VaporError(identifier: "TrelloActionError", reason: "unkonw action: \(actionValue)")
        }

        switch action {
        case .fetchNewCardForm:
            return try getCreateCardForm(req, queryModel: queryModel)
        case .createCard:
            fatalError("TODO")
        }
    }

    private func getCreateCardForm(_ req: Request, queryModel: BCFormRequest) throws -> Future<FormResponse> {
        let logger = try req.make(Logger.self)
        return BCMessageFormState.query(on: req)
            .filter(\.messageKey == queryModel.messageKey)
            .filter(\.userID == queryModel.userID)
            .first()
            .flatMap { cache -> Future<FormResponse> in
                if cache?.state == .cardCreating,
                    let form = cache?.form {
                    logger.info("fetch cache...\(req.http.urlString)")
                    return Future.map(on: req) { form }
                }

                let lists = TrelloList.query(on: req).all()
                let members = TrelloMember.query(on: req).all()
                return flatMap(lists, members) { (lists, members) -> Future<FormResponse> in
                    let listSelect = SelectAction.custom(
                        name: TrelloFormController.trelloListName,
                        placeholder: "选择一个list",
                        options: lists.map { SelectAction.Option(text: $0.name, value: $0.id!) })

                    let nameInput = InputAtion(
                        name: TrelloFormController.trelloLisCardtName,
                        placeholder: "任务名称")

                    let descInput = InputAtion(
                        name: TrelloFormController.trelloListCardDesc,
                        placeholder: "任务描述")

                    let assignSelect = SelectAction.custom(
                        name: TrelloFormController.trelloListCardAssign,
                        placeholder: "分配给谁",
                        options: members.map { SelectAction.Option(text: $0.username, value: $0.id!) })

                    let createSubmit = SubmitAction(
                        name: Action.createCard.rawValue,
                        text: "创建任务")

                    let form = FormResponse(action: [listSelect, nameInput, descInput, assignSelect, createSubmit])
                    if let cache = cache {
                        cache.form = form
                        cache.state = .cardCreating
                        return cache.save(on: req)
                            .map { _ in form }
                    } else {
                        let new = try BCMessageFormState(
                            messageKey: queryModel.messageKey,
                            userID: queryModel.userID,
                            state: .cardCreating,
                            form: form)
                        return new.create(on: req)
                            .map { _ in form }
                    }
                }
            }
    }
}


fileprivate extension TrelloFormController {
    static let initial = FormResponse(
        action: [
            SubmitAction(name: Action.fetchNewCardForm.rawValue, text: "创建一个Card")
        ])

    enum Action: String {
        case fetchNewCardForm
        case createCard
    }

    static let trelloListName = "trelloListName"
    static let trelloLisCardtName = "trelloLisCardtName"
    static let trelloListCardDesc = "trelloListCardDesc'"
    static let trelloListCardAssign = "trelloListCardAssign"
}
