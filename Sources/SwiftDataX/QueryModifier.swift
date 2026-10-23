import SwiftData
import SwiftUI


public protocol FetchDescriptorRepresentable<ResultType>: Equatable, Sendable {
    associatedtype ResultType: PersistentModel
    func makeFetchDescriptor() -> FetchDescriptor<ResultType> 
    
    //func configure(observer: ResultsObserver<ResultType, Never>)
}


//public struct ModernSortedFetch<ResultType: NSManagedObject>: FetchDescriptorConfiguring {
//
//    public var sortDescriptors: [SortDescriptor<ResultType>]
//    
//    public init(sortDescriptors: [SortDescriptor<ResultType>] = []) {
//        self.sortDescriptors = sortDescriptors
//    }
//    
//    public func configure(request: NSFetchRequest<ResultType>) {
//        request.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
//    }
//}

//public extension ModernSortedFetch {
//    /// Creates a fetch configuration with the specified Swift `SortDescriptor`s.
//    static func sortDescriptors(_ descriptors: [SortDescriptor<ResultType>]) -> ModernSortedFetch {
//        ModernSortedFetch(sortDescriptors: descriptors)
//    }
//    
//    /// Convenience helper for a single sort descriptor.
//    static func sorted(by keyPath: KeyPath<ResultType, some Comparable>, order: SortOrder = .forward) -> ModernSortedFetch {
//        ModernSortedFetch(sortDescriptors: [SortDescriptor(keyPath, order: order)])
//    }
//}

@MainActor
public struct QueryModifier<F>: ViewModifier where F: FetchDescriptorRepresentable {
    
    private let representable: F
    private let handleResults: ([F.ResultType]) -> Void
    private let onError: (Error) -> Void
    
    @State private var observer = QueryObserver<F>()
    
    @Environment(\.modelContext) private var context
    
    public init(
        representable: F,
        handleResults: @escaping ([F.ResultType]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.representable = representable
        self.handleResults = handleResults
        self.onError = onError
    }
    
    private struct Trigger: Equatable {
        let context: ModelContext
        let representable: F
    }
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: observer.version) {
                handleResults(observer.fetcher?.fetchedModels ?? [])
            }
            .onChange(of: Trigger(context: context, representable: representable), initial: true) { old, new in
                do {
                    let fd = representable.makeFetchDescriptor()
                    //fd.includePendingChanges = true
                    let fetcher = FetchedModelsController(fetchDescriptor: fd, modelContext: context)
                    try fetcher.performFetch()
                    observer.fetcher = fetcher
                    handleResults(fetcher.fetchedModels ?? [])
                }catch {
                    onError(error)
                }
            }
    }
}

// extension allows skipping the return in body
//extension FetchedResultsView: View where Content: View {
//
//}

@MainActor
@Observable
class QueryObserver<F: FetchDescriptorRepresentable>: NSObject, @preconcurrency FetchedModelsControllerDelegate {
    
    private(set) var version = 0
    
    @ObservationIgnored
    var fetcher: FetchedModelsController<F.ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetcher?.delegate = self
        }
    }
    
//    @ObservationIgnored
//    private var hasStructuralChanges = false
    
    override init() {
        super.init()
        print("QueryObserver init")
    }
    
    public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
        //guard hasStructuralChanges else { return }
        //hasStructuralChanges = false
        
        // Bump revision to force SwiftUI to re-evaluate body when background deletes/inserts happen
        version += 1
    }
    
    deinit {
        print("QueryObserver deinit")
    }
}

public extension View {
    func query<F: FetchDescriptorRepresentable>(
        _ representable: F,
        handleResults: @escaping ([F.ResultType]) -> Void,
        onError: @escaping (Error) -> Void,
    ) -> some View {
        modifier(QueryModifier(representable: representable, handleResults: handleResults, onError: onError))
    }
}


// Unforuntaly the new ResultsObserver only notifies on saves not on context changes.
//@MainActor
//@Observable
//class FetchObserver2<F: FetchDescriptorConfiguring> {
//    var error: Error?
//    var results: [F.ResultType] = []
//    
//    @ObservationIgnored
//    public var lastFetch: F?
//    
//    @ObservationIgnored
//    var observer: ResultsObserver<F.ResultType, Never>?
//    
//    @ObservationIgnored
//    private var observationToken: ObservationTracking.Token?
//    
//    public func update(modelContext: ModelContext, fetch: F) {
//        let active: ResultsObserver<F.ResultType, Never>
//        
//        if let existing = observer,
//           existing.modelContext == modelContext {
//            if fetch == lastFetch {
//                return
//            }
//            active = existing
//        } else {
//            //let fr = NSFetchRequest<F.ResultType>(entityName: F.ResultType.entity().name ?? "\(F.ResultType.self)")
//            //fr.sortDescriptors = []
//            var fd = FetchDescriptor<F.ResultType>()
//            //fd.includePendingChanges = true
//            
//            do {
//                active = try ResultsObserver(fetchDescriptor: fd, modelContext: modelContext)
//                observer = active
//            }
//            catch {
//                _error = error
//                return
//            }
//        }
//        
//        lastFetch = fetch
//        //fetch.configure(fetchDescriptor: active)
//        //
//        //        do {
//        //            try active.
//        //            _error = nil
//        //        } catch {
//        //            _error = error
//        //        }
//        
//        observationToken = withContinuousObservation(options: [.didSet]) { [weak self] _ in
//            guard let self else {
//                return
//            }
//            _results = Array(active.results)
//        }
//        
//    }
//}
