//
//  TrelloFormController.swift
//  App
//
//  Created by didi on 2019/3/13.
//

import Vapor

final class TrlloFormController: RouteCollection {
    func boot(router: Router) throws {
        router.post(BCMessage.self, at: "bearychat", use: initialForm)
    }

}

extension TrlloFormController {
    func initialForm(_ req: Request, message: BCMessage) throws -> Future<HTTPStatus> {
        return try req.client().post("http://api.stage.bearychat.com/v1/message.create") { request in
            try request.content.encode([
                "token": message.token,
                "vchannel_id": message.vchannel,
                "text": "创建一个任务",
                "form_url": "http://chaojidiao.stage.bearychat.com:8866/list/select"
            ])
        }.transform(to: .ok)
    }
}
