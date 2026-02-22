//
//  Quote.swift
//  zigni
//
//  Un `Quote` representa una TARJETA DE LIBRO.
//  Puede contener múltiples frases (passages) del mismo libro.
//  Al migrar desde el formato antiguo (text: String), se convierte automáticamente.
//

import Foundation

// Una frase individual dentro de una tarjeta de libro
struct Passage: Identifiable, Codable {
    var id: UUID   = UUID()
    var text: String = ""
    var createdAt: Date = Date()
}

// Tarjeta de libro — puede tener N frases
struct Quote: Identifiable, Codable {
    var id: UUID         = UUID()
    var bookTitle: String = ""
    var passages: [Passage] = []
    var updatedAt: Date  = Date()

    // Accesos rápidos
    var lastPassage: Passage?  { passages.last }
    var passageCount: Int      { passages.count }

    // ── Init cómodo para crear desde título + texto ───────────────────
    init(
        id: UUID = UUID(),
        bookTitle: String = "",
        text: String = "",
        createdAt: Date = Date()
    ) {
        self.id        = id
        self.bookTitle = bookTitle
        self.passages  = text.isEmpty ? [] : [Passage(text: text, createdAt: createdAt)]
        self.updatedAt = createdAt
    }

    // Init directo con passages (para QuotesStore)
    init(
        id: UUID = UUID(),
        bookTitle: String = "",
        passages: [Passage] = [],
        updatedAt: Date = Date()
    ) {
        self.id        = id
        self.bookTitle = bookTitle
        self.passages  = passages
        self.updatedAt = updatedAt
    }

    // ── Codable: migración desde formato antiguo (text: String) ───────
    enum CodingKeys: String, CodingKey {
        case id, bookTitle, passages, updatedAt
        case legacyText      = "text"
        case legacyCreatedAt = "createdAt"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self, forKey: .id)
        bookTitle = try c.decodeIfPresent(String.self, forKey: .bookTitle) ?? ""
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
                 ?? c.decodeIfPresent(Date.self, forKey: .legacyCreatedAt)
                 ?? Date()

        if let existing = try c.decodeIfPresent([Passage].self, forKey: .passages) {
            passages = existing
        } else if let old = try c.decodeIfPresent(String.self, forKey: .legacyText), !old.isEmpty {
            // Migración automática desde el modelo anterior
            passages = [Passage(text: old, createdAt: updatedAt)]
        } else {
            passages = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(bookTitle, forKey: .bookTitle)
        try c.encode(passages,  forKey: .passages)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}
