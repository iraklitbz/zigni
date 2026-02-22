//
//  Quote.swift
//  zigni
//

import Foundation

struct Quote: Identifiable, Codable {
    var id: UUID = UUID()
    var bookTitle: String = ""
    var text: String = ""
    var createdAt: Date = Date()
}
