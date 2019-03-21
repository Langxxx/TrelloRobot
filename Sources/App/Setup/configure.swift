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
        hostname: Environment.get("MYSQL_HOST") ?? "localhost",
        port: Environment.get("MYSQL_PORT").flatMap { Int($0) } ?? 3306,
        username: Environment.get("MYSQL_USER") ?? "root",
        password: Environment.get("MYSQL_PASSWORD") ?? "11111111",
        database: Environment.get("MYSQL_DATABASE") ?? "trello")
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
