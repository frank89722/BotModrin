//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/25.
//

struct Project: Hashable, Identifiable, Codable {
    let slug: String
    let title: String
    let description: String
    let categories: [String]
    let client_side: String
    let server_side: String
    let body: String
    let issues_url: String?
    let source_url: String?
    let wiki_url: String?
    let discord_url: String?
    let donation_urls: [[String:String]]
    let project_type: String
    let downloads: Int
    let icon_url: String?
    let id: String
    let team: String
    let body_url: String?
    let moderator_message: String?
    let published: String
    let updated: String
    let followers: Int
    let status: String
    let license: [String:String]
    let versions: [String]
    let gallery: [[String:String]]
}
