import Vapor
import FluentMySQL

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    let client = try app.client()
    let apiKeyStorage = try app.make(APIKeyStorage.self)
    let conn = try app.requestPooledConnection(to: .mysql).wait()

    #if !DEBUG
    let log = app.make(Logger.self)
    log.debug("prepare fetch data from Trello")
    // update Trello list
    let trelloParams = [
        "key": apiKeyStorage.trelloKey,
        "token": apiKeyStorage.trelloToken
    ]
    try client.get(Constants.trelloDefaultURLString + "/lists") { request in
        try request.query.encode(trelloParams)
    }.flatMap { response in
        return try response.content.decode([TrelloList].self)
    }.flatMap { lists -> Future<()> in
        let insert = {
            return conn.insert(into: TrelloList.self)
                .values(lists)
                .run()
        }
        return conn.delete(from: TrelloList.self)
            .run()
            .flatMap(insert)
    }.wait()

    // update team members
    let members_params = trelloParams.merging(["members": "all"]) { (arg1, arg2) -> String in
        return arg1
    }
    try client.get(Constants.trelloDefaultURLString) { request in
        try request.query.encode(members_params)
    }.flatMap { response -> Future<BoardMembers> in
        print(response.http.body)
        return try response.content.decode(BoardMembers.self)
    }.flatMap { boardMembers -> Future<()> in
        let insert = {
            return conn.insert(into: TrelloMember.self)
                .values(boardMembers.members)
                .run()
        }
        return conn.delete(from: TrelloMember.self)
            .run()
            .flatMap(insert)
    }.wait()
    #endif

    try app.releasePooledConnection(conn, to: .mysql)
}
