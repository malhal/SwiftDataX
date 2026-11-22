//
//  FetchedModelsView.swift
//  SwiftDataX
//
//  Created by Malcolm Hall on 08/11/2026.
//
import SwiftData
import SwiftUI

public struct EquatableFetchDescriptor<ResultType: PersistentModel>: Equatable {
    public let descriptor: FetchDescriptor<ResultType>
    private let baseDescriptor: FetchDescriptor<ResultType>
    private let predicateDescription: String?
    
    public init(_ descriptor: FetchDescriptor<ResultType>) {
        self.descriptor = descriptor
        self.predicateDescription = descriptor.predicate.map { String(describing: $0) }
        
        var base = descriptor
        base.predicate = nil
        self.baseDescriptor = base
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.baseDescriptor == rhs.baseDescriptor &&
        lhs.predicateDescription == rhs.predicateDescription
    }
}

@MainActor public struct FetchedModelsView<ResultType: PersistentModel, Content: View>: View {
    
    @State private var observer: Observer?
    @State private var lastError: Error?
    
    @Environment(\.modelContext) private var modelContext
    
    struct FetchDescriptorEquatableFix: Equatable {
        let fetchDescriptor: FetchDescriptor<ResultType>
    }
    
    private let equtatableFetchDescriptor: EquatableFetchDescriptor<ResultType>
    
    /// The inputs a fetch depends on; a change to either one refetches.
    private struct FetchKey: Equatable {
        let fetchDescriptor: EquatableFetchDescriptor<ResultType>
        let modelContext: ModelContext
    }
    
    private let content: ([ResultType], Error?) -> Content
    
    public init(
        _ fetchDescriptor: FetchDescriptor<ResultType>,
        @ViewBuilder content: @escaping ([ResultType], Error?) -> Content
    ) {
        self.equtatableFetchDescriptor = EquatableFetchDescriptor(fetchDescriptor)
        self.content = content
    }
    
    public var body: some View {
        content(observer?.models ?? [], lastError)
            .onAppear {
                if observer == nil {
                    update()
                }
            }
            .onChange(of: FetchKey(fetchDescriptor: equtatableFetchDescriptor, modelContext: modelContext)) {
                update()
            }
    }
    
    private func update() {
        do {
            let fmc = FetchedModelsController<ResultType>(fetchDescriptor: equtatableFetchDescriptor.descriptor, modelContext: modelContext)
            try fmc.performFetch()
            observer = Observer(fmc: fmc)
            lastError = nil
        } catch {
            lastError = error
            // keep prev models
        }
    }
    
    @MainActor
    @Observable
    final class Observer: NSObject, @preconcurrency FetchedModelsControllerDelegate {
        
        private(set) var models: [ResultType]?
        
        @ObservationIgnored
        private let fmc: FetchedModelsController<ResultType>?
        
        init(fmc: FetchedModelsController<ResultType>) {
            self.models = fmc.fetchedModels
            self.fmc = fmc
            super.init()
            fmc.delegate = self
        }
        
        public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
            models = controller.fetchedModels as? [ResultType]
        }
    }
}
