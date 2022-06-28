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
    
    private static let instance = CommandTrackAdd()
    
    private let logger = Logger(label: "frankv.BotModrin.CommandTrackAdd")

    let key = "trackadd"
    
    lazy private(set) var builder = try! SlashCommandBuilder(name: self.key, description: "Track a project in this channel", defaultMemberPermissions: "16")
        .addOption(option: try! ApplicationCommandOptions(name: "project", description: "Project id or Slug", type: .string))
    
    let projectManager = BotModrin.shared.projectManager
    
    
    func onCommandEvent(event: SlashCommandEvent) async {
        //        try? await event.deferReply()
        event.setEphemeral(true)
        
        let projectId = event.getOptionAsString(optionName: "project") ?? ""
        let fetchResult = await apiService.fetchApi("/project/\(projectId)", objectType: Project.self)
        
        switch fetchResult {
        case .success(let project):
            do {
                try await projectManager.add(project, channelId: event.channelId)
            } catch {
                try? await event.reply(message: project.title + " is already in the tracking list")
            }
            try? await event.reply(message: project.title + " is added to tracking list")
            
        case .failure(let error):
            switch error {
            case HttpError.code(let code):
                if code == 404 {
                    logger.error("Error fetching project: \(error.localizedDescription)")
                    try? await event.reply(message: "Project: \(projectId) is not found")
                    return
                }
            default:
                break
            }
            
            try? await event.reply(message: "We have some issue...")
            
        }
        
    }
}
