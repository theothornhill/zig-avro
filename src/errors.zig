pub const ReadError = error{
    UninitializedIterator,
    SpentIterator,
    UnionIdOutOfBounds,
    UnexpectedEndOfBuffer,
    IntegerOverflow,
};

pub const WriteError = error{
    ArrayTooLong,
    ArrayTooShort,
    UnexpectedEndOfBuffer,
};
