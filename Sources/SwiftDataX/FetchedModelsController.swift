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

public class FetchedModelsController<T: PersistentModel> {

    public var modelContext: ModelContext
    public weak var delegate: FetchedModelsControllerDelegate?
    public var fetchDescriptor: FetchDescriptor<T>!
    public private(set) var fetchedModels: [T]?
    private var remoteChangeObserver: NSObjectProtocol?
    
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
                    changed()
                    return
                }
            }
        }
    }
    
    @objc private func remoteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        if let storeURL = userInfo[NSPersistentStoreURLKey] as? URL {
            if modelContext.container.configurations.contains(where: { $0.url == storeURL }) {
                changed()
            }
        }
    }
    
    func changed() {
        delegate?.controllerWillChangeContent(self)
        fetchedModels = try? modelContext.fetch(fetchDescriptor) // todo optimise, currently just refetch
        delegate?.controllerDidChangeContent(self)
    }
    
    public func performFetch() throws {
        NotificationCenter.default.removeObserver(self)
        if let observer = remoteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        fetchedModels = try modelContext.fetch(fetchDescriptor)
        if delegate == nil { return }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextModelsChanged),
                                               name: ModelContext.didChangeX,
                                               object: modelContext)
        
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.remoteChange(notification)
        }
    }
    
    deinit {
        //print("deinit")
        NotificationCenter.default.removeObserver(self)
        if let observer = remoteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
