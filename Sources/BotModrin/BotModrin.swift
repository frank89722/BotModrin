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

class BotModrin {
    
    public static let shared = BotModrin()
    
    let logger = Logger(label: "frankv.BotModrin.BotModrin")
    
    var config: Config
    
    let swiftCord: Swiftcord
    let projectManager: ProjectManager
    let commandManager: CommandManager
    let db: Connection?
    
    
    init() {
        let codableFiles = CodableFiles.shared
        
        do {
            config = try codableFiles.load(objectType: Config.self, withFilename: "config", atDirectory: ".")!
        } catch {
            logger.error("Invalid config")
            let _ = try? codableFiles.save(object: Config(), withFilename: "config", atDirectory: ".")
            exit(78)
        }
        
        db = try? Connection(.inMemory)
        
        swiftCord = Swiftcord(token: config.bot_token, eventLoopGroup: .none)
        projectManager = ProjectManager()
        commandManager = CommandManager()
    }
    
    
    deinit {
        swiftCord.disconnect()
    }
    

    fileprivate func start() {
        swiftCord.addListeners(BotModrinListener(self))
        swiftCord.connect()
    }
    
}

fileprivate class BotModrinListener: ListenerAdapter {
    
    let botModrin: BotModrin
    
    
    init(_ botModrin: BotModrin) {
        self.botModrin = botModrin
    }
    
    
    override func onReady(botUser: User) async {
        try? botModrin.commandManager.register(command: CommandTrackAdd())
    }
    
    
    override func onSlashCommandEvent(event: SlashCommandEvent) async {
        await botModrin.commandManager.onSlashCommandEvent(event: event)
    }
    
}

@main
extension BotModrin {
    
    public static func main() {
        shared.start()
    }
    
}

struct Config: Codable {
    var bot_token: String = "enter the bot token here"
}


