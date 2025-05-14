import SwiftData
import SwiftUI

// Just for convenience instead of creating your own child custom View
public struct QueryView<Model, Content>: View where Model: PersistentModel, Content: View {
    @Query var models: [Model]
    
    public typealias QueryViewResult = Result<[Model], Error>
    let content: (QueryViewResult) -> Content
    
    public init(query: Query<Model, [Model]>, @ViewBuilder content: @escaping (QueryViewResult) -> Content) {
        self.content = content
        self._models = query
    }
    
    var result: QueryViewResult {
        if let error = _models.fetchError {
            return .failure(error)
        }
        else {
            return .success(models)
        }
    }
    
    public var body: some View {
        content(result)
    }
}
