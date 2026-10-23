import SwiftData
import SwiftUI

//public struct QueryView<Model, Content>: View where Model: PersistentModel, Content: View {
//    @Query var models: [Model]
//    
//    let content: (Context) -> Content
//    
//    public init(query: Query<Model, [Model]>, @ViewBuilder content: @escaping (Context) -> Content) {
//        self.content = content
//        self._models = query
//    }
//    
//    public var body: some View {
//        content(Context(results: models, error: _models.fetchError, modelContext: _models.modelContext))
//    }
//    
//    public struct Context {
//        let results: [Model]
//        let error: Error?
//        let modelContext: ModelContext
//    }
//}
