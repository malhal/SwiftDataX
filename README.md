# SwiftDataX

SwiftDataX brings extended features to SwiftData like `FetchedModelsController` which is like `NSFetchedResultsController` and a `QueryView` that simplifies dynamic predicate and sort descriptors. It also has `@Query2` an open source implementation of `@Query` which might give you an idea of what it might look like and a matching `Query2View` to use with for dynamic queries. `@Query2` uses Swift's built-in `Result` which is an enum containing either the results or the error which I prefer compared with `@Query`'s implementation of a serperate error var. Animation and transaction params have been removed and the .animation modifier is preferred, other property wrappers like @AppStorage don't have these params either.

* `QueryView` & `Query2View`: for easily displaying dynamic fetches.
* `@Query2`: open source version of `@Query` upgraded to use a Swift `Result` type to represent either valid results or an error as one value. 
* `FetchedModelsController`: an `@Observable` class implementation of a fetch controller for SwiftData similar to `NSFetchedResultsController`.

Note: It currently uses a private notification for model context changes which could be a problem for app review but probably not since it is just a string and not a private method.

Here is an example of how `@DynamicQuery` can be used to fetch detail items, updating the predicate whenever the parent item changes:

```
import SwiftUI
import SwiftDataX

struct DetailView: View {
    @Environment(\.modelContext) private var modelContext
    let item: Item

    var filter: Predicate<SubItem> {
        let id = item.persistentModelID
        return #Predicate<SubItem> { subItem in
            subItem.item?.persistentModelID == id
        }
    }
    
    var query: Query2<SubItem> {
        Query2(filter: filter, sort: [.init(\SubItem.timestamp, order: .reverse)])
    }

    var body: some View {
        Query2View(query: query) { result in
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
        .onChange(of: item, initial: true) {
            let id = item.persistentModelID
            let filter = #Predicate<SubItem> { subItem in
                subItem.item?.persistentModelID == id
            }
            _result.fetchDescriptor.predicate = filter
        }
    }
    
    ...
}
```
