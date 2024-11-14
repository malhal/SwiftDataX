# SwiftDataX

SwiftDataX brings extended features to SwiftData like an `NSFetchedResultsController` and `@Query` with dynamic predicate and sort descriptors.

It currently uses a private notification for model context changes which could be a problem for app review but probably not since it is just a string and not a private method.

Here is an example of how `@DynamicQuery` can be used to fetch detail items:
```
import SwiftUI
import SwiftData
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
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
#endif
            ToolbarItem {
                Button(action: addItem) {
                    Label("Add Item", systemImage: "plus")
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
    
    private func addItem() {
        withAnimation {
            let newSubItem = SubItem(item: item, timestamp: Date())
            modelContext.insert(newSubItem)
        }
        
    }
    
    private func deleteItems(offsets: IndexSet, subItems: [SubItem]) {
        withAnimation {
            for index in offsets {
               modelContext.delete(subItems[index])
            }
        }
    }
}
```