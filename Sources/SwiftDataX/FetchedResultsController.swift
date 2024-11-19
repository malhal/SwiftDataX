import Foundation
import SwiftData

public class FetchedResultsController<T: PersistentModel> {

    public private(set) var modelContext: ModelContext
    public private(set) var fetchDescriptor: FetchDescriptor<T>!
    public private(set) var fetchedObjects: [T]?
    
    var willChangeContent: (() -> Void)?
    var didChangeContent: (() -> Void)?
    
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
                    willChangeContent?()
                    fetchedObjects = try? modelContext.fetch(fetchDescriptor) // currently just refetch, todo optimise
                    didChangeContent?()
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
