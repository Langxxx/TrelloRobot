import Vapor
import FluentSQLite

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    let client = try app.client()
    let apiKeyStorage = try app.make(APIKeyStorage.self)

    let trelloParams = [
        "key": apiKeyStorage.trelloKey,
        "token": apiKeyStorage.trelloToken
    ]
    let listsReq = client.get(Constants.trelloDefaultURLString + "/lists") { request in
        try request.query.encode(trelloParams)
        print(request.http)
    }
    let conn = try app.requestPooledConnection(to: .sqlite).wait()

//    try conn.create(table: TrelloList.self)
//        .ifNotExists()
//        .column(for: \TrelloList.id, .primaryKey)
//        .run()
//        .wait()

    try listsReq.flatMap { response in
        return try response.content.decode([TrelloList].self)
    }.flatMap { lists in
        return conn.raw()
//        lists[0].create(on: conn)
//        return conn.insert(into: TrelloList.self)
//            .values(lists)
//            .run()
    }.wait()


    let members_params = trelloParams.merging(["members": "all"]) { (arg1, arg2) -> String in
        return arg1
    }
    let membersRes = client.get(Constants.trelloDefaultURLString) { request in
        try request.content.encode(json: members_params)
    }

    try app.releasePooledConnection(conn, to: .sqlite)
}
