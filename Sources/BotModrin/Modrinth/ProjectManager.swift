//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import SQLite
import Swiftcord


enum QueryError: Error {
    case notFound
}


class ProjectManager {
    
    private let apiService = ApiService.modrinth
    fileprivate let projectRepo: ProjectRepository
    fileprivate let channelRepo: ChannelRepository
    private lazy var projectUpdater = ProjectUpdater(projectRepo: projectRepo, channelRepo: channelRepo)
    
    private var updateTask: Task<(), Never>?
    
    var doUpdate = true
    
    
    init (_ main: BotModrin) {
        projectRepo = ProjectRepository(db: main.db!)
        channelRepo = ChannelRepository(db: main.db!)
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    func add(_ project: Project, latestVersion: String, channelId: Snowflake) async throws {
        try? await projectRepo.insert(project: project, latestVersion: latestVersion)
        try await channelRepo.insert(project: project, channelId: channelId)
    }
    
    func remove(_ projectId: String, channelId: Snowflake) async throws {
        try await channelRepo.deleteBy(projectId: projectId, channelId: channelId.rawValue.description)
    }
    
    func runUpdaterTask() {
        updateTask = Task(priority: .background) {
            while true {
                if doUpdate {
                    await projectUpdater.runUpdate()
                }
                try! await Task.sleep(seconds: 5)
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
    
    func insert(project p: Project, latestVersion v: String) throws {
        try db.run(projects.insert(or: .fail,
            id <- p.id,
            title <- p.title,
            latestVersion <- v,
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
            let _ = try? db.run(channels.createIndex(projectId, channelId, unique: true, ifNotExists: true))
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
    
    func selectAllBy(projectId _projectId: String? = nil, channelId _channelId: String? = nil) -> Table? {
        var queryResult: Table?
        
        if let id = _projectId {
            queryResult = channels.filter(projectId == id)
        }
        
        if let id = _channelId {
            queryResult = channels.filter(channelId == id)
        }
        
        return queryResult
    }
    
    func deleteBy(projectId _projectId: String? = nil, channelId _channelId: String? = nil) throws {
        guard let queryResult = selectAllBy(projectId: _projectId, channelId: _channelId) else { return }
        
        if (try? db.scalar(queryResult.count)) == 0 {
            throw QueryError.notFound
        }
        
        try db.run(queryResult.delete())
    }
    
}


fileprivate actor ProjectUpdater {
    
    private let botModrin = BotModrin.shared
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
                            botModrin.logWarning("Failed on delete project \"\(project.id)\" in database project repository: \(error.localizedDescription)")
                        }
                        continue
                    }
                    
                    do {
                        try await projectRepo.updateBy(project: project)
                        await sendMessageTo(channels, project: project, localVersion: row[projectRepo.latestVersion])
                    } catch {
                        botModrin.logWarning("Failed on update project \"\(project.id)\" in project repository: \(error.localizedDescription)")
                    }
                    
                case .failure(let error):
                    botModrin.logWarning("Project \"\(row[projectRepo.id])\" faild to fetch: \(error.localizedDescription)")
                }
                
                try! await Task.sleep(milliseconds: 500)
            }
            
        }
    }
    
    private func sendMessageTo(_ channelIds: [String], project: Project, localVersion: String) async {
        let bot = botModrin.swiftCord
        let fetchResult = await ApiService.modrinth.fetchApi("/project/\(project.id)/version", objectType: [Version].self)
        var embeds = [EmbedBuilder]()
        
        switch fetchResult {
        case .success(let versions):
            for v in versions {
                guard v.id != localVersion else { break }
                embeds.append(createEmbed(project: project, version: v))
            }
            
        case .failure(let error):
            botModrin.logWarning("Failed on fetching Version data from modrinth: \(error.localizedDescription)")
        }
        
        for embed in embeds {
            for channelId in channelIds {
                guard let channelIdUInt = UInt64(channelId) else { continue }
                let _ = try? await bot.send(embed, to: Snowflake(rawValue: channelIdUInt))
            }
        }
    }
    
    private func createEmbed(project: Project, version v: Version) -> EmbedBuilder {
        return EmbedBuilder()
            .setAuthor(name: project.title, url: "https://modrinth.com/mod/\(project.slug)", iconUrl: project.icon_url)
            .setColor(color: 1825130)
            .setDescription(description: "New file released!")
            .addField("Files", value:
                        "[\(v.files[0].filename)](https://modrinth.com/mod/\(project.slug)/version/\(v.version_number)" + (v.files.count > 1 ? "\n+\(v.files.count-1) file(s)" : ""))
            .addField("Release channel", value: v.version_type, isInline: true)
            .addField("Mod loaders", value: v.loaders.joined(separator: ", "), isInline: true)
            .addField("Minecraft", value: v.game_versions.joined(separator: ", "), isInline: true)
    }
    
}
