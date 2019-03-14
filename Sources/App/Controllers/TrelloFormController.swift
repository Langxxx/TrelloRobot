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
    }

}

extension TrelloFormController {
    func newInitialForm(_ req: Request, message: BCRequestMessage) throws -> Future<HTTPStatus> {
        let logger = try req.make(Logger.self)
        let initialForm = FormResponse.initial
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
            try resp.content.decode(BCResponseMessage.self)
        }.flatMap { responseMsg -> Future<BCMessageFormState> in
            let model = try BCMessageFormState(
                messageKey: responseMsg.key,
                userID: message.sender,
                state: .initial,
                form: initialForm)
            return model.create(on: req)
        }.do { model in
            logger.debug("-----\(model.messageKey)")
        }.transform(to: .ok)
    }
}


extension TrelloFormController {
    func getInitialForm(_ req: Request) throws -> Future<FormResponse> {
        let logger = try req.make(Logger.self)
        let messageKey: String = try req.query.get(at: "message_key")
        let userID: String = try req.query.get(at: "user_id")
        return BCMessageFormState.query(on: req)
            .filter(\.messageKey == messageKey)
            .filter(\.userID == userID)
            .first()
            .flatMap { cache -> Future<FormResponse> in
                if let form = cache?.form {
                    logger.info("fetch cache....")
                    return Future.map(on: req) { form }
                }
                let form = FormResponse.initial
                let model = try BCMessageFormState(
                    messageKey: messageKey,
                    userID: userID,
                    state: .initial,
                    form: form)
                return model.create(on: req)
                    .flatMap { _ in Future.map(on: req) { form } }
            }

    }
}
