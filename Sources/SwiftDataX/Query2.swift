import SwiftData
import SwiftUI

public protocol FetchDescriptorRepresentable<ResultType>: Equatable, Sendable {
    associatedtype ResultType: PersistentModel
    func makeFetchDescriptor() -> FetchDescriptor<ResultType>
}

public struct ModernSortedFetch<Result: PersistentModel>: FetchDescriptorRepresentable {
    
    public var sortDescriptors: [SortDescriptor<Result>]
    
    public init(sortDescriptors: [SortDescriptor<Result>] = []) {
        self.sortDescriptors = sortDescriptors
    }
    
    public func makeFetchDescriptor() -> FetchDescriptor<Result> {
        FetchDescriptor<ResultType>(sortBy: sortDescriptors)
    }
}

extension ModernSortedFetch {
    public static func sorted(by descriptors: [SortDescriptor<ResultType>]) -> ModernSortedFetch<ResultType> {
        ModernSortedFetch(sortDescriptors: descriptors)
    }
}

@MainActor @propertyWrapper public struct Query2View<Representable, Content: View>: View where Representable: FetchDescriptorRepresentable {
    
    @State private var evaluator = QueryEvaluator<Representable>()
    
    @Environment(\.modelContext) private var context
    
    private let representable: Representable
    private let content: ([Representable.ResultType], Error?) -> Content
    
    public init(
        _ representable: Representable,
        @ViewBuilder content: @escaping ([Representable.ResultType], Error?) -> Content
    ) {
        self.representable = representable
        self.content = content
    }
    
    struct Config: Equatable {
        let context: ModelContext
        let representable: Representable
    }
    
    public private(set) var wrappedValue: [Representable.ResultType] = []
    public private(set) var lastError: Error? = nil
    
    public var body: some View {
        // Evaluates synchronously on every render pass; memoized via callAsFunction
        let output = evaluator(.init(context: context, representable: representable))
        content(output.results, output.error)
    }
}

@MainActor @propertyWrapper public struct Query2<Representable>: @preconcurrency DynamicProperty where Representable: FetchDescriptorRepresentable {
    
    @State private var evaluator = QueryEvaluator<Representable>()
    
    @Environment(\.modelContext) private var context
    
    private let representable: Representable
    private var output = QueryEvaluator<Representable>.Output(results: [], error: nil)
    
    public init(_ representable: Representable) {
        self.representable = representable
    }
    
    struct Config: Equatable {
        let context: ModelContext
        let representable: Representable
    }
    
    public var wrappedValue: [Representable.ResultType] {
        output.results
    }
    
    public var lastError: Error? {
        output.error
    }
    
    public mutating func update() {
        output = evaluator(.init(context: context, representable: representable))
    }
    
   

}

@MainActor
@Observable
class QueryEvaluator<Representable: FetchDescriptorRepresentable>: NSObject, @preconcurrency FetchedModelsControllerDelegate {
    
    
    public struct Input: Equatable {
        public let context: ModelContext
        public let representable: Representable
        
        public init(context: ModelContext, representable: Representable) {
            self.context = context
            self.representable = representable
        }
    }
    
    public struct Output {
        public var results: [Representable.ResultType]
        public var error: Error?
    }
    
    
    @ObservationIgnored
    private var lastInput: Input?
    
    private var lastOutput = Output(results: [], error: nil)
    
    @ObservationIgnored
    private var fmc: FetchedModelsController<Representable.ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fmc?.delegate = self
        }
    }
    
    @discardableResult
    public func callAsFunction(_ input: Input) -> Output {
        if let lastInput, lastInput == input {
            return lastOutput
        }
        lastInput = input
        
        let fetch = input.representable.makeFetchDescriptor()
        do {
            let fmc = FetchedModelsController<Representable.ResultType>(fetchDescriptor: fetch, modelContext: input.context)
            try fmc.performFetch()
            self.fmc = fmc
            lastOutput = Output(results: fmc.fetchedModels ?? [], error: nil)
        } catch {
            lastOutput.error = error
        }
        return lastOutput
    }
    
    public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
        lastOutput = Output(results: controller.fetchedModels as? [Representable.ResultType] ?? [], error: nil)
    }
}
