import SwiftData
import SwiftUI

public protocol PredicateRepresentable<Input>: Equatable {
    associatedtype Input
    func makePredicate() -> Predicate<Input>
}

// 1. Type-erased wrapper that conforms to BOTH protocols and Equatable
public struct AnyPredicateRepresentable<Input>: PredicateRepresentable {
    public typealias Input = Input
    
    private let base: any PredicateRepresentable<Input>
    
    public init<T: PredicateRepresentable<Input>>(_ base: T) {
        self.base = base
    }
    
    public func makePredicate() -> Predicate<Input> {
        base.makePredicate()
    }
    
    // Equatable conformance for SwiftUI's diffing engine (Zero closures used)
    public static func == (lhs: AnyPredicateRepresentable<Input>, rhs: AnyPredicateRepresentable<Input>) -> Bool {
        return areEqual(lhs.base, rhs.base)
    }
    
    private static func areEqual(_ lhs: any PredicateRepresentable<Input>, _ rhs: any PredicateRepresentable<Input>) -> Bool {
        func open<T: PredicateRepresentable<Input>>(_ lhsValue: T, _ rhsValue: any PredicateRepresentable<Input>) -> Bool {
            guard let rhsT = rhsValue as? T else { return false }
            return lhsValue == rhsT
        }
        return open(lhs, rhs)
    }
}

@MainActor @propertyWrapper public struct Query2<ResultType: PersistentModel>: @preconcurrency DynamicProperty {
    
    @State private var coordinator = Coordinator()
    
    @Environment(\.modelContext) private var modelContext
    
    private let fetchDescriptorWithoutPredicate: FetchDescriptor<ResultType>
    private var predicateRepresentable: AnyPredicateRepresentable<ResultType>?
    
    public init<V: PredicateRepresentable<ResultType>>(_ fetchDescriptor: FetchDescriptor<ResultType>, predicateRepresentable: V) {
        self.init(fetchDescriptor)
        self.predicateRepresentable = AnyPredicateRepresentable(predicateRepresentable)
    }
    
    public init(_ fetchDescriptor: FetchDescriptor<ResultType>) {
        precondition(
            fetchDescriptor.predicate == nil,
            "Do not set a predicate on the FetchDescriptor when using a PredicateRepresentable. Pass the predicate via the representable argument instead."
        )
        self.fetchDescriptorWithoutPredicate = fetchDescriptor
    }
    
    public var wrappedValue: [ResultType] {
        coordinator.config.models
    }
    
    public var projectedValue: Config {
        coordinator.config
    }
    
    public func update() {
        coordinator.update(from: self)
    }
    
    public struct Config {
        public internal(set) var models: [ResultType] = []
        public internal(set) var lastError: (any Error)?
    }
   

    @MainActor
    @Observable
    final class Coordinator: NSObject, @preconcurrency FetchedModelsControllerDelegate {
        
        private(set) var config = Config()
        
        @ObservationIgnored
        private var fmc: FetchedModelsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fmc?.delegate = self
            }
        }
        
        @ObservationIgnored
        private var fetchDescriptorWithoutPredicate: FetchDescriptor<ResultType>?
        
        @ObservationIgnored
        private var predicateRepresentable: AnyPredicateRepresentable<ResultType>?
        
        @ObservationIgnored
        private var modelContext: ModelContext?
        
        func update(from parent: Query2) {
            if (modelContext, fetchDescriptorWithoutPredicate, predicateRepresentable) == (parent.modelContext, parent.fetchDescriptorWithoutPredicate, parent.predicateRepresentable) {
                return
            }
            modelContext = parent.modelContext
            predicateRepresentable = parent.predicateRepresentable
            fetchDescriptorWithoutPredicate = parent.fetchDescriptorWithoutPredicate
            
            var fd = parent.fetchDescriptorWithoutPredicate
            fd.predicate = parent.predicateRepresentable?.makePredicate()
            
            do {
                let fmc = FetchedModelsController<ResultType>(fetchDescriptor: fd, modelContext: parent.modelContext)
                try fmc.performFetch()
                self.fmc = fmc
                _config.models = fmc.fetchedModels ?? []
                _config.lastError = nil
            } catch {
                _config.lastError = error
                // keep prev models
            }
        }
        
        public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
            config.models = controller.fetchedModels as? [ResultType] ?? []
        }
    }
}


