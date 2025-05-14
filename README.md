# SwiftDataX

SwiftDataX brings extended features to SwiftData like `FetchedModelsController` which is like `NSFetchedResultsController` and a `QueryController` that enables dynamic predicate and sort descriptors. It also has `@Query2` an open source implementation of `@Query` which might give you an idea of how it might be implemented. Since the Query's built-in controller is not public, a `QueryView` wrapper is provided to use `@Query` with for dynamic queries. `QueryController` and `@Query2` use Swift's built-in `Result` which is an enum containing either the results or the error which I prefer compared with `@Query`'s implementation of a distinct error var. Animation and transaction params have been removed and the `.animation` modifier is preferred, since other property wrappers like `@AppStorage` don't have these either.

* `QueryView`: a wrapper for `@Query` that's a workaround for enabling dynamic queries.
* `QueryController`: a `@StateObject` for dynamic SwiftData queries in a more sensible way.
* `@Query2`: open source version of `@Query` powered by `QueryController`.
* `QueryController` `@Query2` use a Swift `Result` type to represent either valid results or an error as one value.
* `FetchedModelsController`: a fetch controller for SwiftData similar to Core Data's `NSFetchedResultsController`.

Note: It currently uses a private notification for model context changes which could be a problem for app review but probably not since it is just a string and not a private method.

Here is an example of how `QueryController` can be used to fetch detail items, updating the predicate whenever the parent item changes:

```
import SwiftUI
import SwiftDataX

struct DetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let item: Item // body called when this item changes

    var filter: Predicate<SubItem> {
        let id = item.persistentModelID
        return #Predicate<SubItem> { subItem in
            subItem.item?.persistentModelID == id
        }
    }
    
    @StateObject var queryController = QueryController(for: SubItem.self)
    
    var result: Result<[SubItem], Error> {
        // body is called if a change is detected in the context that affects these results
        Result { queryController.result(context: modelContext, filter: filter, sort: [SortDescriptor(\.timestamp, order: .reverse)]) }
    }

    var body: some View {
        ZStack { // just to allow the switch result to have a toolbar
            switch(result) {
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
