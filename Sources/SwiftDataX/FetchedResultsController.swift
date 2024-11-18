import Foundation
import SwiftData

public protocol FetchedResultsControllerDelegate: AnyObject {
    func controllerWillChangeContent<T>(_ controller: FetchedResultsController<T>)
    func controllerDidChangeContent<T>(_ controller: FetchedResultsController<T>)
}

extension FetchedResultsControllerDelegate {
    func controllerWillChangeContent<T>(_ controller: FetchedResultsController<T>) {}
    func controllerDidChangeContent<T>(_ controller: FetchedResultsController<T>) {}
}

public class FetchedResultsController<T: PersistentModel> {

    public private(set) var modelContext: ModelContext
    public weak var delegate: FetchedResultsControllerDelegate?
    public private(set) var fetchDescriptor: FetchDescriptor<T>!
    public private(set) var fetchedObjects: [T]?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    @objc private func contextModelsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        // since AnyPersistentObject is private we need to use string comparison of the types
        let search = "AnyPersistentObject(boxed: \(String(reflecting: T.self)))" // e.g. AppName.Item
        for key in ["updated", "inserted", "deleted"] {
            if let set = userInfo[key] as? Set<AnyHashable> {
                if set.contains(where: { String(describing: $0) == search }) {
                    delegate?.controllerWillChangeContent(self)
                    fetchedObjects = try? modelContext.fetch(fetchDescriptor) // currently just refetch, todo optimise
                    delegate?.controllerDidChangeContent(self)
                    return
                }
            }
        }
    }
    
    public func performFetch(_ fetchDescriptor: FetchDescriptor<T>) throws {
        self.fetchDescriptor = fetchDescriptor
        NotificationCenter.default.removeObserver(self)
        fetchedObjects = try modelContext.fetch(fetchDescriptor)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextModelsChanged),
                                               name: ModelContext.didChangeX,
                                               object: modelContext)
        
    }
}
