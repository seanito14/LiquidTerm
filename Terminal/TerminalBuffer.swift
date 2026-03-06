// Terminal/TerminalBuffer.swift
// Grid-based terminal buffer with cursor, scroll regions, and alternate screen.

import AppKit

class TerminalBuffer {
    private(set) var rows: Int
    private(set) var cols: Int
    
    // Main and alternate screen
    private var mainGrid: [[TerminalCell]]
    private var altGrid: [[TerminalCell]]
    private var usingAltScreen = false
    
    // Cursor state
    var cursorRow: Int = 0
    var cursorCol: Int = 0
    var cursorVisible: Bool = true
    
    // Saved cursor (for DECSC / DECRC)
    private var savedCursorRow: Int = 0
    private var savedCursorCol: Int = 0
    private var savedAttributes: CellAttributes = .default
    
    // Current attributes for new characters
    var currentAttributes: CellAttributes = .default
    
    // Scroll region (top and bottom, inclusive 0-based)
    var scrollTop: Int = 0
    var scrollBottom: Int = 0
    
    // Modes
    var autoWrapMode: Bool = true
    var originMode: Bool = false
    private var wrapPending: Bool = false
    
    // Tab stops
    private var tabStops: Set<Int> = []
    
    // Generation counter for change detection
    private(set) var generation: UInt64 = 0
    
    // Active grid accessor
    var grid: [[TerminalCell]] {
        get { usingAltScreen ? altGrid : mainGrid }
        set {
            if usingAltScreen { altGrid = newValue }
            else { mainGrid = newValue }
        }
    }
    
    init(rows: Int, cols: Int) {
        self.rows = max(1, rows)
        self.cols = max(1, cols)
        let blankRow = [TerminalCell](repeating: .blank, count: self.cols)
        self.mainGrid = [[TerminalCell]](repeating: blankRow, count: self.rows)
        self.altGrid = [[TerminalCell]](repeating: blankRow, count: self.rows)
        self.scrollBottom = self.rows - 1
        resetTabStops()
    }
    
    private func resetTabStops() {
        tabStops.removeAll()
        for i in stride(from: 0, to: cols, by: 8) {
            tabStops.insert(i)
        }
    }
    
    func bumpGeneration() {
        generation &+= 1
    }
    
    // MARK: - Character Output
    
    func putChar(_ ch: Character) {
        if wrapPending {
            // Auto-wrap: move to the next line
            wrapPending = false
            cursorCol = 0
            index()  // move down (scrolling if needed)
        }
        
        if cursorRow >= 0 && cursorRow < rows && cursorCol >= 0 && cursorCol < cols {
            grid[cursorRow][cursorCol] = TerminalCell(character: ch, attributes: currentAttributes)
        }
        
        if cursorCol < cols - 1 {
            cursorCol += 1
        } else if autoWrapMode {
            wrapPending = true
        }
        bumpGeneration()
    }
    
    // MARK: - Cursor Movement
    
    func moveCursor(row: Int, col: Int) {
        cursorRow = clampRow(row)
        cursorCol = clampCol(col)
        wrapPending = false
    }
    
    func moveCursorUp(_ n: Int) {
        cursorRow = max(scrollTop, cursorRow - max(1, n))
        wrapPending = false
    }
    
    func moveCursorDown(_ n: Int) {
        cursorRow = min(scrollBottom, cursorRow + max(1, n))
        wrapPending = false
    }
    
    func moveCursorForward(_ n: Int) {
        cursorCol = min(cols - 1, cursorCol + max(1, n))
        wrapPending = false
    }
    
    func moveCursorBackward(_ n: Int) {
        cursorCol = max(0, cursorCol - max(1, n))
        wrapPending = false
    }
    
    func setCursorCol(_ col: Int) {
        cursorCol = clampCol(col)
        wrapPending = false
    }
    
    func setCursorRow(_ row: Int) {
        cursorRow = clampRow(row)
        wrapPending = false
    }
    
    func carriageReturn() {
        cursorCol = 0
        wrapPending = false
    }
    
    /// LF / VT / FF — move cursor down, scrolling if at bottom of scroll region.
    func index() {
        if cursorRow == scrollBottom {
            scrollUp(1)
        } else if cursorRow < rows - 1 {
            cursorRow += 1
        }
        wrapPending = false
        bumpGeneration()
    }
    
    /// Reverse index (ESC M) — move cursor up, scrolling down if at top.
    func reverseIndex() {
        if cursorRow == scrollTop {
            scrollDown(1)
        } else if cursorRow > 0 {
            cursorRow -= 1
        }
        wrapPending = false
        bumpGeneration()
    }
    
    func nextLine() {
        carriageReturn()
        index()
    }
    
    // MARK: - Tab
    
    func tab() {
        let nextTab = tabStops.sorted().first(where: { $0 > cursorCol }) ?? (cols - 1)
        cursorCol = min(nextTab, cols - 1)
        wrapPending = false
    }
    
    // MARK: - Backspace
    
    func backspace() {
        if cursorCol > 0 {
            cursorCol -= 1
        }
        wrapPending = false
    }
    
    // MARK: - Erase Operations
    
    func eraseInDisplay(_ mode: Int) {
        switch mode {
        case 0: // From cursor to end
            eraseInLine(0)
            for r in (cursorRow + 1)..<rows {
                clearRow(r)
            }
        case 1: // From start to cursor
            for r in 0..<cursorRow {
                clearRow(r)
            }
            eraseInLine(1)
        case 2, 3: // Entire screen
            for r in 0..<rows {
                clearRow(r)
            }
            if mode == 3 {
                // Also clear scrollback — we don't have scrollback beyond the grid
            }
        default:
            break
        }
        bumpGeneration()
    }
    
    func eraseInLine(_ mode: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        switch mode {
        case 0: // From cursor to end of line
            for c in cursorCol..<cols {
                grid[cursorRow][c] = TerminalCell(character: " ", attributes: currentAttributes)
            }
        case 1: // From start of line to cursor
            for c in 0...min(cursorCol, cols - 1) {
                grid[cursorRow][c] = TerminalCell(character: " ", attributes: currentAttributes)
            }
        case 2: // Entire line
            clearRow(cursorRow)
        default:
            break
        }
        bumpGeneration()
    }
    
    func eraseCharacters(_ n: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        let count = max(1, n)
        let end = min(cursorCol + count, cols)
        for c in cursorCol..<end {
            grid[cursorRow][c] = TerminalCell(character: " ", attributes: currentAttributes)
        }
        bumpGeneration()
    }
    
    private func clearRow(_ r: Int) {
        guard r >= 0 && r < rows else { return }
        grid[r] = [TerminalCell](repeating: TerminalCell(character: " ", attributes: currentAttributes), count: cols)
    }
    
    // MARK: - Scrolling
    
    func scrollUp(_ n: Int) {
        let count = max(1, min(n, scrollBottom - scrollTop + 1))
        let blankRow = [TerminalCell](repeating: TerminalCell(character: " ", attributes: currentAttributes), count: cols)
        for _ in 0..<count {
            grid.remove(at: scrollTop)
            grid.insert(blankRow, at: scrollBottom)
        }
        bumpGeneration()
    }
    
    func scrollDown(_ n: Int) {
        let count = max(1, min(n, scrollBottom - scrollTop + 1))
        let blankRow = [TerminalCell](repeating: TerminalCell(character: " ", attributes: currentAttributes), count: cols)
        for _ in 0..<count {
            grid.remove(at: scrollBottom)
            grid.insert(blankRow, at: scrollTop)
        }
        bumpGeneration()
    }
    
    // MARK: - Insert / Delete Lines
    
    func insertLines(_ n: Int) {
        guard cursorRow >= scrollTop && cursorRow <= scrollBottom else { return }
        let count = min(max(1, n), scrollBottom - cursorRow + 1)
        let blankRow = [TerminalCell](repeating: .blank, count: cols)
        for _ in 0..<count {
            if scrollBottom < grid.count {
                grid.remove(at: scrollBottom)
            }
            grid.insert(blankRow, at: cursorRow)
        }
        bumpGeneration()
    }
    
    func deleteLines(_ n: Int) {
        guard cursorRow >= scrollTop && cursorRow <= scrollBottom else { return }
        let count = min(max(1, n), scrollBottom - cursorRow + 1)
        let blankRow = [TerminalCell](repeating: .blank, count: cols)
        for _ in 0..<count {
            grid.remove(at: cursorRow)
            grid.insert(blankRow, at: scrollBottom)
        }
        bumpGeneration()
    }
    
    // MARK: - Insert / Delete Characters
    
    func insertCharacters(_ n: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        let count = min(max(1, n), cols - cursorCol)
        for _ in 0..<count {
            grid[cursorRow].insert(.blank, at: cursorCol)
            if grid[cursorRow].count > cols {
                grid[cursorRow].removeLast()
            }
        }
        bumpGeneration()
    }
    
    func deleteCharacters(_ n: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        let count = min(max(1, n), cols - cursorCol)
        for _ in 0..<count {
            if cursorCol < grid[cursorRow].count {
                grid[cursorRow].remove(at: cursorCol)
            }
            grid[cursorRow].append(.blank)
        }
        // Ensure row length stays correct
        if grid[cursorRow].count > cols {
            grid[cursorRow] = Array(grid[cursorRow].prefix(cols))
        }
        bumpGeneration()
    }
    
    // MARK: - Alternate Screen
    
    func enableAltScreen() {
        guard !usingAltScreen else { return }
        saveCursor()
        usingAltScreen = true
        let blankRow = [TerminalCell](repeating: .blank, count: cols)
        altGrid = [[TerminalCell]](repeating: blankRow, count: rows)
        cursorRow = 0
        cursorCol = 0
        scrollTop = 0
        scrollBottom = rows - 1
        bumpGeneration()
    }
    
    func disableAltScreen() {
        guard usingAltScreen else { return }
        usingAltScreen = false
        restoreCursor()
        scrollTop = 0
        scrollBottom = rows - 1
        bumpGeneration()
    }
    
    // MARK: - Save / Restore Cursor
    
    func saveCursor() {
        savedCursorRow = cursorRow
        savedCursorCol = cursorCol
        savedAttributes = currentAttributes
    }
    
    func restoreCursor() {
        cursorRow = clampRow(savedCursorRow)
        cursorCol = clampCol(savedCursorCol)
        currentAttributes = savedAttributes
        wrapPending = false
    }
    
    // MARK: - Scroll Region
    
    func setScrollRegion(top: Int, bottom: Int) {
        let t = max(0, min(top, rows - 1))
        let b = max(t, min(bottom, rows - 1))
        scrollTop = t
        scrollBottom = b
        moveCursor(row: originMode ? t : 0, col: 0)
    }
    
    func resetScrollRegion() {
        scrollTop = 0
        scrollBottom = rows - 1
    }
    
    // MARK: - Resize
    
    func resize(newRows: Int, newCols: Int) {
        let nr = max(1, newRows)
        let nc = max(1, newCols)
        guard nr != rows || nc != cols else { return }
        
        mainGrid = resizeGrid(mainGrid, toRows: nr, cols: nc)
        altGrid = resizeGrid(altGrid, toRows: nr, cols: nc)
        
        rows = nr
        cols = nc
        scrollTop = 0
        scrollBottom = nr - 1
        cursorRow = min(cursorRow, nr - 1)
        cursorCol = min(cursorCol, nc - 1)
        resetTabStops()
        bumpGeneration()
    }
    
    private func resizeGrid(_ oldGrid: [[TerminalCell]], toRows newRows: Int, cols newCols: Int) -> [[TerminalCell]] {
        var newGrid = [[TerminalCell]]()
        newGrid.reserveCapacity(newRows)
        for r in 0..<newRows {
            if r < oldGrid.count {
                var row = oldGrid[r]
                if row.count < newCols {
                    row.append(contentsOf: [TerminalCell](repeating: .blank, count: newCols - row.count))
                } else if row.count > newCols {
                    row = Array(row.prefix(newCols))
                }
                newGrid.append(row)
            } else {
                newGrid.append([TerminalCell](repeating: .blank, count: newCols))
            }
        }
        return newGrid
    }
    
    // MARK: - Reset
    
    func fullReset() {
        let blankRow = [TerminalCell](repeating: .blank, count: cols)
        mainGrid = [[TerminalCell]](repeating: blankRow, count: rows)
        altGrid = [[TerminalCell]](repeating: blankRow, count: rows)
        usingAltScreen = false
        cursorRow = 0
        cursorCol = 0
        cursorVisible = true
        currentAttributes = .default
        scrollTop = 0
        scrollBottom = rows - 1
        autoWrapMode = true
        originMode = false
        wrapPending = false
        resetTabStops()
        bumpGeneration()
    }
    
    // MARK: - Rendering
    
    func toAttributedString(font: NSFont, defaultFG: NSColor, defaultBG: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        
        for r in 0..<rows {
            for c in 0..<cols {
                let cell = grid[r][c]
                let attrs = cell.attributes
                
                var fgColor = attrs.fg.toNSColor(isForeground: true, defaultFG: defaultFG, defaultBG: defaultBG)
                var bgColor = attrs.bg.toNSColor(isForeground: false, defaultFG: defaultFG, defaultBG: defaultBG)
                
                if attrs.inverse {
                    swap(&fgColor, &bgColor)
                }
                
                if attrs.dim {
                    fgColor = fgColor.withAlphaComponent(0.5)
                }
                
                let useFont = attrs.bold ? boldFont : font
                
                var strAttrs: [NSAttributedString.Key: Any] = [
                    .font: useFont,
                    .foregroundColor: fgColor,
                    .backgroundColor: bgColor,
                ]
                
                if attrs.underline {
                    strAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                if attrs.strikethrough {
                    strAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
                
                result.append(NSAttributedString(string: String(cell.character), attributes: strAttrs))
            }
            if r < rows - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: font, .foregroundColor: defaultFG]))
            }
        }
        
        return result
    }
    
    // MARK: - Helpers
    
    private func clampRow(_ r: Int) -> Int {
        max(0, min(r, rows - 1))
    }
    
    private func clampCol(_ c: Int) -> Int {
        max(0, min(c, cols - 1))
    }
}
