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
    private let repo = ProjectRepository.shared
    private let projectUpdater = ProjectUpdater.shared
    var doUpdate = true
    
    init() {
        runUpdater()
    }
    
    deinit {
        doUpdate = false
    }
    
    func add(_ project: Project, channelId: Snowflake) {
        Task {
            do {
                try await repo.insert(project: project, channelId: channelId)
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }
    }
    
    func runUpdater() {
        Task(priority: .background) {
            while doUpdate {
                try? await projectUpdater.runUpdate()
                try! await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
    
}


fileprivate actor ProjectRepository {
    
    fileprivate static let shared = ProjectRepository(db: BotModrin.shared.db!)
    
    let db: Connection
    
    let projects = Table("projects")
    
    let id = Expression<String>("id")
    let title = Expression<String>("title")
    let latestVersion = Expression<String>("latestVersion")
    let lastUpdate = Expression<Date>("lastUpdate")
    let channelId = Expression<String>("channelId")
    
    
    private init(db: Connection) {
        self.db = db
        
        let _ = try? db.run(projects.create { t in
            t.column(id, primaryKey: true)
            t.column(title)
            t.column(latestVersion)
            t.column(lastUpdate)
            t.column(channelId)
        })
    }
    
    func insert(project p: Project, channelId snowflake: Snowflake) throws {
        try db.run(projects.insert(
            id <- p.id,
            title <- p.title,
            latestVersion <- p.versions.last!,
            lastUpdate <- p.updated.date,
            channelId <- "\(snowflake.rawValue)"
        ))
    }
    
}


actor ProjectUpdater {
    
    fileprivate static let shared = ProjectUpdater()
    
    private let logger = Logger(label: "frankv.BotModrin.ProjectUpdater")
    private let repo = ProjectRepository.shared
    
    
    fileprivate init(){}
    
    func runUpdate() async throws {
        let apiService = ApiService.modrinth
        
        Task {
            for row in try repo.db.prepare(repo.projects) {
                let fetchResult = await apiService.fetchApi("/project/\(row[repo.id])", objectType: Project.self)
                
                switch fetchResult {
                case .success(let project):
                    guard row[repo.lastUpdate] < project.updated.date else { break }

                    await sendMessageTo(row[repo.channelId], projectId: row[repo.id], fileId: project.versions.last!)
                    
                case .failure(let error):
                    logger.warning("Project \"\(row[repo.id])\" faild to fetch: \(error.localizedDescription)")
                }
                
                try! await Task.sleep(nanoseconds:5_000_000_000)
            }
            
        }
    }
    
    private func sendMessageTo(_ channelId: String, projectId: String, fileId: String) async {
        let bot = BotModrin.shared.swiftCord
        
        guard let channelIdUInt = UInt64(channelId) else { return }
        
        let embed = EmbedBuilder()
            .setTitle(title: "New file released!")
            .addField("Mod: ", value: projectId)
            .addField("File", value: fileId)
            .setTimestamp()
        
        let _ = try? await bot.send(embed, to: Snowflake(rawValue: channelIdUInt))
    }
    
}
