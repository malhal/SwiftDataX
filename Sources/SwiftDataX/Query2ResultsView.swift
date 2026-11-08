//
//  Query2ResultsView.swift
//  SwiftDataX
//
//  Created by Malcolm Hall on 08/11/2026.
//
import SwiftData
import SwiftUI

@MainActor public struct Query2ResultsView<ResultType: PersistentModel, Content: View>: View {
    let query: Query2<ResultType>
    var results: [ResultType] {
        query.wrappedValue
    }
    
    private let content: ([ResultType], Query2<ResultType>.Config) -> Content
    
    public init(
        _ query: Query2<ResultType>,
        @ViewBuilder content: @escaping ([ResultType], Query2<ResultType>.Config) -> Content
    ) {
        self.query = query
        self.content = content
    }
    
    public var body: some View {
        content(results, query.projectedValue)
    }
}
