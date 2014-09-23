//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
// Intrinsic protocols shared with the compiler
//===----------------------------------------------------------------------===//

/// A type that represents a boolean value.
///
/// Types that conform to the `BooleanType` protocol can be used as
/// the condition in control statements (`if`, `while`, C-style `for`)
/// and other logical value contexts (e.g., `case` statement guards).
///
/// Only two types provided by Swift, `Bool` and `ObjCBool`, conform
/// to `BooleanType`. Expanding this set to include types that
/// represent more than simple boolean values is discouraged.
public protocol BooleanType {
  /// The value of `self`, expressed as a `Bool`.
  var boolValue: Bool { get }
}

/// Encapsulates iteration state and interface for iteration over a
/// *sequence*.
///
/// **Note:** While it is safe to copy a *generator*, advancing one
/// copy may invalidate the others.
///
/// Any code that uses multiple generators (or `for`\ ...\ `in` loops)
/// over a single *sequence* should have static knowledge that the
/// specific *sequence* is multi-pass, either because its concrete
/// type is known or because it is constrained to `CollectionType`.
/// Also, the generators must be obtained by distinct calls to the
/// *sequence's* `generate()` method, rather than by copying.
public protocol GeneratorType { 
  /// The type of element generated by `self`.
  typealias Element

  /// Advance to the next element and return it, or `nil` if no next
  /// element exists.
  ///
  /// Requires: `next()` has not been applied to a copy of `self`
  /// since the copy was made, and no preceding call to `self.next()`
  /// has returned `nil`.  Specific implementations of this protocol
  /// are encouraged to respond to violations of this requirement by
  /// calling `preconditionFailure("...")`.
  mutating func next() -> Element?
}

/// This protocol is an implementation detail of `SequenceType`; do
/// not use it directly.
///
/// Its requirements are inherited by `SequenceType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _SequenceType {
}

/// This protocol is an implementation detail of `SequenceType`; do
/// not use it directly.
///
/// Its requirements are inherited by `SequenceType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _Sequence_Type : _SequenceType {
  /// A type whose instances can produce the elements of this
  /// sequence, in order.
  typealias Generator : GeneratorType

  /// Return a *generator* over the elements of this *sequence*.  The
  /// *generator*\ 's next element is the first element of the
  /// sequence.
  ///
  /// Complexity: O(1)
  func generate() -> Generator
}

/// A type that can be iterated with a `for`\ ...\ `in` loop.
///
/// `SequenceType` makes no requirement on conforming types regarding
/// whether they will be destructively "consumed" by iteration.  To
/// ensure non-destructive iteration, constrain your *sequence* to
/// `CollectionType`.
public protocol SequenceType : _Sequence_Type {
  /// A type that provides the *sequence*\ 's iteration interface and
  /// encapsulates its iteration state.
  typealias Generator : GeneratorType

  /// Return a *generator* over the elements of this *sequence*.
  ///
  /// Complexity: O(1)
  func generate() -> Generator

  /// Return a value less than or equal to the number of elements in
  /// self, **nondestructively**.
  ///
  /// Complexity: O(N)
  func ~> (_:Self,_:(_UnderestimateCount,())) -> Int

  /// If `self` is multi-pass (i.e., a `CollectionType`), invoke the function
  /// on `self` and return its result.  Otherwise, return `nil`.
  func ~> <R>(_: Self, _: (_PreprocessingPass, ((Self)->R))) -> R?

  /// Create a native array buffer containing the elements of `self`,
  /// in the same order.
  func ~>(
    _:Self, _: (_CopyToNativeArrayBuffer, ())
  ) -> _ContiguousArrayBuffer<Self.Generator.Element>
}

public struct _CopyToNativeArrayBuffer {}
public func _copyToNativeArrayBuffer<Args>(args: Args)
  -> (_CopyToNativeArrayBuffer, Args)
{
  return (_CopyToNativeArrayBuffer(), args)
}

// Operation tags for underestimateCount.  See Index.swift for an
// explanation of operation tags.
public struct _UnderestimateCount {}
internal func _underestimateCount<Args>(args: Args)
  -> (_UnderestimateCount, Args)
{
  return (_UnderestimateCount(), args)
}

// Default implementation of underestimateCount for Sequences.  Do not
// use this operator directly; call underestimateCount(s) instead
public func ~> <T: _SequenceType>(s: T,_:(_UnderestimateCount, ())) -> Int {
  return 0
}

/// Return an underestimate of the number of elements in the given
/// sequence, without consuming the sequence.  For Sequences that are
/// actually Collections, this will return countElements(x)
public func underestimateCount<T: SequenceType>(x: T) -> Int {
  return x~>_underestimateCount()
}

// Operation tags for preprocessingPass.  See Index.swift for an
// explanation of operation tags.
public struct _PreprocessingPass {}

// Default implementation of `_preprocessingPass` for Sequences.  Do not
// use this operator directly; call `_preprocessingPass(s)` instead
public func ~> <
  T : _SequenceType, R
>(s: T, _: (_PreprocessingPass, ( (T)->R ))) -> R? {
  return nil
}

internal func _preprocessingPass<Args>(args: Args)
  -> (_PreprocessingPass, Args)
{
  return (_PreprocessingPass(), args)
}

// Pending <rdar://problem/14011860> and <rdar://problem/14396120>,
// pass a GeneratorType through GeneratorSequence to give it "SequenceType-ness"
public struct GeneratorSequence<
  G: GeneratorType
> : GeneratorType, SequenceType {
  public init(_ base: G) {
    _base = base
  }
  
  /// Advance to the next element and return it, or `nil` if no next
  /// element exists.
  ///
  /// Requires: `next()` has not been applied to a copy of `self`
  /// since the copy was made, and no preceding call to `self.next()`
  /// has returned `nil`.
  public mutating func next() -> G.Element? {
    return _base.next()
  }

  /// Return a *generator* over the elements of this *sequence*.
  ///
  /// Complexity: O(1)
  public func generate() -> GeneratorSequence {
    return self
  }
  
  var _base: G
}

/// A type that can be converted to an associated "raw" type, then
/// converted back to produce an instance equivalent to the original.
public protocol RawRepresentable {
  /// The "raw" type that can be used to represent all values of `Self`.
  ///
  /// Every distinct value of `self` has a corresponding unique
  /// value of `RawValue`, but `RawValue` may have representations
  /// that do not correspond to an value of `Self`.
  typealias RawValue

  /// Convert from a value of `RawValue`, yielding `nil` iff
  /// `rawValue` does not correspond to a value of `Self`.
  init?(rawValue: RawValue)

  /// The corresponding value of the "raw" type.
  ///
  /// `Self(rawValue: self.rawValue)!` is equivalent to `self`.
  var rawValue: RawValue { get }
}

// Workaround for our lack of circular conformance checking. Allow == to be
// defined on _RawOptionSetType in order to satisfy the Equatable requirement of
// RawOptionSetType without a circularity our type-checker can't yet handle.

/// This protocol is an implementation detail of `RawOptionSetType`; do
/// not use it directly.
///
/// Its requirements are inherited by `RawOptionSetType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _RawOptionSetType: RawRepresentable, Equatable {
  typealias RawValue: BitwiseOperationsType, Equatable
  init(rawValue: RawValue)
}

public func == <T: _RawOptionSetType>(a: T, b: T) -> Bool {
  return a.rawValue == b.rawValue
}

public func & <T: _RawOptionSetType>(a: T, b: T) -> T {
  return T(rawValue: a.rawValue & b.rawValue)
}
public func | <T: _RawOptionSetType>(a: T, b: T) -> T {
  return T(rawValue: a.rawValue | b.rawValue)
}
public func ^ <T: _RawOptionSetType>(a: T, b: T) -> T {
  return T(rawValue: a.rawValue ^ b.rawValue)
}
public prefix func ~ <T: _RawOptionSetType>(a: T) -> T {
  return T(rawValue: ~a.rawValue)
}

/// Protocol for `NS_OPTIONS` imported from Objective-C
public protocol RawOptionSetType : _RawOptionSetType, BitwiseOperationsType,
    NilLiteralConvertible {
  // FIXME: Disabled pending <rdar://problem/14011860> (Default
  // implementations in protocols)
  // The Clang importer synthesizes these for imported NS_OPTIONS.

  /* init?(rawValue: RawValue) { self.init(rawValue) } */
}

/// Conforming types can be initialized with `nil`.
public protocol NilLiteralConvertible {
  /// Create an instance initialized with `nil`.
  init(nilLiteral: ())
}

public protocol _BuiltinIntegerLiteralConvertible {
  init(_builtinIntegerLiteral value: _MaxBuiltinIntegerType)
}

/// Conforming types can be initialized with integer literals
public protocol IntegerLiteralConvertible {
  typealias IntegerLiteralType : _BuiltinIntegerLiteralConvertible
  /// Create an instance initialized to `value`.
  init(integerLiteral value: IntegerLiteralType)
}

public protocol _BuiltinFloatLiteralConvertible {
  init(_builtinFloatLiteral value: _MaxBuiltinFloatType)
}

/// Conforming types can be initialized with floating point literals
public protocol FloatLiteralConvertible {
  typealias FloatLiteralType : _BuiltinFloatLiteralConvertible
  /// Create an instance initialized to `value`.
  init(floatLiteral value: FloatLiteralType)
}

public protocol _BuiltinBooleanLiteralConvertible {
  init(_builtinBooleanLiteral value: Builtin.Int1)
}

/// Conforming types can be initialized with the boolean literals
/// `true` and `false`.
public protocol BooleanLiteralConvertible {
  typealias BooleanLiteralType : _BuiltinBooleanLiteralConvertible
  /// Create an instance initialized to `value`.
  init(booleanLiteral value: BooleanLiteralType)
}

internal protocol _BuiltinCharacterLiteralConvertible {
  init(_builtinCharacterLiteral value: Builtin.Int32)
}

internal protocol CharacterLiteralConvertible {
  typealias CharacterLiteralType : _BuiltinCharacterLiteralConvertible
  /// Create an instance initialized to `value`.
  init(characterLiteral value: CharacterLiteralType)
}

public protocol _BuiltinUnicodeScalarLiteralConvertible {
  init(_builtinUnicodeScalarLiteral value: Builtin.Int32)
}

/// Conforming types can be initialized with string literals
/// containing a single `Unicode scalar value
/// <http://www.unicode.org/glossary/#unicode_scalar_value>`_.
public protocol UnicodeScalarLiteralConvertible {
  typealias UnicodeScalarLiteralType : _BuiltinUnicodeScalarLiteralConvertible
  /// Create an instance initialized to `value`.
  init(unicodeScalarLiteral value: UnicodeScalarLiteralType)
}

public protocol _BuiltinExtendedGraphemeClusterLiteralConvertible
  : _BuiltinUnicodeScalarLiteralConvertible {

  init(
    _builtinExtendedGraphemeClusterLiteral start: Builtin.RawPointer,
    byteSize: Builtin.Word,
    isASCII: Builtin.Int1)
}

/// Conforming types can be initialized with string literals
/// containing a single `Unicode extended grapheme cluster
/// <http://www.unicode.org/glossary/#extended_grapheme_cluster>`_.
public protocol ExtendedGraphemeClusterLiteralConvertible
  : UnicodeScalarLiteralConvertible {

  typealias ExtendedGraphemeClusterLiteralType
    : _BuiltinExtendedGraphemeClusterLiteralConvertible
  /// Create an instance initialized to `value`.
  init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType)
}

public protocol _BuiltinStringLiteralConvertible
  : _BuiltinExtendedGraphemeClusterLiteralConvertible {
  
  init(
    _builtinStringLiteral start: Builtin.RawPointer,
    byteSize: Builtin.Word,
    isASCII: Builtin.Int1)
}

public protocol _BuiltinUTF16StringLiteralConvertible
  : _BuiltinStringLiteralConvertible {
  
  init(
    _builtinUTF16StringLiteral start: Builtin.RawPointer,
    numberOfCodeUnits: Builtin.Word)
}

/// Conforming types can be initialized with arbitrary string literals
public protocol StringLiteralConvertible
  : ExtendedGraphemeClusterLiteralConvertible {
  // FIXME: when we have default function implementations in protocols, provide
  // an implementation of init(extendedGraphemeClusterLiteral:).

  typealias StringLiteralType : _BuiltinStringLiteralConvertible
  /// Create an instance initialized to `value`.
  init(stringLiteral value: StringLiteralType)
}

/// Conforming types can be initialized with array literals
public protocol ArrayLiteralConvertible {
  typealias Element
  /// Create an instance initialized with `elements`.
  init(arrayLiteral elements: Element...)
}

/// Conforming types can be initialized with dictionary literals
public protocol DictionaryLiteralConvertible {
  typealias Key
  typealias Value
  /// Create an instance initialized with `elements`.
  init(dictionaryLiteral elements: (Key, Value)...)
}

/// Conforming types can be initialized with string interpolations
/// containing `\(`\ ...\ `)` clauses.
public protocol StringInterpolationConvertible {
  init(stringInterpolation strings: Self...)
  init<T>(stringInterpolationSegment expr: T)
}

