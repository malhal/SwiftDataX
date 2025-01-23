//
//  QueryView.swift
//  SwiftDataX
//
//  Created by Malcolm Hall on 23/01/2025.
//
import SwiftData
import SwiftUI

public struct QueryView<Model, Content>: View where Model: PersistentModel, Content: View {
    @Query var models: [Model]
    let content: ([Model]) -> Content
    
    public init(query: Query<Model, [Model]>, @ViewBuilder content: @escaping ([Model]) -> Content) {
        self.content = content
        self._models = query
    }
    
    public var body: some View {
        content(models)
    }
}
