import Foundation
import SwiftData
import CoreData
import UIKit

public enum FetchedModelsChangeType : UInt, @unchecked Sendable {
    case insert = 1
    case delete = 2
    case move = 3
    case update = 4
}

public protocol FetchedModelsControllerDelegate: AnyObject {
    func controllerWillChangeContent<T>(_ controller: FetchedModelsController<T>)
    func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>)
    
    func controller<T>(_ controller: FetchedModelsController<T>, didChange anObject: T, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
}

extension FetchedModelsControllerDelegate {
    public func controllerWillChangeContent<T>(_ controller: FetchedModelsController<T>) {}
    public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) {}
    
    func controller<T>(_ controller: FetchedModelsController<T>, didChange anObject: T, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {}
}

@MainActor
public class FetchedModelsController<T: PersistentModel> {
    
    public let modelContext: ModelContext
    public weak var delegate: FetchedModelsControllerDelegate? {
        didSet {
            if oldValue != nil {
                NotificationCenter.default.removeObserver(self)
            }
            if delegate != nil {
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(update),
                                                       name: ModelContext.didChangeX,
                                                       // name: ModelContext.willProcessPendingChangesX,
                                                       // name: NSManagedObjectContext.didChangeObjectsNotification,
                                                       object: modelContext)
                //object: nil)
                
                //                NotificationCenter.default.addObserver(self,
                //                                                       selector: #selector(update),
                //                                                       name: ModelContext.willSave, // "ModelContextWillSave"
                //                                                       object: modelContext)
            }
        }
    }
    
    public private(set) var fetchedModels: [T]? = nil
    
    public var fetchDescriptor: FetchDescriptor<T>
    
    init(fetchDescriptor: FetchDescriptor<T>, modelContext: ModelContext) {
        self.fetchDescriptor = fetchDescriptor
        self.modelContext = modelContext
    }
    
    @objc private func update(from notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        delegate?.controllerWillChangeContent(self)
        
        // Work with an ordered mutable array copy
        var currentModels = fetchedModels ?? []
        
        // 1. Resolve payloads checking multiple possible OS/runtime key variants
        let insertedPayload = userInfo["inserted"] ?? userInfo["inserted_objectIDs"] ?? userInfo["insertedObjects"]
        let updatedPayload  = userInfo["updated"]  ?? userInfo["updated_objectIDs"]  ?? userInfo["updatedObjects"]
        let deletedPayload  = userInfo["deleted"]  ?? userInfo["deleted_objectIDs"]  ?? userInfo["deletedObjects"]
        
        let insertedModels = resolveModels(from: insertedPayload)
        let updatedModels  = resolveModels(from: updatedPayload)
        let deletedModels  = resolveModels(from: deletedPayload)
        
        // 2. Handle Deletions
        for model in deletedModels {
            if let index = currentModels.firstIndex(of: model) {
                let indexPath = IndexPath(item: index, section: 0)
                currentModels.remove(at: index)
                delegate?.controller(self, didChange: model, at: indexPath, for: .delete, newIndexPath: nil)
            }
        }
        
        // 3. Handle Insertions
        for model in insertedModels {
            if matchesPredicate(model), !currentModels.contains(model) {
                currentModels.append(model)
                currentModels.sort(using: fetchDescriptor.sortBy)
                
                if let newIndex = currentModels.firstIndex(of: model) {
                    let newIndexPath = IndexPath(item: newIndex, section: 0)
                    delegate?.controller(self, didChange: model, at: nil, for: .insert, newIndexPath: newIndexPath)
                }
            }
        }
        
        // 4. Handle Updates
        for model in updatedModels {
            let oldIndex = currentModels.firstIndex(of: model)
            let wasPresent = oldIndex != nil
            let matches = matchesPredicate(model)
            
            if wasPresent && !matches {
                // Fell out of predicate filter -> Delete
                let oldIndex = oldIndex!
                let indexPath = IndexPath(item: oldIndex, section: 0)
                currentModels.remove(at: oldIndex)
                delegate?.controller(self, didChange: model, at: indexPath, for: .delete, newIndexPath: nil)
                
            } else if !wasPresent && matches {
                // Newly matches predicate -> Insert
                currentModels.append(model)
                currentModels.sort(using: fetchDescriptor.sortBy)
                
                if let newIndex = currentModels.firstIndex(of: model) {
                    let newIndexPath = IndexPath(item: newIndex, section: 0)
                    delegate?.controller(self, didChange: model, at: nil, for: .insert, newIndexPath: newIndexPath)
                }
                
            } else if wasPresent && matches {
                // Existing item updated -> Check if its sort position moved
                let oldIndex = oldIndex!
                let oldIndexPath = IndexPath(item: oldIndex, section: 0)
                
                // Re-sort to see if order changed
                currentModels.sort(using: fetchDescriptor.sortBy)
                let newIndex = currentModels.firstIndex(of: model)!
                let newIndexPath = IndexPath(item: newIndex, section: 0)
                
                if oldIndex != newIndex {
                    delegate?.controller(self, didChange: model, at: oldIndexPath, for: .move, newIndexPath: newIndexPath)
                } else {
                    delegate?.controller(self, didChange: model, at: oldIndexPath, for: .update, newIndexPath: newIndexPath)
                }
            }
        }
        
        // 5. Finalize
        if currentModels != fetchedModels {
            self.fetchedModels = currentModels
        }
        
        delegate?.controllerDidChangeContent(self)
    }
    
    // MARK: - Unified Model Resolution Helper
    private func resolveModels(from payload: Any?) -> [T] {
        var candidateModels: [T] = []
        
        let rawModels = extractModels(from: payload)
        if !rawModels.isEmpty {
            candidateModels = rawModels.compactMap { $0 as? T }
        } else if let ids = extractIdentifiers(from: payload) {
            candidateModels = ids.compactMap { modelContext.model(for: $0) as? T }
        }
        
        return candidateModels
    }
    
    
    // MARK: - Helper Utilities
    
    private func extractModels(from value: Any?) -> [any PersistentModel] {
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
    
    private func extractIdentifiers(from value: Any?) -> Set<PersistentIdentifier>? {
        if let set = value as? Set<PersistentIdentifier> {
            return set
        }
        if let array = value as? [PersistentIdentifier] {
            return Set(array)
        }
        return nil
    }
    
    private func matchesPredicate(_ model: T) -> Bool {
        guard let predicate = fetchDescriptor.predicate else { return true }
        do {
            return try [model].filter(predicate).isEmpty == false
        } catch {
            print("Predicate evaluation error: \(error)")
            return false
        }
    }
    
    //    @objc private func contextDidSave(_ notification: Notification) {
    //        //fetchInfo?.reset()
    //    }
    
    public func performFetch() throws {
        //        var fd = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        //        fd.includePendingChanges = false
        //
        //        // if not fetching all properties then add in at least the sort properties
        //        if !nonSortingPropertiesToFetch.isEmpty {
        //            let sortByKeyPaths = sortBy.compactMap(\.keyPath)
        //            let properties = Set(nonSortingPropertiesToFetch).union(sortByKeyPaths)
        //            fd.propertiesToFetch = Array(properties)
        //        }
        //self.fetchInfo = try FetchInfo(modelContext: modelContext, fetchDescriptor: fd)
        fetchedModels = try modelContext.fetch(fetchDescriptor)
    }
    
    
    deinit {
        print("deinit")
        NotificationCenter.default.removeObserver(self)
    }
}
