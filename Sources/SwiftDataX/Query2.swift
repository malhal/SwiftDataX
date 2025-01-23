@preconcurrency import SwiftData
@preconcurrency import SwiftUI

@MainActor @propertyWrapper public struct Query2<ResultType>: DynamicProperty where ResultType: PersistentModel {
    
    @Environment(\.modelContext) private var modelContext
    @StateObject var controller = Query2Controller()
    //let initialFetchDescriptor: FetchDescriptor<ResultType>
    let filter: Predicate<ResultType>?
    let sort: [SortDescriptor<ResultType>]
//    public init(initialFetchDescriptor: FetchDescriptor<ResultType> = .init()) {
//        self.initialFetchDescriptor = initialFetchDescriptor
//    }
    public init(filter: Predicate<ResultType>? = nil, sort: [SortDescriptor<ResultType>]) {
        self.filter = filter
        self.sort = sort
    }
       
    public var wrappedValue: Result<[ResultType], Error> {
        controller.result(context: modelContext, filter: filter, sort: sort)
    }
    
    
    @Observable
    @MainActor class Query2Controller: ObservableObject, @preconcurrency FetchedModelsControllerDelegate {
        
        @ObservationIgnored
        var fetchedModelsController: FetchedModelsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fetchedModelsController?.delegate = self
            }
        }

        func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
            cachedResult = Result.success(controller.fetchedModels as! [ResultType])
        }
        
        var cachedResult: Result<[ResultType], Error>?
        func result(context: ModelContext, filter: Predicate<ResultType>?, sort: [SortDescriptor<ResultType>]) -> Result<[ResultType], Error> {
            
            var fetchDescriptor = fetchedModelsController?.fetchDescriptor ?? FetchDescriptor<ResultType>()
            
            // predicate is not Equatable so need to use its description which hopefully has everything in it.
            if fetchedModelsController?.fetchDescriptor.predicate?.description != filter?.description {
                fetchDescriptor.predicate = filter
                cachedResult = nil
            }
            
            if fetchedModelsController?.fetchDescriptor.sortBy != sort {
                fetchDescriptor.sortBy = sort
                cachedResult = nil
            }
            
            
            let frc: FetchedModelsController<ResultType>
            if let fetchedModelsController {
                if context == fetchedModelsController.modelContext, let cachedResult {
                    return cachedResult
                }
                frc = fetchedModelsController
            }
            else {
                frc =  FetchedModelsController<ResultType>(modelContext: context, fetchDescriptor: fetchDescriptor)
                fetchedModelsController = frc
                cachedResult = nil
            }
            
            let result: Result<[ResultType], Error>
            do {
                try frc.performFetch()
                result = Result.success(frc.fetchedModels ?? [])
            }
            catch {
                result = Result.failure(error)
            }
            cachedResult = result
            let _ = cachedResult // need to call the getter for the Observable depdendency to be configured and for body to be called after controllerDidChangeContent
            return result
        }
    }
}
