@preconcurrency import SwiftData
@preconcurrency import SwiftUI

@MainActor @propertyWrapper @preconcurrency public struct DynamicQuery<ResultType>: @preconcurrency DynamicProperty where ResultType: PersistentModel {
    
    @Environment(\.modelContext) private var modelContext
    @StateObject var coordinator = Coordinator()
    let initialFetchDescriptor: FetchDescriptor<ResultType>
    
    public init(initialFetchDescriptor: FetchDescriptor<ResultType> = .init()) {
        self.initialFetchDescriptor = initialFetchDescriptor
    }
    
    public var fetchDescriptor: FetchDescriptor<ResultType> {
        get {
            coordinator.fetchDescriptor
        }
        nonmutating set {
            coordinator.fetchDescriptor = newValue
        }
    }
       
    public var wrappedValue: Result<[ResultType], Error> {
        coordinator.result
    }
    
    public func update() {
        if coordinator.fetchDescriptor == nil {
            coordinator.fetchDescriptor = initialFetchDescriptor
        }
        if coordinator.modelContext != modelContext {
            coordinator.modelContext = modelContext
        }
    }
    
    @Observable
    @MainActor class Coordinator: ObservableObject, @preconcurrency FetchedResultsControllerDelegate {
        
        @ObservationIgnored
        var modelContext: ModelContext! {
            didSet {
                _fetchedResultsController = nil
            }
        }
        
        @ObservationIgnored
        var fetchDescriptor: FetchDescriptor<ResultType>! {
            didSet {
                _fetchedResultsController = nil
            }
        }
        
        @ObservationIgnored
        var _fetchedResultsController: FetchedResultsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                _fetchedResultsController?.delegate = self
                _result = nil
            }
        }
        var fetchedResultsController: FetchedResultsController<ResultType>! {
            get {
                if _fetchedResultsController == nil {
                    _fetchedResultsController = FetchedResultsController<ResultType>(modelContext: modelContext, fetchDescriptor: fetchDescriptor)
                }
                return _fetchedResultsController!
            }
        }
        
        func controllerDidChangeContent<T>(_ controller: FetchedResultsController<T>) where T : PersistentModel {
            _result = Result.success(controller.fetchedObjects as! [ResultType])
        }
        
        var _result: Result<[ResultType], Error>?
        var result: Result<[ResultType], Error> {
            get {
                if _result == nil {
                    do {
                        let frc = fetchedResultsController!
                        try frc.performFetch()
                        _result = Result.success(frc.fetchedObjects ?? [])
                    }
                    catch {
                        _result = Result.failure(error)
                    }
                }
                return _result!
            }
        }
    }
}
