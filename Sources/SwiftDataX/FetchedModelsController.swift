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
            if let oldValue {
                NotificationCenter.default.removeObserver(self)
            }
            if let delegate {
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(contextModelsChanged),
                                                       name: ModelContext.didChangeX,
                                                       object: modelContext)
                
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(contextDidSave),
                                                       name: ModelContext.didSave,
                                                       object: modelContext)
            }
        }
    }
    
    public var fetchedModels: [T] {
        fetchInfo?.models ?? []
    }
    
    struct FetchInfo {
        var fetchDescriptor: FetchDescriptor<T>
        var persistedModels: [T]
        var models: [T] = []
        
        init(modelContext: ModelContext, fetchDescriptor: FetchDescriptor<T>) throws {
            persistedModels = try modelContext.fetch(fetchDescriptor)
            self.fetchDescriptor = fetchDescriptor
            applyChanges(from: modelContext)
        }
        
        mutating func reset() {
            persistedModels = models
        }
        
        mutating func applyChanges(from modelContext: ModelContext) {
            var items = Set(persistedModels)
            
            let deleted = modelContext.deletedModelsArray.compactMap { $0 as? T }
            items.subtract(deleted)
            
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
            
            let sorted = Array(items).sorted(using: fetchDescriptor.sortBy)
            if sorted != models {
                self.models = sorted
            }
        }
    }
    
    private var fetchInfo: FetchInfo? = nil
    
    public var predicate: Predicate<T>?
    public var sortBy: [SortDescriptor<T>]
    public var nonSortingPropertiesToFetch: [PartialKeyPath<T>]
    
    init(modelContext: ModelContext, predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>], nonSortingPropertiesToFetch: [PartialKeyPath<T>] = []) {
        self.modelContext = modelContext
        self.predicate = predicate
        self.sortBy = sortBy
        self.nonSortingPropertiesToFetch = nonSortingPropertiesToFetch
    }
    
    @objc private func contextModelsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        delegate?.controllerWillChangeContent(self)
        fetchInfo?.applyChanges(from: modelContext)
        delegate?.controllerDidChangeContent(self)
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        fetchInfo?.reset()
    }
    
    public func performFetch() throws {
        var fd = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        fd.includePendingChanges = false
        
        // if not fetching all properties then add in at least the sort properties
        if !nonSortingPropertiesToFetch.isEmpty {
            let sortByKeyPaths = sortBy.compactMap(\.keyPath)
            let properties = Set(nonSortingPropertiesToFetch).union(sortByKeyPaths)
            fd.propertiesToFetch = Array(properties)
        }
        self.fetchInfo = try FetchInfo(modelContext: modelContext, fetchDescriptor: fd)
    }
    
    deinit {
        print("deinit")
        NotificationCenter.default.removeObserver(self)
    }
}
