pub const ReadError = error{
    UninitializedOrSpentIterator,
    UnionIdOutOfBounds,
    UnexpectedEndOfBuffer,
    IntegerOverflow,
};

pub const WriteError = error{
    ArrayTooLong,
    ArrayTooShort,
    UnexpectedEndOfBuffer,
};
