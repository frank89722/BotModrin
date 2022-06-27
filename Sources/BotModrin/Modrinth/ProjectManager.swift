//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

import Foundation
import SQLite
import Logging

class ProjectManager {
    
    private let logger = Logger(label: "frankv.BotModrin.ProjectManager")
    
    private let apiService = ApiService.modrinth
    private let repo = ProjectRepository.shared
    
    
    func add(_ project: Project) {
        do {
            try repo.insert(project: project)
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    
    func getAll() {
        
    }
    
}

fileprivate class ProjectRepository {
    fileprivate static let shared = ProjectRepository(db: BotModrin.shared.db!)
    
    let db: Connection
    
    let projects = Table("projects")
    
    let id = Expression<String>("id")
    let title = Expression<String>("title")
    let latestVersion = Expression<String>("latestVersion")
    let lastUpdate = Expression<Date>("lastUpdate")
    let channelId = Expression<String>("channelId")
    
    
    init(db: Connection) {
        self.db = db
        
        let _ = try? db.run(projects.create { t in
            t.column(id, primaryKey: true)
            t.column(title)
            t.column(latestVersion)
            t.column(lastUpdate)
            t.column(channelId)
        })
    }
    
    
    func insert(project p: Project) throws {
        try db.run(projects.insert(id <- p.id, title <- p.title, latestVersion <- p.versions.last!, lastUpdate <- p.updated.date))
    }
    
}

extension ProjectRepository {
    
    func runUpdate() async throws {
        let apiService = ApiService.modrinth
        
        try db.prepare(projects).forEach { row in
            Task {
                let fetchResult = await apiService.fetchApi("/project/\(row[id])", objectType: Project.self)
                
                switch fetchResult {
                case .success(let project):
                    guard row[lastUpdate] < project.updated.date else { break }

                    //Todo: do update thing
                    print("")
                    
                case .failure:
                    //Todo: remove the thing
                    break
                }
                
                try! await Task.sleep(nanoseconds:500_000_000)
            }
            
        }
    }
    
}
