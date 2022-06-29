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
    
    let logger = Logger(label: "frankv.BotModrin.BotModrin")
    
    var config: Config
    
    let swiftCord: Swiftcord
    private(set) lazy var projectManager = ProjectManager(self)
    let commandManager = CommandManager()
    let db: Connection?
    
    
    private init(isDebug: Bool = false) {
        
        let codableFiles = CodableFiles.shared
        let rootDir = Bundle.main.resourceURL!.description
        
        do {
            config = try codableFiles.load(objectType: Config.self, withFilename: "config", atDirectory: isDebug ? "." : rootDir)!
        } catch {
            logger.error("Invalid config")
            let _ = try? codableFiles.save(object: Config(), withFilename: "config", atDirectory: isDebug ? "." : rootDir)
            exit(78)
        }
        
        db = try? Connection(isDebug ? .inMemory : .uri(rootDir + "/bot_modrin.db"))
        
        swiftCord = Swiftcord(token: config.bot_token, eventLoopGroup: .none)
    }
    
    deinit {
        swiftCord.disconnect()
    }

    fileprivate func start() {
        swiftCord.addListeners(BotModrinListener())
        swiftCord.connect()
    }
    
    private func registerCommand() {
        try? commandManager.register(command: CommandTrackAdd())
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
}


struct Config: Codable {
    var bot_token: String = "enter the bot token here"
}


