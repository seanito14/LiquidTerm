// Pane/ResizableSplitStack.swift
// An arbitrary-length resizable stack of views with draggable dividers.

import SwiftUI

struct ResizableSplitStack<Content: View, Data: RandomAccessCollection>: View where Data.Element: Identifiable, Data.Index == Int {
    let axis: Axis
    let data: Data
    @Binding var fractions: [CGFloat]
    let content: (Data.Element) -> Content
    
    @State private var dragStartFractions: [CGFloat]? = nil
    
    init(axis: Axis, data: Data, fractions: Binding<[CGFloat]>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.axis = axis
        self.data = data
        self._fractions = fractions
        self.content = content
    }
    
    var body: some View {
        GeometryReader { proxy in
            let totalSize = axis == .horizontal ? proxy.size.width : proxy.size.height
            let dividerThickness: CGFloat = 6
            let dividerCount = CGFloat(max(0, data.count - 1))
            let availableSize = max(1, totalSize - (dividerCount * dividerThickness))
            
            if axis == .horizontal {
                HStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        content(item)
                            .frame(width: max(40, availableSize * fraction(at: index)))
                            .clipped()
                        
                        if index < data.count - 1 {
                            dividerView(index: index, totalSize: availableSize, isHorizontal: true)
                                .frame(width: dividerThickness)
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        content(item)
                            .frame(height: max(40, availableSize * fraction(at: index)))
                            .clipped()
                        
                        if index < data.count - 1 {
                            dividerView(index: index, totalSize: availableSize, isHorizontal: false)
                                .frame(height: dividerThickness)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Divider
    
    @ViewBuilder
    private func dividerView(index: Int, totalSize: CGFloat, isHorizontal: Bool) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    (isHorizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartFractions == nil {
                            dragStartFractions = fractions
                        }
                        guard let start = dragStartFractions else { return }
                        guard totalSize.isFinite, totalSize > 1 else { return }
                        let delta = (isHorizontal ? value.translation.width : value.translation.height) / totalSize
                        applyDelta(index: index, delta: delta, startFractions: start)
                    }
                    .onEnded { _ in
                        dragStartFractions = nil
                    }
            )
    }
    
    // MARK: - Fraction Logic
    
    private func fraction(at index: Int) -> CGFloat {
        guard index < fractions.count else {
            return 1.0 / CGFloat(max(1, data.count))
        }
        
        let value = fractions[index]
        if !value.isFinite || value <= 0 {
            return 1.0 / CGFloat(max(1, data.count))
        }
        return value
    }
    
    private func applyDelta(index: Int, delta: CGFloat, startFractions: [CGFloat]) {
        guard index < startFractions.count - 1 else { return }
        guard delta.isFinite else { return }
        
        let minFraction: CGFloat = 0.05
        let combined = startFractions[index] + startFractions[index + 1]
        guard combined.isFinite, combined > minFraction * 2 else { return }
        
        let newA = max(minFraction, min(combined - minFraction, startFractions[index] + delta))
        let newB = combined - newA
        guard newA.isFinite, newB.isFinite else { return }
        
        var updated = fractions
        // Ensure the array is the right size
        while updated.count < data.count {
            updated.append(1.0 / CGFloat(max(1, data.count)))
        }
        if updated.count > data.count {
            updated = Array(updated.prefix(data.count))
        }
        
        updated[index] = newA
        updated[index + 1] = newB
        
        let sanitized = updated.map { value in
            if value.isFinite, value > 0 {
                return value
            }
            return minFraction
        }
        let total = sanitized.reduce(CGFloat.zero, +)
        guard total.isFinite, total > 0 else { return }
        
        fractions = sanitized.map { $0 / total }
    }
}
