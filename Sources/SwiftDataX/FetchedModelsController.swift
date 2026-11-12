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
        guard let changes = ModelContextChanges(notification: notification, modelContext: modelContext) else { return }

        delegate?.controllerWillChangeContent(self)

        // Work with an ordered mutable array copy
        var currentModels = fetchedModels ?? []

        // 1. Resolve changed models of this controller's type
        let insertedModels = changes.inserted(T.self)
        let updatedModels  = changes.updated(T.self)
        let deletedModels  = changes.deleted(T.self)

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
