@preconcurrency import SwiftData
@preconcurrency import SwiftUI

@MainActor @propertyWrapper @preconcurrency public struct DynamicQuery<ResultType>: @preconcurrency DynamicProperty where ResultType: PersistentModel {
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var coordinator = Coordinator()
    
    private let initialFetchDescriptor: FetchDescriptor<ResultType>
    
    public init(initialFetchDescriptor: FetchDescriptor<ResultType> = .init()) {
        self.initialFetchDescriptor = initialFetchDescriptor
    }
    
    public var fetchDescriptor: FetchDescriptor<ResultType> {
        get {
            coordinator.fetchDescriptor ?? initialFetchDescriptor
        }
        nonmutating set {
            coordinator.fetchDescriptor = newValue
            coordinator.result = nil
        }
    }
       
    public var wrappedValue: Result<[ResultType], Error> {
        coordinator.result
    }
    
    public func update() {
        if coordinator.fetchDescriptor == nil {
            coordinator.fetchDescriptor = initialFetchDescriptor
        }
        if coordinator.fetchedResultsController?.modelContext != modelContext {
            coordinator.fetchedResultsController = FetchedResultsController<ResultType>(modelContext: modelContext)
        }
    }
    
    class Coordinator: ObservableObject {
       
        var fetchDescriptor: FetchDescriptor<ResultType>!
        
        var fetchedResultsController: FetchedResultsController<ResultType>? {
            didSet {
                oldValue?.didChangeContent = nil
                _result = nil
                fetchedResultsController?.willChangeContent = { [weak self] in
                    self?.result = nil
                }
            }
        }
        
        private var _result: Result<[ResultType], Error>?
        var result: Result<[ResultType], Error>! {
            get {
                if _result == nil {
                    do {
                        try fetchedResultsController?.performFetch(fetchDescriptor)
                        _result = Result.success(fetchedResultsController?.fetchedObjects ?? [])
                    }
                    catch {
                        _result = Result.failure(error)
                    }
                }
                return _result!
            }
            set {
                objectWillChange.send()
                _result = newValue
            }
        }
    }
}
