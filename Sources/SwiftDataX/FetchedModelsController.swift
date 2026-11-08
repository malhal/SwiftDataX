import Foundation
import SwiftData
import CoreData

public protocol FetchedModelsControllerDelegate: AnyObject {
    func controllerWillChangeContent<T>(_ controller: FetchedModelsController<T>)
    func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>)
}

extension FetchedModelsControllerDelegate {
    public func controllerWillChangeContent<T>(_ controller: FetchedModelsController<T>) {}
    public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) {}
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
                
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(update),
                                                       name: ModelContext.willSave, // "ModelContextWillSave"
                                                       object: modelContext)
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
        delegate?.controllerWillChangeContent(self)
        
        guard let userInfo = notification.userInfo else {
            // Fallback or exit if no payload is present
            return
        }
        
        var itemSet = Set(fetchedModels ?? [])
        
        // 1. Handle Deletions
        if let deletedIDs = extractIdentifiers(from: userInfo["deleted"]) {
            itemSet = Set(itemSet.filter { !deletedIDs.contains($0.persistentModelID) })
        }
        
        // 2. Handle Insertions
        if let insertedIDs = extractIdentifiers(from: userInfo["inserted"]) {
            for id in insertedIDs {
                if let model = modelContext.model(for: id) as? T {
                    if matchesPredicate(model) {
                        itemSet.insert(model)
                    }
                }
            }
        }
        
        // 3. Handle Updates / Changes
        if let updatedIDs = extractIdentifiers(from: userInfo["updated"]) {
            for id in updatedIDs {
                let existingIndex = itemSet.firstIndex(where: { $0.persistentModelID == id })
                
                if let model = modelContext.model(for: id) as? T {
                    if matchesPredicate(model) {
                        // Update value or insert if it newly matches
                        if let existingIndex = existingIndex {
                            itemSet.remove(at: existingIndex)
                        }
                        itemSet.insert(model)
                    } else {
                        // No longer matches predicate, drop it
                        if let existingIndex = existingIndex {
                            itemSet.remove(at: existingIndex)
                        }
                    }
                } else {
                    // Model couldn't be loaded or was removed
                    if let existingIndex = existingIndex {
                        itemSet.remove(at: existingIndex)
                    }
                }
            }
        }
        
        let sorted = Array(itemSet).sorted(using: fetchDescriptor.sortBy)
        if sorted != fetchedModels {
            self.fetchedModels = sorted
        }
        
        delegate?.controllerDidChangeContent(self)
    }
    
    // MARK: - Helper Utilities
    
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
    
//    @objc private func update(from notification: Notification) {
//        // guard let userInfo = notification.userInfo else { return }
//        delegate?.controllerWillChangeContent(self)
//        
//        var items = Set(fetchedModels ?? [])
//        
//        let changes = modelContext.changedModelsArray.compactMap { $0 as? T }
//        if !changes.isEmpty {
//            if let predicate = fetchDescriptor.predicate {
//                do {
//                    items.subtract(changes)
//                    let changedMatches = try changes.filter(predicate)
//                    items.formUnion(changedMatches)
//                }
//                catch { print(error) }
//            }
//        }
//        
//        var inserted = modelContext.insertedModelsArray.compactMap { $0 as? T }
//        if let predicate = fetchDescriptor.predicate {
//            do {
//                inserted = try inserted.filter(predicate)
//            }
//            catch { print(error) }
//        }
//        items.formUnion(inserted)
//        
//        let deleted = modelContext.deletedModelsArray.compactMap { $0 as? T }
//        items.subtract(deleted)
//        
//        let sorted = Array(items).sorted(using: fetchDescriptor.sortBy)
//        if sorted != fetchedModels {
//            self.fetchedModels = sorted
//        }
//        
//        delegate?.controllerDidChangeContent(self)
//    }
    
//    @objc private func contextModelsChanged(_ notification: Notification) {
//        delegate?.controllerWillChangeContent(self)
//        
//        // Build a stable map keyed by persistentModelID to avoid pointer reuse issues
//        var itemMap = Dictionary(uniqueKeysWithValues: (fetchedModels ?? []).map { ($0.persistentModelID, $0) })
//        
//      
//        // 2. Process changed items (re-evaluate predicate match)
//        let changes = modelContext.changedModelsArray.compactMap { $0 as? T }
//        if !changes.isEmpty {
//            if let predicate = fetchDescriptor.predicate {
//                do {
//                    for item in changes {
//                        let id = item.persistentModelID
//                        let matches = try [item].filter(predicate).isEmpty == false
//                        if matches {
//                            itemMap[id] = item // Add or update with the fresh instance
//                        } else {
//                            itemMap.removeValue(forKey: id) // No longer matches filter
//                        }
//                    }
//                } catch {
//                    print(error)
//                }
//            } else {
//                // If no predicate, just update references in case they were re-faulted
//                for item in changes {
//                    itemMap[item.persistentModelID] = item
//                }
//            }
//        }
//        
//        // 3. Process inserted items
//        let inserted = modelContext.insertedModelsArray.compactMap { $0 as? T }
//        print("inserted \(inserted.count)")
//        if !inserted.isEmpty {
//            do {
//                let matchedInserted: [T]
//                if let predicate = fetchDescriptor.predicate {
//                    matchedInserted = try inserted.filter(predicate)
//                } else {
//                    matchedInserted = inserted
//                }
//                
//                for item in matchedInserted {
//                    itemMap[item.persistentModelID] = item
//                }
//            } catch {
//                print(error)
//            }
//        }
//        
//        // 1. Remove deleted items by their persistent model identifier
//        let deletedIDs = Set(modelContext.deletedModelsArray.compactMap { ($0 as? T)?.persistentModelID })
//        for id in deletedIDs {
//            itemMap.removeValue(forKey: id)
//        }
//        print("deleted \(deletedIDs.count)")
//        
//        // Sort and update if changes occurred
//        let sorted = Array(itemMap.values).sorted(using: fetchDescriptor.sortBy)
//        if sorted != fetchedModels {
//            self.fetchedModels = sorted
//        }
//        
//        delegate?.controllerDidChangeContent(self)
//    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        //fetchInfo?.reset()
    }
    
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
