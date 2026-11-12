//
//  Query2.swift
//  SwiftDataX
//
//  Created by Malcolm Hall on 08/11/2026.

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

@MainActor @propertyWrapper public struct Query2<ResultType: PersistentModel>: @preconcurrency DynamicProperty {
    
    @State private var coordinator = Coordinator()
    
    @Environment(\.modelContext) private var modelContext
    
    struct FetchDescriptorEquatableFix: Equatable {
        let fetchDescriptor: FetchDescriptor<ResultType>
    }
    
    private let equtatableFetchDescriptor: EquatableFetchDescriptor<ResultType>
    
    public init(_ fetchDescriptor: FetchDescriptor<ResultType>) {
        self.equtatableFetchDescriptor = EquatableFetchDescriptor(fetchDescriptor)
    }
    
    public var wrappedValue: [ResultType] {
        coordinator.config.models
    }
    
    public var projectedValue: Config {
        coordinator.config
    }
    
    public func update() {
        coordinator.update(from: self)
    }
    
    public struct Config {
        public internal(set) var models: [ResultType] = []
        public internal(set) var lastError: (any Error)?
    }
    
    
    @MainActor
    @Observable
    final class Coordinator: NSObject, @preconcurrency FetchedModelsControllerDelegate {
        
        private(set) var config = Config()
        
        @ObservationIgnored
        private var fmc: FetchedModelsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fmc?.delegate = self
            }
        }
        
        @ObservationIgnored
        private var equtatableFetchDescriptor: EquatableFetchDescriptor<ResultType>?
        
        @ObservationIgnored
        private var modelContext: ModelContext?
        
        func update(from parent: Query2) {
            if (modelContext, equtatableFetchDescriptor) == (parent.modelContext, parent.equtatableFetchDescriptor) {
                return
            }
            modelContext = parent.modelContext
            equtatableFetchDescriptor = parent.equtatableFetchDescriptor
            
            do {
                let fmc = FetchedModelsController<ResultType>(fetchDescriptor: parent.equtatableFetchDescriptor.descriptor, modelContext: parent.modelContext)
                try fmc.performFetch()
                self.fmc = fmc
                _config.models = fmc.fetchedModels ?? []
                _config.lastError = nil
            } catch {
                _config.lastError = error
                // keep prev models
            }
        }
        
        public func controllerDidChangeContent<T>(_ controller: FetchedModelsController<T>) where T : PersistentModel {
            config.models = controller.fetchedModels as? [ResultType] ?? []
        }
    }
}


