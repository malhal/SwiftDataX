@preconcurrency import SwiftData
@preconcurrency import SwiftUI

// Just so it can be used as @StateObject.
extension FetchedResultsController: ObservableObject { }

@MainActor @propertyWrapper @preconcurrency public struct DynamicQuery<ResultType>: @preconcurrency DynamicProperty where ResultType: PersistentModel {
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var fetchedResultsController = FetchedResultsController<ResultType>()
    
    private let initialFetchDescriptor: FetchDescriptor<ResultType>
    private let initialTransaction: Transaction
    
    public init(initialFetchDescriptor: FetchDescriptor<ResultType> = .init(), initialTransaction: Transaction = Transaction(animation: .default)) {
        self.initialFetchDescriptor = initialFetchDescriptor
        self.initialTransaction = initialTransaction
    }
    
    public var fetchDescriptor: FetchDescriptor<ResultType> {
        get {
            fetchedResultsController.fetchDescriptor
        }
        nonmutating set {
            fetchedResultsController.fetchDescriptor = newValue
        }
    }
    
    public var transaction: Transaction {
        get {
            fetchedResultsController.transaction
        }
        nonmutating set {
            fetchedResultsController.transaction = newValue
        }
    }
    
    public var wrappedValue: Result<[ResultType], Error> {
        do {
            return try .success(fetchedResultsController.results)
        } catch {
            return .failure(error)
        }
    }
    
    public func update() {
        if fetchedResultsController.fetchDescriptor == nil {
            fetchedResultsController.fetchDescriptor = initialFetchDescriptor
        }
        if fetchedResultsController.transaction == nil {
            fetchedResultsController.transaction = initialTransaction
        }
        if fetchedResultsController.modelContext != modelContext {
            fetchedResultsController.modelContext = modelContext
        }
    }
}
