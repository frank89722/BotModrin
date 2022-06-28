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
    
    private let swiftCord = BotModrin.shared.swiftCord
    
    private(set) var commands = [String: Command]()
    private(set) var registerDisabled = false
    
    func register(command: Command) throws {
        guard !registerDisabled else { throw CommandError.registerError("Register has been disabled") }
        
        if commands[command.key] != nil {
            logger.error("Faild to register command \"\(command.key)\": Command already existed.")
            throw CommandError.registerError("Command already existed.")
        }
        
        Task {
            do {
                let onlineCommands = try await swiftCord.getApplicationCommands()
                let existed = onlineCommands.contains(where: { cmd in
                    let builder = command.builder
                    
                    return builder.name == cmd.name &&
                    builder.defaultMemberPermissions == cmd.defaultMemberPermissions &&
                    builder.description == cmd.description &&
                    builder.options == cmd.options
                })
                
                if !existed {
                    try await swiftCord.uploadSlashCommand(commandData: command.builder)
                    logger.info("Command \"\(command.key)\" has been upload to discord.")
                }
                
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
    
    func disableRegister() {
        registerDisabled = true
    }
    
}

extension ApplicationCommandOptions: Equatable {
    public static func == (lhs: ApplicationCommandOptions, rhs: ApplicationCommandOptions) -> Bool {
        return lhs.type == rhs.type &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.required == rhs.required
    }
}
