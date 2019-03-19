//
//  TrelloFormController.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor
import FluentMySQL

final class TrelloFormController: RouteCollection {
    private let bcRootPath = "/bearychat"
    private let formURLPath = "/list/select"
    func boot(router: Router) throws {
        let routerWithMiddleware = router.grouped(TrelloAuthMiddleware())
        routerWithMiddleware.post(BCRequestMessage.self, at: bcRootPath, use: newInitialForm)
        routerWithMiddleware.get(formURLPath, use: getInitialForm)
        routerWithMiddleware.post(formURLPath, use: actionCenter)
    }
}

fileprivate extension TrelloFormController {
    func newInitialForm(_ req: Request, message: BCRequestMessage) throws -> Future<HTTPStatus> {
        let logger = try req.make(Logger.self)
        let initialForm = TrelloFormController.initial
        return try req.client().post(Constants.bcCreateMessageURLString) { request in
            let msg = BCMessage(
                token: message.token,
                vchannelID: message.vchannel,
                text: "创建一个任务",
                formURL: Constants.baseFormURLString + "/list/select",
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
        return fetchMessageFormState(on: req, by: queryModel)
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
            return try createCard(req, queryModel: queryModel)
        }
    }

    private func getCreateCardForm(_ req: Request, queryModel: BCFormRequest) throws -> Future<FormResponse> {
        let logger = try req.make(Logger.self)
        return fetchMessageFormState(on: req, by: queryModel)
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
                        name: CreationCardRequestData.CodingKeys.idList.rawValue,
                        placeholder: "选择一个list",
                        options: lists.map { SelectAction.Option(text: $0.name, value: $0.id!) })

                    let nameInput = InputAtion(
                        name: CreationCardRequestData.CodingKeys.name.rawValue,
                        placeholder: "任务名称")

                    let descInput = InputAtion(
                        name: CreationCardRequestData.CodingKeys.desc.rawValue,
                        placeholder: "任务描述")

                    let assignSelect = SelectAction.custom(
                        name: CreationCardRequestData.CodingKeys.idMembers.rawValue,
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

    private func createCard(_ req: Request, queryModel: BCFormRequest) throws -> Future<FormResponse> {
        let logger = try req.make(Logger.self)
        return fetchMessageFormState(on: req, by: queryModel)
            .flatMap { cache -> Future<FormResponse> in
                if cache?.state == .cardCreated,
                    let form = cache?.form {
                    logger.info("fetch cache...\(req.http.urlString)")
                    return Future.map(on: req) { form }
                }
                let api = try req.make(APIKeyStorage.self)
                let reqModel = try req.content.syncDecode(CreationCardRequestData.self)
                reqModel.token = api.trelloToken
                reqModel.key = api.trelloKey
                return try req.client()
                    .post("https://api.trello.com/1/cards") { request in
                        try request.content.encode(json: reqModel)
                    }.flatMap { response in
                        let name = try response.content.syncGet(String.self, at: "name")
                        let url = try response.content.syncGet(String.self, at: "shortUrl")

                        let successSection = SectionAction(value: "创建任务[\(name)](\(url))成功", markdown: true)
                        let newForm = FormResponse(action: [successSection])

                        if let cache = cache {
                            cache.form = newForm
                            cache.state = .cardCreated
                            return cache.save(on: req)
                                .map { _ in newForm }
                        } else {
                            let new = try BCMessageFormState(
                                messageKey: queryModel.messageKey,
                                userID: queryModel.userID,
                                state: .cardCreated,
                                form: newForm)
                            return new.create(on: req)
                                .map { _ in newForm }
                        }
                    }
            }
    }
}

private extension TrelloFormController {
    func fetchMessageFormState(on conn: DatabaseConnectable,
                               by queryModel: BCFormRequest) -> Future<BCMessageFormState?> {
        return BCMessageFormState.query(on: conn)
            .filter(\.messageKey == queryModel.messageKey)
            .filter(\.userID == queryModel.userID)
            .first()
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
}
