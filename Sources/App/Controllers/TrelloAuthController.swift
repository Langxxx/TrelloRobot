//
//  TrelloAuthController.swift
//  App
//
//  Created by didi on 2019/3/18.
//

import Vapor
import FluentMySQL


final class TrelloAuthController: RouteCollection {
    static let authPath = "/trello/auth"
    func boot(router: Router) throws {
        router.post(TrelloAuthController.authPath, use: actionCenter)
//        router.get(TrelloAuthController.authPath, use: initialForm)
    }
}

fileprivate extension TrelloAuthController {
    func actionCenter(_ req: Request) throws -> Future<FormResponse> {
        let actionValue = try req.content.syncGet(String.self, at: "action")
        let queryModel = try req.query.decode(BCFormRequest.self)
        guard let action = Action(rawValue: actionValue) else {
            throw VaporError(identifier: "TrelloActionError", reason: "unkonw action: \(actionValue)")
        }

        return TrelloAPIConfig.query(on: req)
            .filter(\.robotToken == queryModel.token)
            .first()
            .flatMap { [weak self] api -> Future<FormResponse> in
                guard let self = self else {
                    throw VaporError(identifier: "TimeLife", reason: "TimeLife")
                }
                switch action {
                case .setupKey:
                    if api == nil {
                        return try self.setupKeyAndGetSetupBoardForm(req, queryModel: queryModel)
                    } else {
                        return try TrelloAuthController.getSetupBoardForm(req, queryModel: queryModel, apiConfig: api!)
                    }
                case .bindBoard:
                    guard let api = api else {
                        throw VaporError(identifier: "bindBoard", reason: "miss api")
                    }
                    return try self.bindBoard(req, queryModel: queryModel, apiConfig: api)
                }
            }

    }

    private func setupKeyAndGetSetupBoardForm(_ req: Request, queryModel: BCFormRequest) throws -> Future<FormResponse> {
        let reqModel = try req.content.syncDecode(SetupKeyRequestData.self)
        let apiConfig = TrelloAPIConfig(
            robotToken: queryModel.token,
            key: reqModel.key,
            token: reqModel.token)
        return apiConfig.create(on: req)
            .flatMap { _  -> Future<FormResponse> in
                return try TrelloAuthController.getSetupBoardForm(req, queryModel: queryModel, apiConfig: apiConfig)
        }
    }

    private func bindBoard(_ req: Request, queryModel: BCFormRequest, apiConfig: TrelloAPIConfig) throws -> Future<FormResponse> {
        return BCMessageFormState.query(on: req)
            .filter(\.messageKey == queryModel.messageKey)
            .first()
            .flatMap { cache in
                if cache?.state == .authFinish,
                    let form = cache?.form {
                    return Future.map(on: req) { form }
                }

                let reqModel = try req.content.syncDecode(BindBoardRequestData.self)
                apiConfig.idBoard = reqModel.boardID
                return apiConfig.save(on: req)
                    .flatMap { _ in
                        let section = SectionAction(value: "授权完成")
                        let form = FormResponse(action: [section])
                        if let cache = cache {
                            cache.state = .authFinish
                            cache.form = nil
                            return cache.save(on: req)
                                .map { _ in form }
                        } else {
                            let new = try BCMessageFormState(
                                messageKey: queryModel.messageKey,
                                userID: "",
                                state: .authFinish,
                                form: form)
                            return new.create(on: req)
                                .map { _ in form }
                        }
                }
            }
    }
}

extension TrelloAuthController {
    // 因为不支持重定向，所以只能从中间件response
    static func getSetupKeyForm(req: Request, robotToken: String, vchannel: String) throws -> Future<Response> {
        let log = try req.make(Logger.self)

        let tokenInput = InputAtion(name: "token", placeholder: "Trello Token")
        let keyInput = InputAtion(name: "key", placeholder: "Trello Key")
        let nextSubmit = SubmitAction(name: Action.setupKey.rawValue, text: "下一步")
        let form = FormResponse(action: [tokenInput, keyInput, nextSubmit])

        return try req.client().post(Constants.bcCreateMessageURLString) { request in
            let msg = BCMessage(
                token: robotToken,
                vchannelID: vchannel,
                text: "初始化Trello机器人",
                formURL: Constants.baseFormURLString + authPath,
                form: form)
            try request.content.encode(json: msg)
            log.debug("-----+\(request.http.body)")
        }.flatMap { resp in
             resp.content.get(String.self, at: "key")
        }.flatMap { key -> Future<Response> in
            let model = try BCMessageFormState(
                messageKey: key,
                userID: "",
                state: .setupKey,
                form: nil)
            return model.create(on: req)
                .map { _ in Response(http: HTTPResponse(), using: req) }
        }
    }

    fileprivate static func getSetupBoardForm(_ req: Request,
                                              queryModel: BCFormRequest,
                                              apiConfig: TrelloAPIConfig) throws -> Future<FormResponse> {
        guard apiConfig.idBoard == nil else {
            let section = SectionAction(value: "已经完成授权")
            let form = FormResponse(action: [section])
            return Future.map(on: req) { form }
        }

        return BCMessageFormState.query(on: req)
            .filter(\.messageKey == queryModel.messageKey)
            .first()
            .flatMap { cache -> Future<FormResponse> in
                if cache?.state == .bindBoard,
                    let form = cache?.form {
                    return Future.map(on: req) { form }
                }
                let trelloParams = [
                    "key": apiConfig.key,
                    "token": apiConfig.token
                ]
                //TODO: check key and token valid
                return try req.client()
                    .get("https://api.trello.com/1/members/me/boards") { request in
                        try request.query.encode(trelloParams)
                    }.flatMap { response in
                        try response.content.decode([TrelloBoardResponseData].self)
                    }.flatMap { boards -> Future<FormResponse> in
                        let boardSelect = SelectAction.custom(
                            name: BindBoardRequestData.CodingKeys.boardID.rawValue,
                            label: "绑定一个Board",
                            placeholder: "绑定一个Board",
                            options: boards.map { SelectAction.Option(text: $0.name, value: $0.id) })
                        let submitAction = SubmitAction(name: Action.bindBoard.rawValue, text: "完成")
                        let form = FormResponse(action: [boardSelect, submitAction])
                        if let cache = cache {
                            cache.form = form
                            cache.state = .bindBoard
                            return cache.save(on: req)
                                .map { _ in form }
                        } else {
                            let new = try BCMessageFormState(
                                messageKey: queryModel.messageKey,
                                userID: "",
                                state: .bindBoard,
                                form: form)
                            return new.create(on: req)
                                .map { _ in form }
                        }
                }
        }
    }

    fileprivate enum Action: String {
        case setupKey
        case bindBoard
    }
}
