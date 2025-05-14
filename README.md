# SwiftDataX

SwiftDataX brings extended features to SwiftData like `FetchedModelsController` which is like `NSFetchedResultsController` and a `QueryController` that enables dynamic predicate and sort descriptors. It also has `@Query2` an open source implementation of `@Query` which might give you an idea of how it might be implemented. Although you should usually make your own child `QueryView` where you compute a query and pass in as a param, a `QueryView` convenience wrapper is provided to use `@Query` with for dynamic queries. `@Query2` differs from `@Query` that it uses Swift's built-in `Result` type which is an enum containing either the results or the error which I prefer compared with `@Query`'s implementation of a distinct `var fetchError`. The `animation` defaults to `.default` instead of `.none` so animations occur when ever the results change due to an insert, delete or update.

* `QueryView`: a convenience wrapper for `@Query` for enabling dynamic queries but you might be better off just making your own custom child `View`.
* `@Query2`: open source version of `@Query` powered by an internal `QueryController`.
* `@Query2` and `QueryController` use a Swift `Result` type to represent either valid results or an error as one value.
* `FetchedModelsController`: a fetch controller for SwiftData similar to Core Data's `NSFetchedResultsController`.

Note: It currently uses a private notification for model context changes which could be a problem for app review but probably not since it is just a string and not a private method.

Here is an example of how `QueryController` can be used to fetch detail items with dynamic sort, updating the predicate whenever the parent item changes:

```
import SwiftUI
import SwiftDataX

struct DetailView: View {
    
    let item: Item // body called when this item changes
    
    struct QueryView: View {
        let query: Query2<SubItem>
        var result: Result<[SubItem], Error> {
             query.wrappedValue
        }
        @Environment(\.modelContext) private var modelContext
        
        var body: some View {
            switch(query.result) {
                case .success(let subItems):
                    List {
                        ForEach(subItems) { subItem in
                            Text(subItem.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                        .onDelete { offsets in
                            deleteItems(offsets: offsets, subItems: subItems)
                        }
                    }
                    .animation(.default, value: subItems)
                case .failure(let error):
                    Text(error.localizedDescription)
            }
        }
        
        private func deleteItems(offsets: IndexSet, subItems: [SubItem]) {
            ...
        }
    }

    var filter: Predicate<SubItem> {
        let id = item.persistentModelID
        return #Predicate<SubItem> { subItem in
            subItem.item?.persistentModelID == id
        }
    }
    
    @State private var ascending = false
    
    var sort: [SortDescriptor<SubItem>] {
        [SortDescriptor(\SubItem.timestamp, order: ascending ? .forward : .reverse)]
    }

    var body: some View {
        QueryView(query: Query2(filter: filter, sort: sort))
        .toolbar {
            ToolbarItem {
                Button(ascending ? "Desc" : "Asc") {
                    withAnimation {
                        ascending.toggle()
                    }
                }
            }
        }
    }
    
    ...
}
```
