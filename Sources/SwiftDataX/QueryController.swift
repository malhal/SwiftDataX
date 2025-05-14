import SwiftData
import SwiftUI

@MainActor
public class QueryController<ResultType: PersistentModel>: ObservableObject, @preconcurrency FetchedModelsControllerDelegate {
    
    var animation: Animation?
    
    private var fetchedModelsController: FetchedModelsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetchedModelsController?.delegate = self
        }
    }
    
    public init(for result: ResultType.Type) { }
    
    public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
        cachedResult = controller.fetchedModels as? [ResultType] ?? []
        withAnimation(animation) {
            objectWillChange.send()
        }
    }
    
    var cachedResult: [ResultType]?
    public func result(context: ModelContext, filter: Predicate<ResultType>? = nil, sort: [SortDescriptor<ResultType>], animation: Animation? = .default) throws -> [ResultType] {
        
        self.animation = animation
        
        let frc: FetchedModelsController<ResultType>
        if let fetchedModelsController, fetchedModelsController.modelContext == context {
            frc = fetchedModelsController
            
            // predicate is not Equatable so need to use its description which hopefully has everything in it.
            if frc.predicate?.description != filter?.description {
                frc.predicate = filter
                cachedResult = nil
            }
            
            if frc.sortBy != sort {
                frc.sortBy = sort
                cachedResult = nil
            }
        }
        else {
            frc = FetchedModelsController<ResultType>(modelContext: context, predicate: filter, sortBy: sort)
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
