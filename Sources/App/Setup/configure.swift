import FluentMySQL
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentMySQLProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
//    middlewares.use(TrelloAuthMiddleware())
    services.register(middlewares)

    // Configure a SQLite database
    let mysqlCOnfig = MySQLDatabaseConfig(
        hostname: "localhost",
        port: 3306,
        username: "root",
        password: "11111111",
        database: "trello")
    let mysql = MySQLDatabase(config: mysqlCOnfig)

    // Register the configured MySQL database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: mysql, as: .mysql)
    services.register(databases)

    // Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: TrelloBoard.self, database: .mysql)
    migrations.add(model: TrelloList.self, database: .mysql)
    migrations.add(model: TrelloMember.self, database: .mysql)
    migrations.add(model: BCMessageFormState.self, database: .mysql)
    migrations.add(model: TrelloAPIConfig.self, database: .mysql)
    services.register(migrations)

    var commands = CommandConfig.default()
    commands.useFluentCommands()
    services.register(commands)

}
