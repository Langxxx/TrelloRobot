//
//  TrelloAuthMiddleware.swift
//  App
//
//  Created by didi on 2019/3/18.
//

import Vapor
import FluentMySQL

final class TrelloAuthMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let robotToken: String
        do {
            robotToken = try request.query.get(at: "token")
        } catch {
            robotToken = try request.content.syncGet(String.self, at: "token")
        }

        let vchannel: String
        do {
            vchannel = try request.query.get(at: "vchannel_id")
        } catch {
            if let temp = try? request.content.syncGet(String.self, at: "vchannel_id") {
                vchannel = temp
            } else {
                vchannel = try request.content.syncGet(String.self, at: "vchannel")
            }
        }

        return TrelloAPIConfig.query(on: request)
            .filter(\.robotToken == robotToken)
            .first()
            .flatMap { api -> Future<Response> in
                guard api?.idBoard != nil else {
                    return try TrelloAuthController.getSetupKeyForm(
                        req: request,
                        robotToken: robotToken,
                        vchannel: vchannel)
                }

                return try next.respond(to: request)
            }
    }
}
