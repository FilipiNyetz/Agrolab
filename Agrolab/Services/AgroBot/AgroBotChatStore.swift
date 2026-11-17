//
//  AgroBotChatStore.swift
//  Agrolab
//

import Foundation
import SwiftData

/// Sessão de conversa do AgroBot, sempre vinculada ao produtor dono (RNF-008: sem acesso cruzado).
@Model
final class AgroBotChatRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: String
    var title: String
    var topic: String?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \AgroBotMessageRecord.chat)
    var messages: [AgroBotMessageRecord] = []

    init(id: UUID = UUID(), ownerID: String, title: String, topic: String?, createdAt: Date = Date()) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.topic = topic
        self.createdAt = createdAt
    }
}

@Model
final class AgroBotMessageRecord {
    @Attribute(.unique) var id: UUID
    var role: String
    var content: String
    var createdAt: Date
    var chat: AgroBotChatRecord?

    init(id: UUID, role: String, content: String, createdAt: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

/// Persistência local (SwiftData) das conversas com o AgroBot. As conversas não saem do aparelho.
@MainActor
final class AgroBotChatStore {
    private let context: ModelContext

    init(inMemory: Bool = false) {
        let schema = Schema([AgroBotChatRecord.self, AgroBotMessageRecord.self])
        let configuration = ModelConfiguration("AgroBot", schema: schema, isStoredInMemoryOnly: inMemory)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Sem disco disponível, a conversa continua funcionando só na memória.
            let memory = ModelConfiguration("AgroBot", schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: memory)
        }
        context = ModelContext(container)
    }

    func latestChatID(ownerID: String) throws -> UUID? {
        var descriptor = FetchDescriptor<AgroBotChatRecord>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.id
    }

    func createChat(ownerID: String, title: String, topic: String? = nil) throws -> UUID {
        let chat = AgroBotChatRecord(ownerID: ownerID, title: title, topic: topic)
        context.insert(chat)
        try context.save()
        return chat.id
    }

    func messages(in chatID: UUID) throws -> [AgroBotMessage] {
        guard let chat = try chat(chatID) else { return [] }
        return chat.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { AgroBotMessage(id: $0.id, role: AgroBotRole(rawValue: $0.role) ?? .assistant, content: $0.content, createdAt: $0.createdAt) }
    }

    func topic(of chatID: UUID) throws -> String? {
        try chat(chatID)?.topic
    }

    func append(_ message: AgroBotMessage, to chatID: UUID) throws {
        guard let chat = try chat(chatID) else { return }
        let record = AgroBotMessageRecord(id: message.id, role: message.role.rawValue, content: message.content, createdAt: message.createdAt)
        record.chat = chat
        context.insert(record)
        try context.save()
    }

    /// Apaga todas as conversas do produtor (exclusão de conta, LGPD / RNF-015).
    func deleteAll(ownerID: String) throws {
        let chats = try context.fetch(FetchDescriptor<AgroBotChatRecord>(predicate: #Predicate { $0.ownerID == ownerID }))
        chats.forEach(context.delete)
        try context.save()
    }

    private func chat(_ id: UUID) throws -> AgroBotChatRecord? {
        var descriptor = FetchDescriptor<AgroBotChatRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
