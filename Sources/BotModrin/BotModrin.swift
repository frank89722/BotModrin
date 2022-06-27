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
    
    public static let shared = BotModrin()
    
    let logger = Logger(label: "frankv.BotModrin.BotModrin")
    
    var config: Config
    
    let swiftCord: Swiftcord
    private(set) lazy var projectManager = ProjectManager(self)
    let commandManager = CommandManager()
    let db: Connection?
    
    
    private init() {
        let codableFiles = CodableFiles.shared
        let rootDir = Bundle.main.resourceURL!.description
        
        do {
            config = try codableFiles.load(objectType: Config.self, withFilename: "config", atDirectory: rootDir)!
        } catch {
            logger.error("Invalid config")
            let _ = try? codableFiles.save(object: Config(), withFilename: "config", atDirectory: rootDir)
            exit(78)
        }
        
        #if DEBUG
        db = try? Connection(.inMemory)
        #else
        db = try? Connection(.uri(rootDir + "/bot_modrin.db"))
        #endif
        
        swiftCord = Swiftcord(token: config.bot_token, eventLoopGroup: .none)
    }
    
    deinit {
        swiftCord.disconnect()
    }

    fileprivate func start() {
        swiftCord.addListeners(BotModrinListener(self))
        swiftCord.connect()
    }
    
    fileprivate func onReady() {
        projectManager.runUpdaterTask()
    }
    
}


fileprivate class BotModrinListener: ListenerAdapter {
    
    let botModrin: BotModrin
    
    
    init(_ botModrin: BotModrin) {
        self.botModrin = botModrin
    }
    
    override func onReady(botUser: User) async {
        try? botModrin.commandManager.register(command: CommandTrackAdd())
        botModrin.onReady()
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


