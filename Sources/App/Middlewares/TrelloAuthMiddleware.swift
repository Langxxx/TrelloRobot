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
                guard let api = api,
                   api.idBoard != nil else {
                    return try TrelloAuthController.getSetupKeyForm(
                        req: request,
                        robotToken: robotToken,
                        vchannel: vchannel)
                }

                return try TrelloAuthMiddleware.fetchTrelloDataIfNeed(req: request, api: api)
                    .flatMap { _ in try next.respond(to: request) }
            }
    }

    private static func fetchTrelloDataIfNeed(req: Request, api: TrelloAPIConfig) throws -> Future<()> {
        guard let idBoard = api.idBoard else {
            return .done(on: req)
        }


        return TrelloBoard.find(idBoard, on: req)
            .flatMap { board in
                guard board == nil else {
                    return .done(on: req)
                }

                let boardURLString = "https://api.trello.com/1/boards/\(idBoard)"
                let boardQuery = [
                    "token": api.token,
                    "key": api.key,
                    "fields": "name,desc,closed,idOrganization,pinned,url,shortUrl",
                    "lists": "open"
                ]

                let fetchAndSaveList = try req.client()
                    .get(boardURLString) { request in
                        try request.query.encode(boardQuery)
                    }.flatMap { response  in
                        try response.content.decode(TrelloBoardResponseData.self)
                    }.flatMap { model -> Future<()> in
                        req.withPooledConnection(to: .mysql) { conn -> Future<()> in
                            let trello = TrelloBoard(id: model.id, name: model.name, url: model.url)
                                .create(on: conn)
                                .map { _ in () }
                            let lists = {
                                conn.insert(into: TrelloList.self)
                                .values(model.lists ?? [])
                                .run()
                            }
                            return trello.flatMap(lists)
                        }
                    }

                let memberdQuery = [
                    "token": api.token,
                    "key": api.key,
                ]
                let fetchAndSaveMember = try req.client()
                    .get("\(boardURLString)/members") { request in
                        try request.query.encode(memberdQuery)
                    }.flatMap { response in
                         return try response.content.decode([TrelloMemberResponse].self)
                    }.flatMap { members -> Future<()> in
                        let members = members.map { TrelloMember(
                            memberID: $0.id ?? "",
                            username: $0.username,
                            fullname: $0.fullName,
                            idBoard: idBoard) }
                        return req.withPooledConnection(to: .mysql) { conn -> Future<()> in
                            return conn.insert(into: TrelloMember.self)
                                .values(members)
                                .run()
                        }
                    }
                return fetchAndSaveList.and(fetchAndSaveMember)
                    .map { _ in () }
        }
    }
}
