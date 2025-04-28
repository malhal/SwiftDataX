import SwiftData
import SwiftUI

@Observable
@MainActor
public class QueryController<ResultType: PersistentModel>: ObservableObject, @preconcurrency FetchedModelsControllerDelegate {
    
    @ObservationIgnored
    var animation: Animation?
    
    @ObservationIgnored
    private var fetchedModelsController: FetchedModelsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetchedModelsController?.delegate = self
        }
    }
    
    public init(for: ResultType.Type) { }
    
    public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
        withAnimation(animation) {
            cachedResult = Result.success(controller.fetchedModels as! [ResultType])
        }
    }
    
    var cachedResult: Result<[ResultType], Error>?
    public func result(context: ModelContext, filter: Predicate<ResultType>? = nil, sort: [SortDescriptor<ResultType>], animation: Animation? = nil) -> Result<[ResultType], Error> {
        
        self.animation = animation
        
        let frc: FetchedModelsController<ResultType>
        if let fetchedModelsController {
            frc = fetchedModelsController
            
            // predicate is not Equatable so need to use its description which hopefully has everything in it.
            if frc.fetchDescriptor.predicate?.description != filter?.description {
                frc.fetchDescriptor.predicate = filter
                cachedResult = nil
            }
            
            if frc.fetchDescriptor.sortBy != sort {
                frc.fetchDescriptor.sortBy = sort
                cachedResult = nil
            }
            
            if frc.modelContext != context {
                frc.modelContext = context
                cachedResult = nil
            }
            
            if let cachedResult {
                return cachedResult
            }
        }
        else {
            frc = FetchedModelsController<ResultType>(modelContext: context, fetchDescriptor: FetchDescriptor<ResultType>(predicate: filter, sortBy: sort))
            fetchedModelsController = frc
        }
        
        do {
            try frc.performFetch()
            cachedResult = Result.success(frc.fetchedModels ?? [])
        }
        catch {
            cachedResult = Result.failure(error)
        }
        return cachedResult!
    }
}
