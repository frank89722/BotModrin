//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import Swiftcord

enum CommandError: Error {
    case registerError(String)
}


protocol Command {
    var key: String { get }
    var builder: SlashCommandBuilder { get }
    func onCommandEvent(event: SlashCommandEvent) async -> Void
}


class CommandManager {
    
    private(set) var commands = [String: Command]()
    private(set) var registerDisabled = false
    
    
    func register(command: Command) throws {
        let botModrin = BotModrin.shared
        
        guard !registerDisabled else { throw CommandError.registerError("Register has been disabled") }
        
        if commands[command.key] != nil {
            botModrin.logError("Faild to register command \"\(command.key)\": Command already existed.")
            throw CommandError.registerError("Command already existed.")
        }
        
        Task {
            do {
                let swiftCord = BotModrin.shared.swiftCord
                let onlineCommands = try await swiftCord.getApplicationCommands()
                let existed = onlineCommands.contains(where: { cmd in
                    let builder = command.builder
                    
                    return builder.name == cmd.name &&
                    builder.defaultMemberPermissions == cmd.defaultMemberPermissions &&
                    builder.description == cmd.description &&
                    ((builder.options.isEmpty && cmd.options == nil) || (builder.options == cmd.options))
                })
                
                if !existed {
                    try await swiftCord.uploadSlashCommand(commandData: command.builder)
                    botModrin.logInfo("Command \"\(command.key)\" has been upload to discord.")
                }
                
                botModrin.logInfo("Command \"\(command.key)\" is registered.")
            } catch {
                botModrin.logError("Faild to register command \"\(command.key)\": \(error.localizedDescription)")
                throw error
            }
        }
        
        commands.updateValue(command, forKey: command.key)
        
    }
    
    func onSlashCommandEvent(event: SlashCommandEvent) async {
        let commands = BotModrin.shared.commandManager.commands
        
        if commands.keys.contains(event.name) {
            BotModrin.shared.logInfo("Run command \"\(event.name)\" from \(event.channelId.rawValue) by \(event.user.username ?? "unknown")#\(event.user.discriminator ?? "unknown")")
            try? await event.deferReply()
            await commands[event.name]!.onCommandEvent(event: event)
        }
    }
    
    func postOnReady() {
        guard !registerDisabled else { return }
        
        Task {
            let swiftCord = BotModrin.shared.swiftCord
            guard let onlineCommands = try? await swiftCord.getApplicationCommands() else { return }
            
            for command in onlineCommands {
                if commands.keys.contains(command.name) { continue }
                try? await swiftCord.deleteApplicationCommand(commandId: command.id)
            }
        }
        
        registerDisabled = false
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
