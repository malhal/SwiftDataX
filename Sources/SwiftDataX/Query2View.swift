//
//  QueryView.swift
//  SwiftDataX
//
//  Created by Malcolm Hall on 23/01/2025.
//
import SwiftData
import SwiftUI

public struct Query2View<Element, Content>: View where Element: PersistentModel, Content: View {
    @Query2 var result: Result<[Element], Error>
    let content: (Result<[Element], Error>) -> Content
    
    public init(query: Query2<Element>, @ViewBuilder content: @escaping (Result<[Element], Error>) -> Content) {
        self.content = content
        self._result = query
    }
    
    public var body: some View {
        content(result)
    }
}
