//
//  QuotesStore.swift
//  zigni
//

import Foundation
import Observation

@Observable
class QuotesStore {
    var quotes: [Quote] = []

    private let saveURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("zigni_quotes.json")
    }()

    init() {
        load()
        if quotes.isEmpty {
            quotes = Self.defaultQuotes
            save()
        }
    }

    // MARK: - Operaciones

    @discardableResult
    func addQuote() -> Quote {
        let q = Quote()
        quotes.insert(q, at: 0)
        // No guardamos todavía: el usuario puede cancelar sin escribir nada
        return q
    }

    func update(_ quote: Quote) {
        guard let i = quotes.firstIndex(where: { $0.id == quote.id }) else { return }
        quotes[i] = quote
        save()
    }

    func delete(_ quote: Quote) {
        quotes.removeAll { $0.id == quote.id }
        save()
    }

    // MARK: - Persistencia

    func save() {
        guard let data = try? JSONEncoder().encode(quotes) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: saveURL),
            let decoded = try? JSONDecoder().decode([Quote].self, from: data)
        else { return }
        quotes = decoded
    }

    // MARK: - Citas de ejemplo (primer arranque)

    private static let defaultQuotes: [Quote] = [
        Quote(
            bookTitle: "El Principito",
            text: "Lo esencial es invisible a los ojos. Solo se ve bien con el corazón.",
            createdAt: Date().addingTimeInterval(-86400 * 1)
        ),
        Quote(
            bookTitle: "Cien años de soledad",
            text: "No llores porque ya se acabó. Sonríe porque sucedió.",
            createdAt: Date().addingTimeInterval(-86400 * 3)
        ),
        Quote(
            bookTitle: "Kafka en la orilla",
            text: "Perderse en ocasiones no es siempre un error.",
            createdAt: Date().addingTimeInterval(-86400 * 6)
        ),
        Quote(
            bookTitle: "Siddhartha",
            text: "La sabiduría no puede transmitirse. La sabiduría que un sabio intenta transmitir suena siempre como una tontería.",
            createdAt: Date().addingTimeInterval(-86400 * 10)
        ),
        Quote(
            bookTitle: "1984",
            text: "Si quieres tener un secreto, debes ocultártelo también a ti mismo.",
            createdAt: Date().addingTimeInterval(-86400 * 14)
        ),
        Quote(
            bookTitle: "La insoportable levedad del ser",
            text: "La felicidad es el anhelo de la repetición.",
            createdAt: Date().addingTimeInterval(-86400 * 20)
        ),
        Quote(
            bookTitle: "El nombre de la rosa",
            text: "Los libros no están hechos para que creamos lo que dicen, sino para que los examinemos.",
            createdAt: Date().addingTimeInterval(-86400 * 27)
        ),
        Quote(
            bookTitle: "Stoner",
            text: "Un hombre que trabaja con sus manos, su mente y su corazón, con amor e imaginación, puede lograr la grandeza.",
            createdAt: Date().addingTimeInterval(-86400 * 35)
        ),
        Quote(
            bookTitle: "Don Quijote de la Mancha",
            text: "El que lee mucho y anda mucho, ve mucho y sabe mucho.",
            createdAt: Date().addingTimeInterval(-86400 * 45)
        ),
        Quote(
            bookTitle: "Ficciones",
            text: "El tiempo se bifurca perpetuamente hacia innumerables futuros.",
            createdAt: Date().addingTimeInterval(-86400 * 60)
        ),
    ]
}
