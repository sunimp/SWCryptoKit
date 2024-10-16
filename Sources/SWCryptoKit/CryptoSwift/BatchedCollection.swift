//
//  BatchedCollection.swift
//  SWCryptoKit
//
//  Created by Sun on 2024/8/14.
//

// MARK: - BatchedCollectionIndex

struct BatchedCollectionIndex<Base: Collection> {
    let range: Range<Base.Index>
}

// MARK: Comparable

extension BatchedCollectionIndex: Comparable {
    static func == (lhs: BatchedCollectionIndex<Base>, rhs: BatchedCollectionIndex<Base>) -> Bool {
        lhs.range.lowerBound == rhs.range.lowerBound
    }

    static func < (lhs: BatchedCollectionIndex<Base>, rhs: BatchedCollectionIndex<Base>) -> Bool {
        lhs.range.lowerBound < rhs.range.lowerBound
    }
}

// MARK: - BatchedCollectionType

protocol BatchedCollectionType: Collection {
    associatedtype Base: Collection
}

// MARK: - BatchedCollection

struct BatchedCollection<Base: Collection>: Collection {
    // MARK: Nested Types

    typealias Index = BatchedCollectionIndex<Base>

    // MARK: Properties

    let base: Base
    let size: Int

    // MARK: Computed Properties

    var startIndex: Index {
        Index(range: base.startIndex ..< nextBreak(after: base.startIndex))
    }

    var endIndex: Index {
        Index(range: base.endIndex ..< base.endIndex)
    }

    // MARK: Functions

    func index(after idx: Index) -> Index {
        Index(range: idx.range.upperBound ..< nextBreak(after: idx.range.upperBound))
    }

    subscript(idx: Index) -> Base.SubSequence {
        base[idx.range]
    }

    private func nextBreak(after idx: Base.Index) -> Base.Index {
        base.index(idx, offsetBy: size, limitedBy: base.endIndex) ?? base.endIndex
    }
}

extension Collection {
    func batched(by size: Int) -> BatchedCollection<Self> {
        BatchedCollection(base: self, size: size)
    }
}

extension Collection<UInt8> where Self.Index == Int {
    /// Big endian order
    var uInt64Array: [UInt64] {
        if isEmpty {
            return []
        }

        var result = [UInt64](reserveCapacity: 32)
        for idx in stride(from: startIndex, to: endIndex, by: 8) {
            let val = UInt64(bytes: self, fromIndex: idx).bigEndian
            result.append(val)
        }

        return result
    }
}
