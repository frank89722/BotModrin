//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import Swiftcord
import Logging

fileprivate let apiService = ApiService.modrinth

class CommandTrackAdd: Command {
    private let logger = Logger(label: "frankv.BotModrin.CommandTrackAdd")

    let key = "track"
    
    lazy private(set) var builder = try! SlashCommandBuilder(name: self.key,
                                                             description: "Manage Modrinth project update tracker in this channel",
                                                             defaultMemberPermissions: "16")
//        .addOption(option: try! ApplicationCommandOptions(name: "add", description: "Track a project in this channel ", type: .subCommand))
        .addOption(option: try! ApplicationCommandOptions(name: "action", description: "Command action", type: .string)
            .addChoice(name: "add", value: "add")
            .addChoice(name: "remove", value: "remove")
        )
        .addOption(option: try! ApplicationCommandOptions(name: "project", description: "Project id or slug", type: .string))
    
    let projectManager = BotModrin.shared.projectManager
    
    
    func onCommandEvent(event: SlashCommandEvent) async {
        event.setEphemeral(true)
        
        let action = event.getOptionAsString(optionName: "action")
        let projectId = event.getOptionAsString(optionName: "project") ?? ""
        let fetchResult = await apiService.fetchApi("/project/\(projectId)", objectType: Project.self)
        
        switch fetchResult {
        case .success(let project):
            switch action {
            case "add":
                await add(event, project: project)
                
            case "remove":
                await remove(event, project: project)
            default:
                break
            }
            
        case .failure(let error):
            switch error {
            case HttpError.code(let code) where code == 404:
                logger.error("Error fetching project: \(error.localizedDescription)")
                try? await event.reply(message: "Project: \(projectId) is not found")
                
            default:
                try? await event.reply(message: "We have some issue...")
            }
        }
    }
    
    private func add(_ event: SlashCommandEvent, project: Project) async {
        do {
            try await projectManager.add(project, channelId: event.channelId)
            try? await event.reply(message: project.title + " is added to tracking list")
        } catch {
            try? await event.reply(message: project.title + " is already in the tracking list")
        }
    }
    
    private func remove(_ event: SlashCommandEvent, project: Project) async {
        do {
            try await projectManager.remove(project.id, channelId: event.channelId)
            try? await event.reply(message: "No longer tracking the project \"\(project.title)\" in this channel")
        } catch QueryError.notFound {
            try? await event.reply(message: "Project \"\(project.title)\" is not tracking in this channel")
        } catch {
            try? await event.reply(message: "We have some issue...")
        }
    }
    
}
