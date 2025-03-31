import SwiftData
import SwiftUI

@MainActor @propertyWrapper public struct Query2<ResultType>: DynamicProperty where ResultType: PersistentModel {
    
    @Environment(\.modelContext) private var modelContext
    @StateObject var controller = QueryController(for: ResultType.self)
    
    let filter: Predicate<ResultType>?
    let sort: [SortDescriptor<ResultType>]

    public init(filter: Predicate<ResultType>? = nil, sort: [SortDescriptor<ResultType>]) {
        self.filter = filter
        self.sort = sort
    }
       
    public var wrappedValue: Result<[ResultType], Error> {
        controller.result(context: modelContext, filter: filter, sort: sort)
    }
}
