import SwiftData
import SwiftUI

@MainActor @propertyWrapper public struct Query2<ResultType>: DynamicProperty where ResultType: PersistentModel {
    
    @Environment(\.modelContext) private var modelContext
    @StateObject var controller = QueryController(for: ResultType.self)
    
    let filter: Predicate<ResultType>?
    let sort: [SortDescriptor<ResultType>]
    let animation: Animation?

    public init(filter: Predicate<ResultType>? = nil, sort: [SortDescriptor<ResultType>], animation: Animation? = nil) {
        self.filter = filter
        self.sort = sort
        self.animation = animation
    }
    
    public init<Value>(filter: Predicate<ResultType>? = nil, sort keyPath: KeyPath<ResultType, Value> & Sendable, order: SortOrder = .forward, animation: Animation? = nil) where Value : Comparable {
        self.init(filter: filter, sort:  [SortDescriptor<ResultType>(keyPath, order: order)], animation: animation)
    }
       
    public var wrappedValue: Result<[ResultType], Error> {
        controller.result(context: modelContext, filter: filter, sort: sort, animation: animation)
    }
}
