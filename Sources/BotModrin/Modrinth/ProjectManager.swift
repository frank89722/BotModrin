//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import SQLite
import Logging
import Swiftcord

class ProjectManager {
    
    private let logger = Logger(label: "frankv.BotModrin.ProjectManager")
    
    private let apiService = ApiService.modrinth
    fileprivate let projectRepo: ProjectRepository
    fileprivate let channelRepo: ChannelRepository
    private lazy var projectUpdater = ProjectUpdater(projectRepo: projectRepo, channelRepo: channelRepo)
    
    var doUpdate = true
    
    init (_ main: BotModrin) {
        projectRepo = ProjectRepository(db: main.db!)
        channelRepo = ChannelRepository(db: main.db!)
    }
    
    deinit {
        doUpdate = false
    }
    
    func add(_ project: Project, channelId: Snowflake) async throws {
        try? await projectRepo.insert(project: project)
        try await channelRepo.insert(project: project, channelId: channelId)
    }
    
    func runUpdaterTask() {
        Task(priority: .background) {
            while doUpdate {
                await projectUpdater.runUpdate()
                try! await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
    
}


fileprivate actor ProjectRepository {
    
    let db: Connection
    
    let projects = Table("projects")
    
    let id = Expression<String>("id")
    let title = Expression<String>("title")
    let latestVersion = Expression<String>("latestVersion")
    let lastUpdate = Expression<Date>("lastUpdate")
    
    
    fileprivate init(db: Connection) {
        self.db = db
        
        let _ = try? db.run(projects.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(title)
            t.column(latestVersion)
            t.column(lastUpdate)
        })
    }
    
    func insert(project p: Project) throws {
        try db.run(projects.insert(or: .fail,
            id <- p.id,
            title <- p.title,
            latestVersion <- p.versions.last!,
            lastUpdate <- p.updated.date
        ))
    }
    
    func updateBy(project: Project) throws {
        let queryResult = projects.filter(id == project.id)
        try db.run(queryResult.update(lastUpdate <- project.updated.date, latestVersion <- project.versions.last!))
    }
    
    func selectAll() -> AnySequence<Row>? {
        return try? db.prepare(projects)
    }
    
    func deleteBy(id _id: String) throws {
        try db.run(projects.filter(id == _id).delete())
    }
    
}


fileprivate actor ChannelRepository {
    
    let db: Connection
    
    let channels = Table("channels")
    
    let projectId = Expression<String>("projectId")
    let channelId = Expression<String>("channelId")
    
    
    fileprivate init(db: Connection) {
        self.db = db
        
        let _ = try? db.run(channels.create(ifNotExists: true) { t in
            t.column(projectId)
            t.column(channelId)
        })

        Task {
            let _ = try? db.run(channels.createIndex(projectId, channels, unique: true, ifNotExists: true))
        }
    }
    
    func insert(project p: Project, channelId snowflake: Snowflake) throws {
        try db.run(channels.insert(or: .fail,
            projectId <- p.id,
            channelId <- snowflake.rawValue.description
        ))
    }
    
    func selectChannelIdsBy(project: Project) -> [String]? {
        return try? db.prepare(channels.select(channelId).where(projectId == project.id))
            .map({ $0[channelId] })
    }
    
    func selectAllBy(project: Project? = nil, projectId _projectId: String? = nil, channelId _channelId: String? = nil) -> Table? {
        var queryResult: Table?
        
        if let project = project {
            queryResult = channels.filter(projectId == project.id)
        } else if let id = _projectId {
            queryResult = channels.filter(projectId == id)
        } else if let id = _channelId {
            queryResult = channels.filter(channelId == id)
        }
        
        return queryResult
    }
    
    func deleteBy(project: Project? = nil, projectId _projectId: String? = nil, channelId _channelId: String? = nil) throws {
        guard let queryResult = selectAllBy(project: project, projectId: _projectId, channelId: _channelId) else { return }
        try db.run(queryResult.delete())
    }
    
    func deleteBy(channelId snowflake: Snowflake) throws {
        try deleteBy(channelId: snowflake.rawValue.description)
    }
}


fileprivate actor ProjectUpdater {
    
    private let logger = Logger(label: "frankv.BotModrin.ProjectUpdater")
    private let projectRepo: ProjectRepository
    private let channelRepo: ChannelRepository
    
    
    fileprivate init(projectRepo: ProjectRepository, channelRepo: ChannelRepository){
        self.projectRepo = projectRepo
        self.channelRepo = channelRepo
    }
    
    fileprivate func runUpdate() async {
        let apiService = ApiService.modrinth
        
        Task {
            guard let sequence = await projectRepo.selectAll() else { return }
            
            for row in sequence {
                let fetchResult = await apiService.fetchApi("/project/\(row[projectRepo.id])", objectType: Project.self)
                
                switch fetchResult {
                case .success(let project):
                    guard row[projectRepo.lastUpdate] < project.updated.date else { continue }
                    
                    guard let channels = await channelRepo.selectChannelIdsBy(project: project) else { continue }
                    
                    if channels.isEmpty {
                        do {
                            try await projectRepo.deleteBy(id: project.id)
                        } catch {
                            //log fail to delete
                        }
                        continue
                    }
                    
                    do {
                        try await projectRepo.updateBy(project: project)
                        await sendMessageTo(channels, project: project)
                    } catch {
                        //log fail to update
                    }
                    
                case .failure(let error):
                    logger.warning("Project \"\(row[projectRepo.id])\" faild to fetch: \(error.localizedDescription)")
                }
                
                try! await Task.sleep(nanoseconds:5_000_000_000)
            }
            
        }
    }
    
    private func sendMessageTo(_ channelIds: [String], project: Project) async {
        let bot = BotModrin.shared.swiftCord
        
        let embed = EmbedBuilder()
//            .setTitle(title: "\(project.title)")
            .setAuthor(name: project.title, url: "https://modrinth.com/mod/\(project.slug)", iconUrl: project.icon_url)
            .setDescription(description: "New file released!")
            .addField("Release channel", value: "unknow", isInline: true)
            .addField("Mod loaders", value: "unknow", isInline: true)
            .addField("Minecraft", value: "unknow", isInline: true)
//            .addField("\u200B", value: "\u200B")
            .addField("Files", value: "[\("filename")]()")
            .setTimestamp()
        
        for channelId in channelIds {
            guard let channelIdUInt = UInt64(channelId) else { continue }
            
            Task {
                let _ = try? await bot.send(embed, to: Snowflake(rawValue: channelIdUInt))
            }
        }
        
    }
        
    
}
