//
//  FractionalIndex.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

/// Generates order keys for manual Kanban ordering using string fractional indexing
/// (a LexoRank-style scheme). A key can always be produced strictly between any two
/// existing keys, so inserting an item never requires renumbering its neighbours.
///
/// Keys are strings over a base-62 alphabet ordered by ASCII, so plain lexicographic
/// `String` comparison matches key order.
enum FractionalIndex {
    /// Base-62 digits in ascending ASCII order (`0-9`, `A-Z`, `a-z`).
    private static let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")

    private static func value(of char: Character) -> Int {
        digits.firstIndex(of: char) ?? 0
    }

    /// Returns a key strictly between `a` and `b`.
    /// - `a == nil` means "before everything"; `b == nil` means "after everything".
    /// Requires `a < b` when both are provided.
    static func keyBetween(_ a: String?, _ b: String?) -> String {
        let lower = a ?? ""
        return midpoint(lower, b)
    }

    /// Returns `count` strictly-increasing keys between `a` and `b` (used for multi-item drops).
    static func keysBetween(_ a: String?, _ b: String?, count: Int) -> [String] {
        guard count > 0 else { return [] }
        if count == 1 { return [keyBetween(a, b)] }

        if a == nil, let b = b {
            // Walk down from b, generating descending keys, then reverse to ascending.
            var result: [String] = []
            var next: String? = b
            for _ in 0..<count {
                let key = keyBetween(nil, next)
                result.append(key)
                next = key
            }
            return result.reversed()
        }

        if b == nil {
            // Walk up from a (possibly nil), generating ascending keys.
            var result: [String] = []
            var prev: String? = a
            for _ in 0..<count {
                let key = keyBetween(prev, nil)
                result.append(key)
                prev = key
            }
            return result
        }

        // Both bounds present: split around the midpoint and recurse.
        let mid = count / 2
        let midKey = keyBetween(a, b)
        let left = keysBetween(a, midKey, count: mid)
        let right = keysBetween(midKey, b, count: count - mid - 1)
        return left + [midKey] + right
    }

    // MARK: - Core midpoint

    /// Faithful port of the `fractional-indexing` midpoint algorithm.
    /// `a` is a (possibly empty) key; `b` is a key or `nil` (meaning +∞).
    private static func midpoint(_ a: String, _ b: String?) -> String {
        let base = digits.count
        let zero = digits[0]

        if let b = b, a >= b {
            // Defensive: callers guarantee a < b. Fall back to appending to a.
            return midpoint(a, nil)
        }

        // Strip the longest common prefix, padding `a` with the zero digit as needed.
        if let b = b {
            var n = 0
            let aChars = Array(a)
            let bChars = Array(b)
            while true {
                let ac = n < aChars.count ? aChars[n] : zero
                let bc = n < bChars.count ? bChars[n] : zero
                if ac != bc { break }
                n += 1
            }
            if n > 0 {
                let aRest = String(aChars.dropFirst(n))
                let bRest = String(bChars.dropFirst(n))
                return String(bChars.prefix(n)) + midpoint(aRest, bRest)
            }
        }

        // First digits differ (or a/b are empty at this position).
        let digitA = a.isEmpty ? 0 : value(of: a.first!)
        let digitB: Int = {
            guard let b = b, let first = b.first else { return base }
            return value(of: first)
        }()

        if digitB - digitA > 1 {
            let mid = Int((Double(digitA + digitB) / 2.0).rounded())
            return String(digits[mid])
        } else {
            if let b = b, b.count > 1 {
                return String(b.prefix(1))
            } else {
                // b is nil or a single digit: keep a's first digit and recurse deeper.
                let rest = a.isEmpty ? "" : String(a.dropFirst())
                return String(digits[digitA]) + midpoint(rest, nil)
            }
        }
    }
}
