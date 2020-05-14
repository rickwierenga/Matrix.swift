![](./.github/logo.png)

Matrix.swift is a lightweight, easy-to-use Matrix data structure in pure Swift. The backend is based on [Accelerate.framework](https://developer.apple.com/documentation/accelerate) to run compute intensive operations in parallel. The API is inspired by NumPy.

**This is not a fully fledged linear algebra library. If you are looking for one, check out [Surge](https://github.com/Jounce/Surge).**

## Performance

Processing a batch of MNIST-like images (on a 2016 15" MacBook Pro):

```swift
let totalSeconds = (0..<100).reduce(0.0) { _,_ in
    let x = Matrix(randomIn: 0...1, rows: 100, columns: 784)
    let w = Matrix(randomIn: 0...1, rows: 784, columns: 10)
    let start = CFAbsoluteTimeGetCurrent()
    _ = x • w
    let end = CFAbsoluteTimeGetCurrent()
    return Double(end - start)
}
print("\(totalSeconds / 100) seconds")
```

```
1.41e-06 seconds // ≈ 0.00141 ms ≈ 1.41 µs
```

## Installation

Simply copy the [`Matrix.swift`](https://github.com/rickwierenga/Matrix.swift/blob/master/Matrix.swift) file into your project.

## Usage

### Creating a `Matrix`

From an array

```swift
Matrix([1, 2, 3, 4])
Matrix([
  [1, 2],
  [3, 4]
])
```

Copy another matrix

```swift
Matrix(copy: anotherMatrix)
```

Repeating a number (similar to [this](https://developer.apple.com/documentation/swift/array/1641692-init)). This is an alternative to NumPy `zeros` or `ones`.

```swift
Matrix(repeating: .pi, rows: 2, columns: 2)
```

Random

```swift
Matrix(randomIn: 0...1, columns: 5, rows: 5)
```

### Indexing / slicing

`Matrix.swift` has powerful slicing support with `Range`. Slicing also supports in place assignment. 

```swift
var m = Matrix([
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
    [10, 11, 12]
])

m[1...3, 1...2] *= 2
```

```
Matrix([
    [1.0, 4.0, 6.0],
    [4.0, 10.0, 12.0],
    [7.0, 16.0, 18.0],
    [10.0, 11.0, 12.0],
])
```

You can assign integers to matrices:

```swift
m[...1, 1...] &= 0 // Is equal to: Matrix(repeating: 0, rows: a[...1, 1...].rows, columns: a[...1, 1...].columns)
```

```
Matrix([
    [1.0, 0.0, 0.0],
    [4.0, 0.0, 0.0],
    [7.0, 8.0, 9.0],
    [10.0, 11.0, 12.0],
])
```

### Arithmatic

Every usual arithmatic operators `+`, `-`, `*` and `/` is supported for Matrix-Scalar and Matrix-Matrix computations. Note that these are _elementwise_ if both operands are matrices. `+=`, `-=`, `*=`, `•=` can be used for in place operations.

`•` is used for matrix multiplication (hint: `alt+8`).

### Other features

Number of elements:

```swift
m.size
```

Sum:
```swift
m.sum
m.sum(.rows)
m.sum(.columns)
```

Argmax:
```swift
m.argmax(.rows)
m.argmax(.columns)
```

Argmin:
```swift
m.argmin(.rows)
m.argmin(.columns)
```

Transposition:
```swift
m.transposed()
```

Diagonal:
```swift
m.diagonal()
```

Reversed:
```swift
m.reversed()
```

Count zero / nonzero:
```swift
m.countNonzeros()
m.countZeros()
```

Flipping:
```swift
m.flipped(.rows)
m.flipped(.columns)
```

Flatten:
```swift
m.flatten()
```

Sorting:
```swift
m.sorted(.rows, sortOrder: .ascending)
m.sorted(.columns, sortOrder: .descending)
```

Searching:
```swift
m.firstIndex(where: {$0 == 9}) // -> (row: Optional(2), column: Optional(2))
```

## License

Matrix.swift is available under the MIT License. See [`LICENSE`](https://github.com/rickwierenga/Matrix.swift/blob/master/LICENSE) for details.

---
&copy;2020 Rick Wierenga
