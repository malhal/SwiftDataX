//
//  QueryView.swift
//  SwiftDataX
//
//  Created by Malcolm Hall on 23/01/2025.
//
import SwiftData
import SwiftUI

public struct QueryView<Element, Content>: View where Element: PersistentModel, Content: View {
    @Query var elements: [Element]
    let content: ([Element]) -> Content
    
    public init(query: Query<Element, [Element]>, @ViewBuilder content: @escaping ([Element]) -> Content) {
        self.content = content
        self._elements = query
    }
    
    public var body: some View {
        content(elements)
    }
}
