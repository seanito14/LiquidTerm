// Pane/ResizableSplitStack.swift
// Implements an arbitrary-length resizable stack of views.

import SwiftUI

struct ResizableSplitStack<Content: View, Data: RandomAccessCollection>: View where Data.Element: Identifiable, Data.Index == Int {
    let axis: Axis
    let data: Data
    @Binding var fractions: [CGFloat]
    let content: (Data.Element) -> Content
    
    init(axis: Axis, data: Data, fractions: Binding<[CGFloat]>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.axis = axis
        self.data = data
        self._fractions = fractions
        self.content = content
    }
    
    var body: some View {
        GeometryReader { proxy in
            if axis == .horizontal {
                HStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        content(item)
                            .frame(width: max(0, proxy.size.width * getFraction(at: index)))
                        
                        // Add a divider after each item except the last
                        if index < data.count - 1 {
                            Divider()
                                .frame(width: 8)
                                .background(Color.white.opacity(0.001))
                                .onHover { inside in
                                    if inside {
                                        NSCursor.resizeLeftRight.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            adjustFraction(index: index, delta: value.translation.width / proxy.size.width)
                                        }
                                )
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        content(item)
                            .frame(height: max(0, proxy.size.height * getFraction(at: index)))
                        
                        if index < data.count - 1 {
                            Divider()
                                .frame(height: 8)
                                .background(Color.white.opacity(0.001))
                                .onHover { inside in
                                    if inside {
                                        NSCursor.resizeUpDown.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            adjustFraction(index: index, delta: value.translation.height / proxy.size.height)
                                        }
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func getFraction(at index: Int) -> CGFloat {
        if index < fractions.count {
            return fractions[index]
        }
        return 1.0 / CGFloat(max(1, data.count))
    }
    
    private func adjustFraction(index: Int, delta: CGFloat) {
        guard index < fractions.count - 1 else { return }
        
        let minFraction: CGFloat = 0.1
        let currentSize1 = fractions[index]
        let currentSize2 = fractions[index + 1]
        
        // Ensure sizes don't go below minimum
        let newSize1 = max(minFraction, min(currentSize1 + currentSize2 - minFraction, currentSize1 + delta))
        let newSize2 = currentSize1 + currentSize2 - newSize1
        
        var newFractions = fractions
        newFractions[index] = newSize1
        newFractions[index + 1] = newSize2
        
        fractions = newFractions
    }
}
