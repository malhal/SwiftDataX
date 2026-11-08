# SwiftDataX

`SwiftDataX` provides a high-performance, closure-driven query architecture for SwiftData centered around `FetchedModelsController`—a SwiftData equivalent to Core Data's `NSFetchedResultsController`. It replaces traditional rigid query property wrappers with a flexible view modifier and property wrapper combination that supports complex `FetchDescriptor` configurations, modular predicates, explicit error handling, and seamless animation preservation.

---

## Why This Architecture?

### 1. Solving the Predicate Comparison Problem

SwiftData's native `FetchDescriptor` is a value type, but its `.predicate` property relies on runtime `#Predicate` closures that **cannot be compared for equality (`Equatable`) by the compiler**.

If you attempt to diff raw descriptors directly, the system has no way to evaluate whether two predicates match, forcing queries to re-execute redundantly on every single view body evaluation. `SwiftDataX` introduces an **Equatable Guardian** pattern via `PredicateRepresentable`:

* **The Core Descriptor**: Handles standard parameters like sort descriptors, limits, offsets, and prefetching keys natively.
* **The Predicate Representable**: Encapsulates the predicate inside a lightweight, equatable configuration type.
* **The Result**: The controller only tears down and re-fetches when underlying query parameters or predicate configurations actually mutate.

### 2. Explicit Error Boundaries & Fine-Grained Control

Unlike standard SwiftUI property wrappers that fail silently or lack error interception, `Query2` exposes database fetch exceptions directly to the view layer via its projected configuration state (`projectedValue`), keeping your success and error paths cleanly separated.

---

## Core Components

* **`PredicateRepresentable`**: A protocol defining a lightweight, equatable, and sendable configuration blueprint (`makePredicate()`) that builds a SwiftData `Predicate`.
* **`AnyPredicateRepresentable`**: A type-erased container utilizing static type-opening to safely wrap and compare arbitrary predicate representables without losing type safety or triggering closure equality traps.
* **`Query2`**: A `@propertyWrapper` and `DynamicProperty` that monitors the environment's `ModelContext` and coordinate changes, driving a reactive view lifecycle via an internal `@Observable` coordinator.
* **`Query2ResultsView`**: A view helper that injects strongly-typed results and error states directly into your UI closure.
* **`FetchedModelsController`**: The underlying engine bridging SwiftData models to delegate-driven change notifications.

---

## API Design: Combining Descriptors & Predicates

`Query2` allows you to pass a standard `FetchDescriptor` (minus the predicate) alongside any custom `PredicateRepresentable`. A built-in `precondition` ensures that predicates are never accidentally duplicated across both layers:

```swift
// Initializing with a custom sort descriptor and a modular predicate representable
Query2ResultsView(Query2(fetchDescriptor, predicateRepresentable: MyPredicate())) { items, config in
    List(items) { item in
        Text(item.timestamp, format: .dateTime)
    }
}

```

---

## Usage Example

Here is how cleanly you can drive a dynamic query with sort controls, selection reconciliation, uncommitted animations, and custom predicate representables:

```swift
import SwiftUI
import SwiftDataX

struct ItemListView: View {
    @State private var ascending = true
    @State private var selection: Item?
    @Environment(\.modelContext) private var modelContext
    
    // 1. Define a modular predicate representable
    struct FilterByCounter: PredicateRepresentable {
        let maxCounter: Int
        
        func makePredicate() -> Predicate<Item> {
            let limit = maxCounter
            return #Predicate<Item> { $0.counter < limit }
        }
    }
    
    // 2. Construct a base FetchDescriptor for sorting
    var fetchDescriptor: FetchDescriptor<Item> {
        var descriptor = FetchDescriptor<Item>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: ascending ? .forward : .reverse)]
        return descriptor
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Button(ascending ? "Ascending" : "Descending") {
                    withAnimation {
                        ascending.toggle()
                    }
                }
                .padding()
                
                // 3. Drive the view using Query2 and Query2ResultsView
                Query2ResultsView(Query2(fetchDescriptor, predicateRepresentable: FilterByCounter(maxCounter: 5))) { items, config in
                    
                    if let error = config.lastError {
                        Text("Error loading items: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    }
                    
                    List(items, selection: $selection) { item in
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                    .onChange(of: items.map(\.id)) { oldIDs, newIDs in
                        if let selected = selection, !newIDs.contains(selected.id) {
                            let oldIndex = oldIDs.firstIndex(of: selected.id) ?? 0
                            let safeIndex = min(oldIndex, max(0, newIDs.count - 1))
                            selection = newIDs.isEmpty ? nil : items[safeIndex]
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }
    
    private func addItem() {
        let newItem = Item(timestamp: Date())
        modelContext.insert(newItem)
        selection = newItem
        
        withAnimation {
            modelContext.processPendingChanges()
        }
    }
}

```