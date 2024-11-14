# SwiftDataX

SwiftDataX brings extended features to SwiftData like an `NSFetchedResultsController` and `@Query` with dynamic predicate and sort descriptors.

`@DynamicQuery`: like `@Query` but offers dynamic configuration of the fetch descriptor, i.e. the predicate and sort.
`FetchedResultsController`: an Observable implementation of a fetch controller for SwiftData similar to `NSFetchedResultsController`.

It currently uses a private notification for model context changes which could be a problem for app review but probably not since it is just a string and not a private method.

Here is an example of how `@DynamicQuery` can be used to fetch detail items, updating the predicate whenever the parent item changes:
```
import SwiftUI
import SwiftDataX

struct DetailView: View {
    @Environment(\.modelContext) private var modelContext
    let item: Item
    @DynamicQuery(initialFetchDescriptor: .init(sortBy: [.init(\SubItem.timestamp, order: .reverse)])) var result: Result<[SubItem], Error>

    var body: some View {
        List {
            if case let .success(subItems) = result {
                ForEach(subItems) { subItem in
                    Text(subItem.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                }
                .onDelete { offsets in
                    deleteItems(offsets: offsets, subItems: subItems)
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
The sort can be a `@State` bool source of truth which could be easily replaced with `@SceneStorage` or `@AppStorage`. In the example below a computed binding is used to make it work with a `Table`:
```
import SwiftUI
import SwiftDataX

struct ItemTable: View {
    @DynamicQuery var result: Result<[Item], Error>
    @State var selectedItem: Item?
    @State var ascending = false
 
    var sortDescriptors: Binding<[SortDescriptor<Item>]> {
        Binding {
            _result.fetchDescriptor.sortBy
        } set: { v in
            // after this, the onChange will set the new sortDescriptor.
            ascending = v.first?.order == .forward
        }
    }
    
    var body: some View {
		Group {
			switch (result) {
		    	case .success(let items):
    		        Table(results, sortOrder: sortOrder) {
	    	            TableColumn("timestamp", value: \.timestamp) { item in
		                    Text("Item at \(item.timestamp ?? Date(), formatter: itemFormatter)")
	    	            }
					}
		        case .failure(let error):
				    Text(error.localizedDescription)
			}
		}
		.toolbar(id: "myToolbar") {
           ToolbarItem(id: "myItem", placement: .primaryAction) {
                Button(config.ascending ? "Hi" : "A-Z") {
                    withAnimation {
                        config.ascending.toggle()
                    }
                }
			}
        }		
        .onChange(of: ascending, initial: true) {
            _result.fetchDescriptor.sortBy = [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        }
    }
}
```