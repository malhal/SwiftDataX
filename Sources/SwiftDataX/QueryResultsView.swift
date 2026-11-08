import SwiftData
import SwiftUI

public struct QueryResultsView<Model, Content>: View where Model: PersistentModel, Content: View {
    @Query private var models: [Model]
    private let content: ([Model], Context) -> Content
    
    public init(_ query: Query<Model, [Model]>, @ContentBuilder content: @escaping ([Model], Context) -> Content) {
        self._models = query
        self.content = content
    }
    
    public var body: some View {
        content(models, Context(fetchError: _models.fetchError, modelContext: _models.modelContext))
    }
    
    public struct Context {
        public let fetchError: (any Error)?
        public let modelContext: ModelContext
    }
}

