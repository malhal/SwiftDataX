import Foundation
import SwiftData

extension ModelContext {
    /// Private SwiftData notification that `@Query` observes. Its `userInfo` includes deleted
    /// unsaved models, which the context itself no longer tracks. Parse it with `ModelContextChanges`.
    public static let didChangeX = NSNotification.Name(rawValue: "_SwiftDataModelsChangedInContextNotificationPrivate")
}

/// The inserted, updated and deleted models parsed from a `ModelContext.didChangeX`
/// (`_SwiftDataModelsChangedInContextNotificationPrivate`) notification.
public struct ModelContextChanges {
    public let inserted: [any PersistentModel]
    public let updated: [any PersistentModel]
    public let deleted: [any PersistentModel]
    
    /// Returns nil if the notification has no `userInfo`.
    /// - Parameter modelContext: Used to resolve models when the payload only contains identifiers.
    public init?(notification: Notification, modelContext: ModelContext) {
        guard let userInfo = notification.userInfo else { return nil }
        
        // Resolve payloads checking multiple possible OS/runtime key variants
        let insertedPayload = userInfo["inserted"] ?? userInfo["inserted_objectIDs"] ?? userInfo["insertedObjects"]
        let updatedPayload  = userInfo["updated"]  ?? userInfo["updated_objectIDs"]  ?? userInfo["updatedObjects"]
        let deletedPayload  = userInfo["deleted"]  ?? userInfo["deleted_objectIDs"]  ?? userInfo["deletedObjects"]
        
        inserted = Self.resolveModels(from: insertedPayload, modelContext: modelContext)
        updated  = Self.resolveModels(from: updatedPayload, modelContext: modelContext)
        deleted  = Self.resolveModels(from: deletedPayload, modelContext: modelContext)
    }
    
    // MARK: - Typed Accessors
    
    public func inserted<T: PersistentModel>(_ type: T.Type = T.self) -> [T] {
        inserted.compactMap { $0 as? T }
    }
    
    public func updated<T: PersistentModel>(_ type: T.Type = T.self) -> [T] {
        updated.compactMap { $0 as? T }
    }
    
    public func deleted<T: PersistentModel>(_ type: T.Type = T.self) -> [T] {
        deleted.compactMap { $0 as? T }
    }
    
    // MARK: - Unified Model Resolution Helper
    
    private static func resolveModels(from payload: Any?, modelContext: ModelContext) -> [any PersistentModel] {
        let rawModels = extractModels(from: payload)
        if !rawModels.isEmpty {
            return rawModels
        } else if let ids = extractIdentifiers(from: payload) {
            return ids.map { modelContext.model(for: $0) }
        }
        return []
    }
    
    // MARK: - Helper Utilities
    
    private static func extractModels(from value: Any?) -> [any PersistentModel] {
        var models: [any PersistentModel] = []
        
        // Unwrap optional collection if necessary
        var targetCollection: Any = value ?? []
        let mirror = Mirror(reflecting: value as Any)
        if mirror.displayStyle == .optional, let first = mirror.children.first {
            targetCollection = first.value
        }
        
        // Iterate through the collection items generically
        if let sequence = targetCollection as? any Sequence {
            for element in sequence {
                // 1. Direct model instance match
                if let model = element as? (any PersistentModel) {
                    models.append(model)
                }
                // 2. Wrapped internal object (e.g., AnyPersistentObject with a 'boxed' property)
                else {
                    let elementMirror = Mirror(reflecting: element)
                    for child in elementMirror.children {
                        if child.label == "boxed", let model = child.value as? (any PersistentModel) {
                            models.append(model)
                        }
                    }
                }
            }
        }
        return models
    }
    
    private static func extractIdentifiers(from value: Any?) -> Set<PersistentIdentifier>? {
        if let set = value as? Set<PersistentIdentifier> {
            return set
        }
        if let array = value as? [PersistentIdentifier] {
            return Set(array)
        }
        return nil
    }
}
