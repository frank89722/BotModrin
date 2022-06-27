//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import Swiftcord
import Logging

enum CommandError: Error {
    case registerError(String)
}


protocol Command {
    var key: String { get }
    var builder: SlashCommandBuilder { get }
    func onCommandEvent(event: SlashCommandEvent) async -> Void
}


class CommandManager {
    
    private let logger = Logger(label: "frankv.BotModrin.CommandManager")
    
    private(set) var commands = [String: Command]()
    
    
    func register(command: Command) throws {
        if commands[command.key] != nil {
            logger.error("Faild to register command \"\(command.key)\": Command already existed.")
            throw CommandError.registerError("Command already existed.")
        }
        
        Task {
            do {
                try await BotModrin.shared.swiftCord.uploadSlashCommand(commandData: command.builder)
                logger.info("Command \"\(command.key)\" is registered.")
            } catch {
                logger.info("Faild to register command \"\(command.key)\": \(error.localizedDescription)")
                throw error
            }
        }
        
        commands.updateValue(command, forKey: command.key)
        
    }
    
    func onSlashCommandEvent(event: SlashCommandEvent) async {
        let commands = BotModrin.shared.commandManager.commands
        
        if commands.keys.contains(event.name) {
            try? await event.deferReply()
            await commands[event.name]!.onCommandEvent(event: event)
        }
    }
    
}
