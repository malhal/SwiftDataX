# SwiftDataX

SwiftDataX provides a high-performance, closure-driven query architecture for SwiftData centered around `FetchedModelsController`—a SwiftData equivalent to Core Data's `NSFetchedResultsController`. It replaces traditional property wrappers and rigid query components with a clean view modifier approach (`.query(...)`) that brings explicit error handling, precise state tracking, and seamless animation preservation directly into your views.

---

## Why This Architecture?

### 1. View Modifier vs. Property Wrapper (Why Avoid `@Query`?)

Standard property wrappers like `@Query` enforce compile-time constraints that make dynamic queries, closures, and custom error UI difficult to structure gracefully.

* **Lifecycle & Scoping**: The `.query(...)` view modifier acts as a natural boundary. It scopes the `QueryObserver` lifecycle tightly to the view's appearance and passes strongly-typed results (`[ResultType]`) directly into a clean callback.
* **Explicit Error Boundaries**: Traditional property wrappers cannot throw or safely expose database fetch exceptions to the view layer. This design intercepts errors explicitly via an `onError:` callback, keeping your success and error paths cleanly separated.

### 2. Two-Tier Lifecycle Management

* **Tier 1 (Context Switch / Re-init)**: Automatically tears down and re-initializes the `FetchedModelsController` when the underlying `ModelContext` changes or a new configuration blueprint is injected.
* **Tier 2 (Reactivity)**: The internal `QueryObserver` listens to changes via `FetchedModelsControllerDelegate`, bumping a reactive version counter to trigger clean, atomic view updates when inserts, deletes, or modifications happen.

---

## Core Components

* **`FetchDescriptorRepresentable`**: A protocol defining a lightweight, equatable, and sendable configuration blueprint (`makeFetchDescriptor()`) that builds a SwiftData `FetchDescriptor`.
> **Why a factory method (`makeFetchDescriptor()`)?**
> Although the blueprint itself is a value type and explicitly conforms to `Equatable`, Swift's `#Predicate` closures are not `Equatable` and cannot be diffed directly by the compiler. If we passed predicates straight into an equality check, the system would have no way to compare them, causing the query to re-execute redundantly on every single view initialization.
> By wrapping the raw parameters that drive the predicate inside this custom `Equatable` type and generating the `FetchDescriptor` fresh via `makeFetchDescriptor()` only when those parameters change, we effectively give the non-equatable predicate an equatable guardian. This ensures fetches only run when underlying data parameters actually mutate.


* **`QueryModifier`**: A custom `ViewModifier` managing the controller lifecycle, model context triggers, and error interception.
* **`QueryObserver`**: An `@Observable` helper acting as the delegate for `FetchedModelsController`, bumping revisions reactively.
* **`FetchedModelsController`**: The underlying engine bridging SwiftData models to delegate-driven change notifications.

---

## Animation & Transaction Behavior

### Uncommitted Changes & `notifyAndProcessPendingChanges()`

Because SwiftData mutations occur asynchronously by default, uncommitted in-memory inserts or deletions can close their `withAnimation` transaction block before the `FetchedModelsController` delegate fires.

To ensure uncommitted local writes animate smoothly into view during user actions, call `modelContext.notifyAndProcessPendingChanges()` inside your animation block. This triggers the custom `willPerformChanges` notification required by the observation engine to process pending changes immediately:

```swift
private func addItem() {
    let newItem = Item(timestamp: Date())
    modelContext.insert(newItem)
    selection = newItem

    withAnimation {
        modelContext.notifyAndProcessPendingChanges()
    }
}

```

---

## Usage Example

Here is how cleanly you can drive a dynamic query with sort controls, selection reconciliation, a toolbar action, and explicit error handling using the `.query(_:handleResults:onError:)` modifier:

```swift
import SwiftUI
import SwiftDataX

struct ItemListView: View {
    @State private var ascending = true
    @State private var items: [Item] = []
    @State private var selection: Item?
    @State private var fetchError: Error?
    @Environment(\.modelContext) private var modelContext
    
    // Define a domain-specific query configuration
    struct SortedItems: FetchDescriptorRepresentable {
        let ascending: Bool
         
        func makeFetchDescriptor() -> FetchDescriptor<Item> {
            var descriptor = FetchDescriptor<Item>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: ascending ? .forward : .reverse)]
            return descriptor
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button(ascending ? "Ascending" : "Descending") {
                        withAnimation {
                            ascending.toggle()
                        }
                    }
                    Spacer()
                    Text("\(items.count) items")
                }
                .padding()
                 
                List(items, selection: $selection) { item in
                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
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
            .query(SortedItems(ascending: ascending)) { newItems in
                // Handle automatic selection fallback if the selected item was deleted
                if let selected = selection, !newItems.contains(where: { $0 == selected }) {
                    let oldIndex = items.firstIndex(where: { $0 == selected }) ?? 0
                    let safeIndex = min(oldIndex, max(0, newItems.count - 1))
                    selection = newItems.isEmpty ? nil : newItems[safeIndex]
                }
                
                withAnimation {
                    items = newItems
                }
            } onError: { error in
                fetchError = error
                print("Query failed: \(error)")
            }
        }
    }
    
    private func addItem() {
        let newItem = Item(timestamp: Date())
        modelContext.insert(newItem)
        selection = newItem
        
        withAnimation {
            modelContext.notifyAndProcessPendingChanges()
        }
    }
}

```