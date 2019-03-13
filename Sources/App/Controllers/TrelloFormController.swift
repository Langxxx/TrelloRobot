//
//  TrelloFormController.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor

final class TrlloFormController: RouteCollection {
    func boot(router: Router) throws {
        router.post(BCRequestMessage.self, at: "bearychat", use: initialForm)
    }

}

extension TrlloFormController {
    func initialForm(_ req: Request, message: BCRequestMessage) throws -> Future<HTTPStatus> {
        let logger = try req.make(Logger.self)
        return try req.client().post("http://api.stage.bearychat.com/v1/message.create") { request in
            let msg = BCMessage(
                msg: message,
                text: "创建一个任务",
                formURL: "http://chaojidiao.stage.bearychat.com:8866/list/select",
                form: FormResponse.initial)
            try request.content.encode(json: msg)
            logger.debug("-----+\(request.http.body)")
        }.do { resp in
            logger.debug("-----\(resp)")
        }.flatMap { resp in
            try resp.content.decode(BCResponseMessage.self)
        }.flatMap { responseMsg -> Future<BCMessageFormState> in
            let model = BCMessageFormState(id: responseMsg.key + message.sender, state: .initial)
            return model.create(on: req)
        }.do { model in
            logger.debug("-----\(model.id!)")
        }.transform(to: .ok)
    }
}
