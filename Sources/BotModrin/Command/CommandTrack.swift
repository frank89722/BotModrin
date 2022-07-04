//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import Swiftcord

fileprivate let apiService = ApiService.modrinth

class CommandTrack: Command {

    let key = "track"
    let projectManager = BotModrin.shared.projectManager
    let botModrin = BotModrin.shared
    
    private(set) lazy var builder = try! SlashCommandBuilder(name: self.key,
                                                             description: "Manage Modrinth project update tracker in this channel",
                                                             defaultMemberPermissions: "16")
        .addOption(option: try! ApplicationCommandOptions(name: "add", description: "Track a project in this channel", type: .subCommand)
            .addOption(option: try! ApplicationCommandOptions(name: "project", description: "Project id or slug", type: .string))
        )
        .addOption(option: try! ApplicationCommandOptions(name: "remove", description: "Remove a tracking project in this channel", type: .subCommand)
            .addOption(option: try! ApplicationCommandOptions(name: "project", description: "Project id or slug", type: .string))
        )
        .addOption(option: try! ApplicationCommandOptions(name: "removeall", description: "Remove all of tracking projects in this channel", type: .subCommand))
        .addOption(option: try! ApplicationCommandOptions(name: "list", description: "List all of tracking projects in this channel ", type: .subCommand))
    
    
    func onCommandEvent(event: SlashCommandEvent) async {
        event.setEphemeral(true)
        
        if let options = event.getOptionAsSlashCommandEventOptions(optionName: "add") {
            await add(projectId: options.getOptionAsString(optionName: "project") ?? "", event)
            return
        }
        
        if let options = event.getOptionAsSlashCommandEventOptions(optionName: "remove") {
            await remove(projectId: options.getOptionAsString(optionName: "project") ?? "", event)
            return
        }
        
        if event.getOptionAsSlashCommandEventOptions(optionName: "removeall") != nil {
            
            return
        }
        
        if event.getOptionAsSlashCommandEventOptions(optionName: "list") != nil {
            await listAll(event)
            return
        }
    }
    
    private func add(projectId: String, _ event: SlashCommandEvent) async {
        let projectFetched = await apiService.fetchApi("/project/\(projectId)", objectType: Project.self)
        let versionFetched = await apiService.fetchApi("/project/\(projectId)/version", objectType: [Version].self)
        
        switch projectFetched {
        case .success(let project):
            switch versionFetched {
            case .success(let versions):
                let v = versions[0]
                
                do {
                    try await projectManager.add(project, latestVersion: v.id, channelId: event.channelId, ownerId: event.user.id)
                    try? await event.reply(message: project.title + " is added to tracking list")
                } catch {
                    try? await event.reply(message: project.title + " is already in the tracking list")
                }
                
            case .failure(let error):
                botModrin.logError("Failed to fetch latest version in CommandTrackAdd#add: \(error.localizedDescription)")
                try? await event.reply(message: "We have some issue...")
            }
            
        case .failure(let error):
            switch error {
            case HttpError.code(let code) where code == 404:
                try? await event.reply(message: "Project: \(projectId) is not found")
                
            default:
                botModrin.logWarning("Unknow api error in \"CommandTrack\"")
                try? await event.reply(message: "We have some issue...")
            }
        }
        
        
    }
    
    private func remove(projectId: String, _ event: SlashCommandEvent) async {
        
        let projectFetched = await apiService.fetchApi("/project/\(projectId)", objectType: Project.self)
        switch projectFetched {
        case .success(let project):
            do {
                try await projectManager.remove(project.id, channelId: event.channelId)
                try? await event.reply(message: "No longer tracking the project \"\(project.title)\" in this channel")
            } catch QueryError.notFound {
                try? await event.reply(message: "Project \"\(project.title)\" is not tracking in this channel")
            } catch {
                try? await event.reply(message: "We have some issue...")
            }
            
        case .failure(let error):
            switch error {
            case HttpError.code(let code) where code == 404:
                try? await event.reply(message: "Project: \(projectId) is not found")
                
            default:
                botModrin.logWarning("Unknow api error in \"CommandTrack\"")
                try? await event.reply(message: "We have some issue...")
            }
        }
    }
    
    private func listAll(_ event: SlashCommandEvent) async {
        do {
            let channels = try await projectManager.getChannelTracking(event.channelId)
            try? await event.reply(message: channels.joined(separator: ", "))
        } catch {
            try? await event.reply(message: "No project is tracking in this channel")
        }
    }
    
}
