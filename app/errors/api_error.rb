module ApiError
    class Base < StandardError; end
    class InvalidToken < Base; end
    class TokenExpired < Base; end
    class Unauthorized < Base; end
    class ResourceNotFound < Base; end
    class ValidationError < Base; end
end
