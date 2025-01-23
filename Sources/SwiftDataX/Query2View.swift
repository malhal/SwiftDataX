//
//  QueryView.swift
//  SwiftDataX
//
//  Created by Malcolm Hall on 23/01/2025.
//
import SwiftData
import SwiftUI

public struct Query2View<Model, Content>: View where Model: PersistentModel, Content: View {
    @Query2 var result: Result<[Model], Error>
    let content: (Result<[Model], Error>) -> Content
    
    public init(query: Query2<Model>, @ViewBuilder content: @escaping (Result<[Model], Error>) -> Content) {
        self.content = content
        self._result = query
    }
    
    public var body: some View {
        content(result)
    }
}
