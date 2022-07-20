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
    
    func add(_ project: Project, latestVersion: String, channelId: Snowflake, ownerId: Snowflake) async throws {
        try? projectRepo.insert(project: project, latestVersion: latestVersion)
        try channelRepo.insert(project: project, channelId: channelId, ownerId: ownerId)
    }
    
    func remove(_ projectId: String, channelId: Snowflake) async throws {
        try channelRepo.deleteBy(projectId: projectId, channelId: channelId.rawValue.description)
    }
    
    func removeAll(in channelId: String) async throws {
        try channelRepo.deleteBy(channelId: channelId)
    }
    
    func getChannelTracking(_ channel: Snowflake) async throws -> [String] {
        guard let result = channelRepo
            .selectProjectIdsBy(channelId: channel.rawValue.description), !result.isEmpty
        else {
            throw QueryError.notFound
        }
        
        return result
    }
    
    func runUpdaterTask() {
        updateTask = Task(priority: .background) {
            while true {
                if doUpdate {
                    BotModrin.shared.logInfo("Starting to runUpdate")
                    await projectUpdater.runUpdate()
                }
                try! await Task.sleep(seconds: 180)
            }
        }
    }
    
}


fileprivate class ProjectRepository {
    
    let db: Connection
    
    let projects = Table("projects")
    
    let id = Expression<String>("id")
    let title = Expression<String>("title")
    let latestVersion = Expression<String>("latestVersion")
    let lastUpdate = Expression<Date>("lastUpdate")
    
    
    fileprivate init(db: Connection) {
        self.db = db
        
        _ = try? self.db.run(projects.create(ifNotExists: true) { t in
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
    
    func updateBy(project: Project, latestVersion v: String) throws {
        let queryResult = projects.filter(id == project.id)
        try db.run(queryResult.update(lastUpdate <- project.updated.date, title <- project.title, latestVersion <- v))
    }
    
    func selectAll() -> AnySequence<Row>? {
        return try? db.prepare(projects)
    }
    
    func selectLatestVersionBy(id: String) -> String? {
        return try? db.prepare(projects.select(latestVersion).where(self.id == id))
            .map { $0[latestVersion] }.first
    }
    
    func deleteBy(id _id: String) throws {
        try db.run(projects.filter(id == _id).delete())
    }
    
}


fileprivate class ChannelRepository {
    
    let db: Connection
    
    let channels = Table("channels")
    
    let projectId = Expression<String>("projectId")
    let channelId = Expression<String>("channelId")
    let ownerId = Expression<String>("ownerId")
    
    fileprivate init(db: Connection) {
        self.db = db
        
        _ = try? self.db.run(channels.create(ifNotExists: true) { t in
            t.column(projectId)
            t.column(channelId)
            t.column(ownerId)
        })
        
        _ = try? self.db.run(channels.createIndex(projectId, channelId, unique: true, ifNotExists: true))
    }
    
    func insert(project p: Project, channelId cId: Snowflake, ownerId oId: Snowflake) throws {
        try db.run(channels.insert(or: .fail,
                                   projectId <- p.id,
                                   channelId <- cId.rawValue.description,
                                   ownerId <- oId.rawValue.description
                                  ))
    }
    
    func selectChannelIdsBy(project: Project) -> [String]? {
        return try? db.prepare(channels.select(channelId).where(projectId == project.id))
            .map({ $0[channelId] })
    }
    
    func selectProjectIdsBy(channelId cId: String) -> [String]? {
        return try? db.prepare(channels.select(projectId).where(channelId == cId))
            .map({ $0[projectId] })
    }
    
    func selectAllBy(projectId _projectId: String? = nil, channelId _channelId: String? = nil) -> Table {
        var queryResult = channels
        
        if let id = _projectId {
            queryResult = queryResult.filter(projectId == id)
        }
        
        if let id = _channelId {
            queryResult = queryResult.filter(channelId == id)
        }
        
        return queryResult
    }
    
    func deleteBy(projectId _projectId: String? = nil, channelId _channelId: String? = nil) throws {
        let queryResult = selectAllBy(projectId: _projectId, channelId: _channelId)
        
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
        
        guard let sequence = projectRepo.selectAll() else { return }
        let projects = sequence.map { ($0[projectRepo.id], $0[projectRepo.lastUpdate]) }
        let projectsUpdated = await checkProjectUpdate(projects)
        
        for project in projectsUpdated {
            do {
                let versionFetched = await apiService.fetchApi("/project/\(project.id)/version", objectType: [Version].self)
                guard let channels = channelRepo.selectChannelIdsBy(project: project) else { continue }
                
                switch versionFetched {
                case .success(let version):
                    await sendMessageTo(channels, project: project)
                    try projectRepo.updateBy(project: project, latestVersion: version[0].id)
                    botModrin.logInfo("Project '\(project.title)' has been updated.")
                    
                case .failure(let error):
                    botModrin.logWarning("Failed fetching version on update project \"\(project.id)\" in project repository: \(error)")
                }
            } catch {
                botModrin.logWarning("Failed fetching project on update project \"\(project.id)\" in project repository: \(error)")
            }

        }
        
    }
    
    private func checkProjectUpdate(_ data: [(String, Date)]) async -> [Project] {
        let fetchSize = 10
        
        var result = [Project]()
        let data = data.chunked(into: fetchSize)
        let apiService = ApiService.modrinth
        
        for chunk in data {
            let idString = chunk.map { $0.0 }.description
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\"", with: "%22")
            let fetched = await apiService.fetchApi("/projects?ids=\(idString)", objectType: [Project].self)
            let mappedChunk = chunk.reduce(into: [String: Date]()) { $0[$1.0] = $1.1 }
            
            switch fetched {
            case .success(let projects):
                for project in projects {
                    if project.updated.date > mappedChunk[project.id]! {
                        result.append(project)
                    }
                }
                
            case .failure(let error):
                botModrin.logWarning("\(error)")
            }
            
            try! await Task.sleep(milliseconds: 500)
        }
        
        return result
    }
    
    private func sendMessageTo(_ channelIds: [String], project: Project) async {
        let bot = botModrin.swiftCord
        let fetchResult = await ApiService.modrinth.fetchApi("/project/\(project.id)/version", objectType: [Version].self)
        var embeds = [EmbedBuilder]()
        
        switch fetchResult {
        case .success(let versions):
            var newVersions = [Version]()
            for v in versions {
                guard v.id != projectRepo.selectLatestVersionBy(id: project.id) else { break }
                newVersions.append(v)
            }
            
            if newVersions.count == versions.count {
                embeds.append(createEmbed(project: project, version: versions[0]))
                break
            }
            
            for v in newVersions {
                embeds.append(createEmbed(project: project, version: v))
            }
            
        case .failure(let error):
            botModrin.logWarning("Failed on fetching Version data from modrinth: \(error)")
        }
        
        for embed in embeds {
            for channelId in channelIds {
                guard let channelIdUInt = UInt64(channelId) else { continue }
                _ = try? await bot.send(embed, to: Snowflake(rawValue: channelIdUInt))
                try! await Task.sleep(milliseconds: 200)
            }
        }
    }
    
    private func createEmbed(project: Project, version v: Version) -> EmbedBuilder {
        return EmbedBuilder()
            .setAuthor(name: project.title, url: "https://modrinth.com/\(project.project_type)/\(project.slug)", iconUrl: project.icon_url)
            .setColor(color: 1825130)
            .setDescription(description: "New file released!")
            .addField("Files", value:
                        "[\(v.files[0].filename)](https://modrinth.com/\(project.project_type)/\(project.slug)/version/\(v.version_number))" + (v.files.count > 1 ? "\n+\(v.files.count-1) file(s)" : ""))
            .addField("Release channel", value: v.version_type, isInline: true)
            .addField("Mod loaders", value: v.loaders.joined(separator: ", "), isInline: true)
            .addField("Minecraft", value: v.game_versions.joined(separator: ", "), isInline: true)
    }
    
}
