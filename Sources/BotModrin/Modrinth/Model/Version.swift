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
    let dependencies: [String]?
    let game_version: [String]?
    let version_type: String
    let loaders: [String]
    let featured: Bool
    let id: String
    let project_id: String
    let author_id: String
    let date_published: String
    let downloads: Int
    let files: [String]
}
