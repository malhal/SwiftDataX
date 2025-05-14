import SwiftData
import SwiftUI

@MainActor @propertyWrapper public struct Query2<ResultType>: DynamicProperty where ResultType: PersistentModel {
    
    struct Configuration {
        let filter: Predicate<ResultType>?
        let sort: [SortDescriptor<ResultType>]
        let animation: Animation?
    }
    
    private let configuration: Configuration
    
    public init(filter: Predicate<ResultType>? = nil, sort: [SortDescriptor<ResultType>], animation: Animation? = .default) {
        configuration = Configuration(filter: filter, sort: sort, animation: animation)
    }
    
    public init<Value>(filter: Predicate<ResultType>? = nil, sort keyPath: KeyPath<ResultType, Value> & Sendable, order: SortOrder = .forward, animation: Animation? = nil) where Value : Comparable {
        self.init(filter: filter, sort:  [SortDescriptor<ResultType>(keyPath, order: order)], animation: animation)
    }
    
    @MainActor class QueryController: ObservableObject, @preconcurrency FetchedModelsControllerDelegate {
        
        private var animation: Animation?
        
        private var fetchedModelsController: FetchedModelsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fetchedModelsController?.delegate = self
            }
        }
        
        public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
            cachedResult = controller.fetchedModels as? [ResultType] ?? []
            withAnimation(animation) {
                objectWillChange.send()
            }
        }

        var cachedResult: [ResultType]?
        func result(context: ModelContext, configuration: Configuration) throws -> [ResultType] {
            
            self.animation = configuration.animation
            
            let frc: FetchedModelsController<ResultType>
            if let fetchedModelsController, fetchedModelsController.modelContext == context {
                frc = fetchedModelsController
                
                // predicate is not Equatable so need to use its description which hopefully has everything in it.
                if frc.predicate?.description != configuration.filter?.description {
                    frc.predicate = configuration.filter
                    cachedResult = nil
                }
                
                if frc.sortBy != configuration.sort {
                    frc.sortBy = configuration.sort
                    cachedResult = nil
                }
            }
            else {
                frc = FetchedModelsController<ResultType>(modelContext: context, predicate: configuration.filter, sortBy: configuration.sort)
                fetchedModelsController = frc
                cachedResult = nil
            }
            
            if let cachedResult {
                return cachedResult
            }
            
            try frc.performFetch()
            let result = frc.fetchedModels ?? []
            cachedResult = result
            return result
        }
    }
    
    @StateObject var controller = QueryController()
    
    @Environment(\.modelContext) private var modelContext
    
    public var wrappedValue: Result<[ResultType], Error> {
        Result { try controller.result(context: modelContext, configuration: configuration) }
    }
}
