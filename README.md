# SwiftDataX

> **Archived:** SwiftDataX has been merged into [swift-mh](https://github.com/malhal/swift-mh). Use `FetchedModelsView` and `MHFetchedModelsController` from its `MHSwiftData` module instead. This repository is no longer updated.

`SwiftDataX` provides a closure-driven query view for SwiftData built on `FetchedModelsController`, a SwiftData equivalent of Core Data's `NSFetchedResultsController`. Instead of the `@Query` property wrapper, you pass any `FetchDescriptor` to `FetchedModelsView` and get the results and fetch error in a closure. The results update in place as models are inserted, updated and deleted, so list animations are preserved.

---

## Why This Architecture?

### 1. Solving the Predicate Comparison Problem

`FetchDescriptor` is a value type, but its `predicate` is a `#Predicate` closure that **cannot be compared for equality**. Without a way to tell whether a descriptor changed, a view would have to refetch every time its `body` is recomputed.

`EquatableFetchDescriptor` wraps a descriptor and makes it `Equatable`:

* **Everything but the predicate** (sort descriptors, fetch limit, offset, relationship key paths to prefetch, and so on) is compared natively.
* **The predicate** is compared by its `String(describing:)` text, which includes the values it captures.
* **The result**: `FetchedModelsView` only builds a new controller and refetches when the query actually changes.

### 2. Errors as a Closure Parameter

Like `@Query`, which exposes the error of its last fetch through its property wrapper (`_items.fetchError`), `FetchedModelsView` provides the error of the last fetch, but as a parameter of your content closure. When a fetch fails, the previous results are kept.

---

## Core Components

* **`FetchedModelsView`**: A view that fetches a `FetchDescriptor` from the environment's `ModelContext` and passes the results and the last fetch error to its content closure. It refetches when the descriptor or the model context changes.
* **`EquatableFetchDescriptor`**: Wraps a `FetchDescriptor` to make it `Equatable`, comparing the predicate by its description.
* **`FetchedModelsController`**: The engine behind the view. It performs the fetch, then observes the model context's changes and applies inserts, updates, deletes and moves to the results, notifying its delegate.
* **`ModelContextChanges`**: Parses the inserted, updated and deleted models from the model context's change notification.
* **`QueryResultsView`**: A view that wraps a standard SwiftData `Query` and passes its results, fetch error and model context to a content closure.

---

## API Design

Pass a `FetchDescriptor`, including its predicate, and a closure that receives the results and the error of the last fetch:

```swift
FetchedModelsView(fetchDescriptor) { items, error in
    List(items) { item in
        Text(item.timestamp, format: .dateTime)
    }
}
```

---

## Usage Example

A list with a sort order and a filter that change the query, an error message, animated changes, and a selection that moves to the next item when the selected item is deleted:

```swift
import SwiftUI
import SwiftData
import SwiftDataX

@Model
final class Item {
    var timestamp = Date()
    var counter = 0
    
    init() { }
}

struct ItemListView: View {
    @State private var ascending = true
    @State private var maxCounter = 5
    @State private var selection: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    
    // A new descriptor is built on every recomputation of body;
    // FetchedModelsView only refetches when it actually differs.
    private var fetchDescriptor: FetchDescriptor<Item> {
        let limit = maxCounter
        return FetchDescriptor<Item>(
            predicate: #Predicate { $0.counter < limit },
            sortBy: [SortDescriptor(\.timestamp, order: ascending ? .forward : .reverse)]
        )
    }
    
    var body: some View {
        NavigationStack {
            FetchedModelsView(fetchDescriptor) { items, error in
                VStack {
                    if let error {
                        Text("Error loading items: \(error.localizedDescription)")
                            .foregroundStyle(.red)
                    }
                    
                    List(selection: $selection) {
                        ForEach(items) { item in
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .tag(item.persistentModelID)
                        }
                    }
                    .animation(.default, value: items.map(\.persistentModelID))
                }
                .onChange(of: items.map(\.persistentModelID)) { oldIDs, newIDs in
                    // The selected item was deleted, from anywhere: select the item now in its place.
                    guard let selected = selection, !newIDs.contains(selected) else { return }
                    let oldIndex = oldIDs.firstIndex(of: selected) ?? 0
                    selection = newIDs.isEmpty ? nil : newIDs[min(oldIndex, newIDs.count - 1)]
                }
            }
            .toolbar {
                ToolbarItem {
                    Button(ascending ? "Ascending" : "Descending") {
                        ascending.toggle()
                    }
                }
                ToolbarItem {
                    Stepper("Max Counter \(maxCounter)", value: $maxCounter)
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }
    
    private func addItem() {
        let newItem = Item()
        modelContext.insert(newItem)
        selection = newItem.persistentModelID
    }
}
```
