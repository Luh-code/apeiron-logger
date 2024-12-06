pub const LogError = error{
    AlreadyInitializedError,
    UnknownLogLevelError,
    ThreadMapDesyncError, // gets returned when a ThreadMap operation notices, that the internal HashMaps have different contents
    ThreadNotNamedError,
    MessageLengthExceededDefinedMaximum,
    FileNameGenerationError,
    VerbosityParsingError,
    FileNameError,
    FileHandlerError,
};
