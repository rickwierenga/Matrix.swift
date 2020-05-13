// Matrix.swift: A lightweight, easy-to-use Matrix data structure in pure Swift.

/*
 Copyright (c) 2020 Rick Wierenga

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import Accelerate

extension Array where Element: Comparable {
    internal func argmax() -> Index? { indices.max(by: { self[$0] < self[$1] }) }
    internal func argmin() -> Index? { indices.min(by: { self[$0] < self[$1] }) }
}

public struct Matrix {
    internal var data: [Float32]
    public let columns: Int
    public let rows: Int

    public var size: Int { columns * rows }
    public var sum: Float32 {
        return vDSP.sum(data)
    }

    // MARK: - Initialization
    internal init(data: [Float32], rows: Int, columns: Int) {
        precondition(rows > 0, "Rows must be greater than 0")
        precondition(columns > 0, "Columns must be greater than 0")
        precondition(data.count == rows * columns, "Size of data must be rows * columns")
        self.data = data
        self.rows = rows
        self.columns = columns
    }

    public init(_ array: [Float32]) {
        self.init(data: array, rows: 1, columns: array.count)
    }

    public init(_ array: [[Float32]]) {
        precondition(array.dropFirst().allSatisfy { $0.count == array.first?.count },
                     "All rows must have the same number of columns")
        let data = array.flatMap { $0 }
        let rows = array.count
        let columns = data.count / rows
        self.init(data: data, rows: rows, columns: columns)
    }

    public init(repeating repeatedValue: Float32, rows: Int, columns: Int) {
        self.init(data: [Float32].init(repeating: repeatedValue, count: rows * columns),
                  rows: rows, columns: columns)
    }

    public init(copy: Matrix) {
        self.init(data: copy.data, rows: copy.rows, columns: copy.columns)
    }

    public init(randomIn range: Range<Float>, rows: Int, columns: Int) {
        self.init(data: (0..<rows*columns).map({ _ in Float.random(in: range) }),
                  rows: rows, columns: columns)
    }

    public init(randomIn range: ClosedRange<Float>, rows: Int, columns: Int) {
        self.init(data: (0..<rows*columns).map({ _ in Float.random(in: range) }),
                  rows: rows, columns: columns)
    }

    // MARK: - Indexing / slicing
    private func isValid(row: Int) -> Bool { row >= 0 && row < rows }
    private func isValid(column: Int) -> Bool { column >= 0 && column < columns }
    private func isValid(rows: ClosedRange<Int>) -> Bool {
        isValid(row: rows.lowerBound) && isValid(row: rows.upperBound)
    }
    private func isValid(columns: ClosedRange<Int>) -> Bool {
        isValid(column: columns.lowerBound) && isValid(column: columns.upperBound)
    }

    public subscript(row: Int, column: Int) -> Float32 {
        get {
            precondition(isValid(row: row) && isValid(column: column), "Index out of range")
            return data[(row * columns) + column]
        }
        set {
            precondition(isValid(row: row) && isValid(column: column), "Index out of range")
            self.data[(row * columns) + column] = newValue
        }
    }

    public subscript(rows: ClosedRange<Int>, column: Int) -> Matrix {
        get {
            precondition(isValid(rows: rows) && isValid(column: column), "Index out of range")
            let startIndex = rows.lowerBound * columns + column
            let endIndex = startIndex + (rows.count * columns)
            let strides = stride(from: startIndex, to: endIndex, by: columns)
            let data = strides.map { self.data[$0] }
            return Matrix(data: data, rows: rows.count, columns: 1)
        }
        set {
            precondition(isValid(rows: rows) && isValid(column: column), "Index out of range")
            let startIndex = rows.lowerBound * columns + column
            let endIndex = startIndex + rows.count
            stride(from: startIndex, to: endIndex+1, by: columns).enumerated().forEach {
                data[$1] = newValue[$0, 0]
            }
        }
    }

    public subscript(rows: PartialRangeFrom<Int>, column: Int) -> Matrix {
        get { return self[rows.lowerBound...self.rows-1, column] }
        set { self[rows.lowerBound...self.rows-1, column] = newValue }
    }

    public subscript(rows: PartialRangeThrough<Int>, column: Int) -> Matrix {
        get { return self[0...rows.upperBound, column] }
        set { self[0...rows.upperBound, column] = newValue }
    }

    public subscript(row: Int, columns: ClosedRange<Int>) -> Matrix {
        get {
            precondition(isValid(row: row) && isValid(columns: columns), "Index out of range")
            let startIndex = row * self.columns + columns.lowerBound
            let endIndex = columns.count + startIndex
            let data = [Float](self.data[startIndex..<endIndex])
            return Matrix(data: data, rows: 1, columns: columns.count)
        }
        set {
            precondition(isValid(row: row) && isValid(columns: columns), "Index out of range")
            precondition(newValue.rows == 1 && columns.count == newValue.data.count, "Invalid shape")
            let startIndex = row * self.columns + columns.lowerBound
            let endIndex = columns.count + startIndex
            self.data.replaceSubrange(startIndex..<endIndex, with: newValue.data)
        }
    }

    public subscript(row: Int, columns: PartialRangeFrom<Int>) -> Matrix {
        get { return self[row, columns.lowerBound...self.columns-1] }
        set { self[row, columns.lowerBound...self.columns-1] = newValue }
    }

    public subscript(row: Int, columns: PartialRangeThrough<Int>) -> Matrix {
        get { return self[row, 0...columns.upperBound] }
        set { self[row, 0...columns.upperBound] = newValue }
    }

    public subscript(rows: ClosedRange<Int>, columns: ClosedRange<Int>) -> Matrix {
        get {
            precondition(isValid(rows: rows) && isValid(columns: columns), "Index out of range")
            let data = [Float]((0..<rows.count).map({ self[$0, columns].data }).joined())
            return Matrix(data: data, rows: rows.count, columns: columns.count)
        }
        set {
            precondition(isValid(rows: rows) && isValid(columns: columns), "Index out of range")
            precondition(newValue.rows == rows.count && newValue.columns == columns.count, "Invalid shape")
            (0..<rows.count).forEach({ self[$0, columns] = newValue[$0, 0...] })
        }
    }

    public subscript(rows: PartialRangeFrom<Int>, columns: PartialRangeFrom<Int>) -> Matrix {
        get { return self[rows.lowerBound...self.rows-1, columns.lowerBound...self.columns-1] }
        set { self[rows.lowerBound...self.rows-1, columns.lowerBound...self.columns-1] = newValue }
    }

    public subscript(rows: PartialRangeFrom<Int>, columns: PartialRangeThrough<Int>) -> Matrix {
        get { return self[rows.lowerBound...self.rows-1, 0...columns.upperBound] }
        set { self[rows.lowerBound...self.rows-1, 0...columns.upperBound] = newValue }
    }

    public subscript(rows: PartialRangeThrough<Int>, columns: PartialRangeFrom<Int>) -> Matrix {
        get { return self[0...rows.upperBound, columns.lowerBound...self.columns-1] }
        set { self[0...rows.upperBound, columns.lowerBound...self.columns-1] = newValue }
    }

    public subscript(rows: PartialRangeThrough<Int>, columns: PartialRangeThrough<Int>) -> Matrix {
        get { return self[0...rows.upperBound, 0...columns.upperBound] }
        set { self[0...rows.upperBound, 0...columns.upperBound] = newValue }
    }

    // MARK: - Statistics
    public enum Axis {
        case rows, columns
    }

    public func sum(_ axis: Axis) -> Matrix {
        switch axis {
        case .rows: return Matrix((0..<rows).map({ self[$0, ...(columns-1)].sum }))
        case .columns: return Matrix((0..<columns).map({ self[...(rows-1), $0].sum }))
        }
    }

    public func argmax(_ axis: Axis) -> [Int] {
        switch axis {
        case .rows: return (0..<rows).map({ self[$0, ...(columns-1)].data.argmax()! })
        case .columns: return (0..<columns).map({ self[...(rows-1), $0].data.argmax()! })
        }
    }

    public func argmin(_ axis: Axis) -> [Int] {
        switch axis {
        case .rows: return (0..<rows).map({ self[$0, ...(columns-1)].data.argmin()! })
        case .columns: return (0..<columns).map({ self[...(rows-1), $0].data.argmin()! })
        }
    }

    // MARK: - Transformations
    public func flatten() -> Matrix {
        return Matrix(data: self.data, rows: 1, columns: size)
    }

    public func transposed() -> Matrix {
        var x = Matrix(repeating: 0, rows: columns, columns: rows)
        vDSP_mtrans(self.data, 1, &x.data, 1, vDSP_Length(x.rows), vDSP_Length(x.columns))
        return x
    }

    public func diagonal() -> Matrix {
        let data = (0..<min(rows, columns)).map({ self[$0, $0] })
        return Matrix(data: data, rows: 1, columns: min(rows, columns))
    }

    public func reversed() -> Matrix {
        var data = self.data
        vDSP_vrvrs(&data, 1, vDSP_Length(size))
        return Matrix(data: data, rows: rows, columns: columns)
    }

    public func flip(_ axis: Axis) -> Matrix {
        switch axis {
        case .rows:
            return self.reversed().flip(.columns)
        case .columns:
            let data = [Float32]( (0..<rows).map({ self[$0, 0...].data.reversed() }).joined() )
            return Matrix(data: data, rows: rows, columns: columns)
        }
    }

    // MARK: - Counting zeros
    public func countZeros() -> Int {
        return data.filter({ $0 == 0 }).count
    }

    public func countNonzeros() -> Int {
        return size - countZeros()
    }

    // MARK: - Sorting
    public func sorted(_ axis: Axis, sortOrder: vDSP.SortOrder) -> Matrix {
        let data: [[Float32]]
        switch axis {
        case .rows:
            data = [[Float32]]((0..<rows).map({
                var data = self[$0, ...(columns-1)].data
                vDSP.sort(&data, sortOrder: sortOrder)
                return data
            }))
            return Matrix(data: data.flatMap({ $0 }), rows: rows, columns: columns)
        case .columns:
            data = [[Float32]]((0..<columns).map({
                var data = self[...(rows-1), $0].data
                vDSP.sort(&data, sortOrder: (sortOrder == .ascending) ? .descending : .ascending)
                return data
            }))
            return Matrix(data: data.flatMap({ $0 }), rows: columns, columns: rows).transposed()
        }
    }
}

extension Matrix: CustomStringConvertible {
    public var description: String {
        var lines = ["Matrix(" + (rows > 1 ? "[" : "")]
        for i in 0..<rows {
            let row = (0..<columns)
                .map({"\(self[i, $0])"})
                .joined(separator: ", ")
            lines.append("    [\(row)],")
        }
        lines.append((rows > 1 ? "]" : "") + ")")
        return lines.joined(separator: "\n")
    }
}

extension Matrix: Equatable {}

// MARK: - Matrix arithmatic
// MARK: Matrix-scalar
public func &=(lhs: inout Matrix, rhs: Float32) {
    lhs = Matrix(repeating: rhs, rows: lhs.rows, columns: lhs.columns)
}

public func +(lhs: Matrix, rhs: Float32) -> Matrix {
    var x = Matrix(repeating: 0, rows: lhs.rows, columns: lhs.columns)
    var scalar = rhs // We need a variable to get a pointer.
    vDSP_vsadd(lhs.data, 1, &scalar, &x.data, 1, vDSP_Length(x.columns * x.rows))
    return x
}

public func -(lhs: Matrix, rhs: Float32) -> Matrix {
    return lhs + (-1 * rhs)
}

public func *(lhs: Matrix, rhs: Float32) -> Matrix {
    var x = Matrix(repeating: 0, rows: lhs.rows, columns: lhs.columns)
    var scalar = rhs // We need a variable to get a pointer.
    vDSP_vsmul(lhs.data, 1, &scalar, &x.data, 1, vDSP_Length(x.columns * x.rows))
    return x
}

public func /(lhs: Matrix, rhs: Float32) -> Matrix {
    var x = Matrix(repeating: 0, rows: lhs.rows, columns: lhs.columns)
    var scalar = rhs // We need a variable to get a pointer.
    vDSP_vsdiv(lhs.data, 1, &scalar, &x.data, 1, vDSP_Length(x.columns * x.rows))
    return x
}

public func +(lhs: Float32, rhs: Matrix) -> Matrix { rhs + lhs }
public func +=(lhs: inout Matrix, rhs: Float32) { lhs = lhs + rhs }
public func -(lhs: Float32, rhs: Matrix) -> Matrix { rhs + (-1 * lhs) }
public func -=(lhs: inout Matrix, rhs: Float32) { lhs = lhs - rhs }
public func *(lhs: Float32, rhs: Matrix) -> Matrix { rhs * lhs }
public func *=(lhs: inout Matrix, rhs: Float32) { lhs = lhs * rhs }
public func /=(lhs: inout Matrix, rhs: Float32) { lhs = lhs / rhs }

// MARK: Matrix-matrix
public func +(lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.rows == rhs.rows && lhs.columns == rhs.columns)
    var x = Matrix(repeating: 0.0, rows: lhs.rows, columns: lhs.columns)
    vDSP_vadd(rhs.data, 1, lhs.data, 1, &x.data, 1, vDSP_Length(lhs.columns * lhs.rows))
    return x
}

public func -(lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.rows == rhs.rows && lhs.columns == rhs.columns)
    var x = Matrix(repeating: 0.0, rows: lhs.rows, columns: lhs.columns)
    vDSP_vsub(rhs.data, 1, lhs.data, 1, &x.data, 1, vDSP_Length(lhs.columns * lhs.rows))
    return x
}

public func *(lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.rows == rhs.rows && lhs.columns == rhs.columns)
    var x = Matrix(repeating: 0.0, rows: lhs.rows, columns: lhs.columns)
    vDSP_vmul(rhs.data, 1, lhs.data, 1, &x.data, 1, vDSP_Length(lhs.columns * lhs.rows))
    return x
}

public func /(lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.rows == rhs.rows && lhs.columns == rhs.columns)
    var x = Matrix(repeating: 0.0, rows: lhs.rows, columns: lhs.columns)
    vDSP_vdiv(rhs.data, 1, lhs.data, 1, &x.data, 1, vDSP_Length(lhs.columns * lhs.rows))
    return x
}

infix operator •: MultiplicationPrecedence
public func •(lhs: Matrix, rhs: Matrix) -> Matrix {
    precondition(lhs.columns == rhs.rows)
    var x = Matrix(repeating: 0, rows: lhs.rows, columns: rhs.columns)
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(lhs.rows), Int32(rhs.columns), Int32(lhs.columns), 1.0,
                lhs.data, Int32(lhs.columns), rhs.data, Int32(lhs.columns), 0.0, &(x.data), Int32(x.columns))
    return x
}

public func +=(lhs: inout Matrix, rhs: Matrix) { lhs = lhs + rhs }
public func -=(lhs: inout Matrix, rhs: Matrix) { lhs = lhs - rhs }
public func *=(lhs: inout Matrix, rhs: Matrix) { lhs = lhs * rhs }
infix operator •= : MultiplicationPrecedence
public func •=(lhs: inout Matrix, rhs: Matrix) { lhs = lhs • rhs }
