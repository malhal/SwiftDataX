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
                                                       name: ModelContext.willProcessPendingChangesX,
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
        // guard let userInfo = notification.userInfo else { return }
        delegate?.controllerWillChangeContent(self)
        
        var items = Set(fetchedModels ?? [])
        
        let changes = modelContext.changedModelsArray.compactMap { $0 as? T }
        if !changes.isEmpty {
            if let predicate = fetchDescriptor.predicate {
                do {
                    items.subtract(changes)
                    let changedMatches = try changes.filter(predicate)
                    items.formUnion(changedMatches)
                }
                catch { print(error) }
            }
        }
        
        var inserted = modelContext.insertedModelsArray.compactMap { $0 as? T }
        if let predicate = fetchDescriptor.predicate {
            do {
                inserted = try inserted.filter(predicate)
            }
            catch { print(error) }
        }
        items.formUnion(inserted)
        
        let deleted = modelContext.deletedModelsArray.compactMap { $0 as? T }
        items.subtract(deleted)
        
        let sorted = Array(items).sorted(using: fetchDescriptor.sortBy)
        if sorted != fetchedModels {
            self.fetchedModels = sorted
        }
        
        delegate?.controllerDidChangeContent(self)
    }
    
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
