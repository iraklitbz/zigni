//
//  BookService.swift
//  zigni
//
//  Consulta la Google Books API (gratuita, sin API key) y cachea los resultados en memoria.
//  Endpoint: https://www.googleapis.com/books/v1/volumes?q=intitle:TITULO&maxResults=1
//

import Foundation
import Observation

struct BookInfo {
    let authors: String
    let description: String
    let coverURL: URL?
}

@Observable
final class BookService {
    static let shared = BookService()

    // Resultados encontrados
    private var cache: [String: BookInfo] = [:]
    // Títulos ya buscados sin resultado (para no repetir la llamada)
    private var notFound: Set<String> = []
    // Títulos cuya llamada está en vuelo (evita duplicados)
    private var inFlight: Set<String> = []

    private init() {}

    func fetch(title: String) async -> BookInfo? {
        let key = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        // Caché de éxito
        if let cached = cache[key] { return cached }
        // Ya se buscó y no había resultado
        if notFound.contains(key) { return nil }
        // Llamada ya en vuelo
        if inFlight.contains(key) { return nil }

        inFlight.insert(key)
        defer { inFlight.remove(key) }

        guard
            let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string:
                "https://www.googleapis.com/books/v1/volumes" +
                "?q=intitle:\(encoded)" +
                "&maxResults=1" +
                "&fields=items(volumeInfo(authors,description,imageLinks))"
            )
        else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(BooksResponse.self, from: data)

            guard let info = response.items?.first?.volumeInfo else {
                notFound.insert(key)
                return nil
            }

            // Las URLs de portada vienen en http:// → cambiar a https://
            var coverURL: URL? = nil
            if var raw = info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail {
                raw = raw.replacingOccurrences(of: "http://", with: "https://")
                // Subir calidad: zoom=0 → zoom=1
                raw = raw.replacingOccurrences(of: "zoom=1", with: "zoom=2")
                coverURL = URL(string: raw)
            }

            let result = BookInfo(
                authors:     info.authors?.joined(separator: " · ") ?? "",
                description: info.description?.cleanedHTML ?? "",
                coverURL:    coverURL
            )
            cache[key] = result
            return result

        } catch {
            notFound.insert(key)
            return nil
        }
    }
}

// MARK: - Decodables (privados)

private struct BooksResponse: Decodable {
    let items: [BookItem]?
}
private struct BookItem: Decodable {
    let volumeInfo: VolumeInfo?
}
private struct VolumeInfo: Decodable {
    let authors: [String]?
    let description: String?
    let imageLinks: ImageLinks?
}
private struct ImageLinks: Decodable {
    let smallThumbnail: String?
    let thumbnail: String?
}

private extension String {
    /// Elimina etiquetas HTML básicas y decodifica entidades comunes
    var cleanedHTML: String {
        self
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "  +",    with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
