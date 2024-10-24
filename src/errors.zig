pub const ReadError = error{
    UninitializedOrSpentIterator,
    UnionIdOutOfBounds,
    UnexpectedEndOfBuffer,
    IntegerOverflow,
};
