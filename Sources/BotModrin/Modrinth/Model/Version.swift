//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

struct Version: Hashable, Identifiable, Codable {
    let name: String
    let version_number: String
    let changelog: String?
    let dependencies: [Dependency]?
    let game_versions: [String]
    let version_type: String
    let loaders: [String]
    let featured: Bool
    let id: String
    let project_id: String
    let author_id: String
    let date_published: String
    let downloads: Int
    let changelog_url: String?
    let files: [File]
}


struct Dependency: Hashable, Codable {
    let version_id: String?
    let project_id: String?
    let dependency_type: String
}


struct File: Hashable, Codable {
    let hashes: [String:String]
    let url: String
    let filename: String
    let primary: Bool
    let size: Int
}
