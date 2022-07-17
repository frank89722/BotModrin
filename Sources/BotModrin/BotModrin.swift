//
//  BotModrin.swift
//
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import Swiftcord
import Logging
import CodableFiles
import SQLite


final class BotModrin {
    
    #if DEBUG
    public static let shared = BotModrin(isDebug: true)
    #else
    public static let shared = BotModrin()
    #endif
    
    var logger = Logger(label: "me.frankv.BotModrin")
    
    var swiftcordLogger = Logger(label: "Swiftcord")
    
    var config: Config
    
    let swiftCord: Swiftcord
    private(set) lazy var projectManager = ProjectManager(self)
    let commandManager = CommandManager()
    let db: Connection?
    
    
    private init(isDebug: Bool = false) {
        
        let codableFiles = CodableFiles.shared
        let rootDir = Bundle.main.resourceURL!.description
        
        logger.logLevel = isDebug ? .debug : .info
        
        swiftcordLogger.logLevel = .trace
        
        if let isDocker = ProcessInfo.processInfo.environment["BM_DOCKER"], isDocker == "1" {
            config = Config()
            config.bot_token = ProcessInfo.processInfo.environment["BM_DISCORD_BOT_TOKEN"] ?? ""
            config.db_dir = ProcessInfo.processInfo.environment["BM_DB_DIR"] ?? config.db_dir
        } else {
            do {
                config = try codableFiles.load(objectType: Config.self, withFilename: "config", atDirectory: isDebug ? "." : rootDir)
            } catch {
                logger.error("Invalid config")
                let _ = try? codableFiles.save(object: Config(), withFilename: "config", atDirectory: isDebug ? "." : rootDir)
                exit(78)
            }
        }
        
        db = try? Connection(isDebug ? .inMemory : .uri(config.db_dir))
//        db = try? Connection(.uri("/Users/frankv/Documents/asd.db"))
        
        swiftCord = Swiftcord(token: config.bot_token, logger: swiftcordLogger, eventLoopGroup: .none)
    }
    
    deinit {
        swiftCord.disconnect()
    }

    fileprivate func start() {
        swiftCord.addListeners(BotModrinListener())
        swiftCord.connect()
    }
    
    private func registerCommand() {
        try? commandManager.register(command: CommandTrack())
    }
    
    fileprivate func onReady() {
        registerCommand()
        projectManager.runUpdaterTask()
    }
    
}


fileprivate class BotModrinListener: ListenerAdapter {
    
    private let botModrin = BotModrin.shared
    
    
    override func onReady(botUser: User) async {
        botModrin.onReady()
        botModrin.commandManager.postOnReady()
    }
    
    override func onSlashCommandEvent(event: SlashCommandEvent) async {
        await botModrin.commandManager.onSlashCommandEvent(event: event)
    }
    
}


@main
extension BotModrin {
    public static func main() {
        BotModrin.shared.start()
    }
    
    func logInfo(_ content: String, file: String = #file, function: String = #function, line: UInt = #line) {
        BotModrin.shared.logger.info("\(content)", file: file, function: function, line: line)
    }
    
    func logWarning(_ content: String, file: String = #file, function: String = #function, line: UInt = #line) {
        BotModrin.shared.logger.warning("\(content)", file: file, function: function, line: line)
    }
    
    func logError(_ content: String, file: String = #file, function: String = #function, line: UInt = #line) {
        BotModrin.shared.logger.error("\(content)", file: file, function: function, line: line)
    }
    
    func logDebug(_ content: String, file: String = #file, function: String = #function, line: UInt = #line) {
        BotModrin.shared.logger.debug("\(content)", file: file, function: function, line: line)
    }
}


struct Config: Codable {
    var bot_token: String = "enter the bot token here"
    var db_dir: String = Bundle.main.resourceURL!.description + "/bot_modrin/bot_modrin.db"
}


