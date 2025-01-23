import Foundation
import SwiftData

public protocol FetchedModelsControllerDelegate: AnyObject {
    func controllerWillChangeContent<T>(_ controller: FetchedModelsController<T>)
    func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>)
}

extension FetchedModelsControllerDelegate {
    func controllerWillChangeContent<T>(_ controller: FetchedModelsController<T>) {}
    func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) {}
}

public class FetchedModelsController<T: PersistentModel> {

    public let modelContext: ModelContext
    public weak var delegate: FetchedModelsControllerDelegate?
    public let fetchDescriptor: FetchDescriptor<T>!
    public private(set) var fetchedModels: [T]?
    
    init(modelContext: ModelContext, fetchDescriptor: FetchDescriptor<T>) {
        self.modelContext = modelContext
        self.fetchDescriptor = fetchDescriptor
    }
    
    @objc private func contextModelsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        // since AnyPersistentObject is private we need to use string comparison of the types
        let search = "AnyPersistentObject(boxed: \(String(reflecting: T.self)))" // e.g. AppName.Item
        for key in ["updated", "inserted", "deleted"] {
            if let set = userInfo[key] as? Set<AnyHashable> {
                if set.contains(where: { String(describing: $0) == search }) {
                    delegate?.controllerWillChangeContent(self)
                    fetchedModels = try? modelContext.fetch(fetchDescriptor) // todo optimise, currently just refetch
                    delegate?.controllerDidChangeContent(self)
                    return
                }
            }
        }
    }
    
    public func performFetch() throws {
        NotificationCenter.default.removeObserver(self)
        fetchedModels = try modelContext.fetch(fetchDescriptor)
        if delegate == nil { return }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextModelsChanged),
                                               name: ModelContext.didChangeX,
                                               object: modelContext)
        
    }
    
    deinit {
        //print("deinit")
        NotificationCenter.default.removeObserver(self)
    }
}
