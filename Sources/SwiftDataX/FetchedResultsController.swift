import Foundation
import SwiftData
import SwiftUI

@Observable
public class FetchedResultsController<T: PersistentModel> {

    public var fetchDescriptor: FetchDescriptor<T>! {
        didSet {
            // if fetchDescriptor == oldValue { return } // need to wait until they make it Equatable
            _results = nil
        }
    }
    
    public var modelContext: ModelContext! {
        didSet {
            // if modelContext == oldValue { return } // perhaps should be removed, to have same semantics as the current var fetchDescriptor
            _results = nil
            NotificationCenter.default.removeObserver(self)
            if let modelContext {
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(contextModelsChanged),
                                                       name: ModelContext.didChangeX,
                                                       object: modelContext)
            }
        }
    }
    
    
    @objc private func contextModelsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        // since AnyPersistentObject is private we need to use string comparison of the types
        let search = "AnyPersistentObject(boxed: \(String(reflecting: T.self)))" // e.g. AppName.Item
        for key in ["updated", "inserted", "deleted"] {
            if let set = userInfo[key] as? Set<AnyHashable> {
                if set.contains(where: { String(describing: $0) == search }) {
                    _results = nil
                    return
                }
            }
        }
    }
    
    private(set) var _results: [T]?
    public var results: [T] {
        get throws {
            if _results == nil {
                _results = try modelContext.fetch(fetchDescriptor)
            }
            return _results!
        }
    }
}
