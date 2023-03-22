import Foundation

enum Token: Hashable, CustomStringConvertible {
    case multiplication
    case division
    case exponentiation
    case addition
    case subtraction
    case leftParen
    case rightParen
    case value(_ value: Decimal)

    var description : String {
        switch self {
        case .multiplication: return"*"
        case .division: return "/"
        case .exponentiation: return "^"
        case .addition: return "+"
        case .subtraction: return "-"
        case .leftParen: return "("
        case .rightParen: return ")"
        case let .value(value): return String(describing: value)
        }
    }
}

enum Notation {
    case ReversePolishNotation
    case Infix
    // parse as one of our "custom" notation schemes, such as `+ 10 20 30 40` = 10 + 20 + 30 + 40.
    case Custom
}

enum MathParserError: Error {
    case invalidExpression
}

// reverse polish notation parser.
// TODO write a parser for normal notation as well
class MathPaser {
    static func parse(_ input: String, notation: Notation? = nil) -> Decimal? {
        let notation = notation ?? detectNotation(input)
        do {
            switch notation {
            case .ReversePolishNotation:
                return try parseRPN(input)
            case .Infix:
                return try parseInfix(input)
            case .Custom:
                return try parseCustom(input)
            }
        } catch {
            return nil
        }
    }

    static func detectNotation(_ input: String) -> Notation {
        // it's easier to try and detect RPN then it is to detect normal notation. We'll look for
        // two numbers side by side, without an operator in between, as an indicator of RPN.
        var maxConsecutiveNumbers = 0
        var currentConsecutiveNumbers = 0
        var insideNumber = false
        for character in input {
            if character.isNumber && !insideNumber {
                currentConsecutiveNumbers += 1
                insideNumber = true
            }
            if character == " " {
                insideNumber = false
            }
            if ["*", "^", "/", "-", "+"].contains(character) {
                currentConsecutiveNumbers = 0
            }
            maxConsecutiveNumbers = max(maxConsecutiveNumbers, currentConsecutiveNumbers)
        }

        // if we start with an operator instead of a number, we're custom notation.
        // This might get more confusing to detect in the future if we add (non-reverse) polish notation,
        // aka prefix notation.
        if input.count > 0 && ["*", "^", "/", "-", "+"].contains(input[0]) {
            return .Custom
        }

        if maxConsecutiveNumbers > 1 {
            return .ReversePolishNotation
        }

        return .Infix
    }

    static func tokenize(_ input: String) throws -> [Token] {
        var stack: [Token] = []

        var valueBuffer = ""
        func flushValueBuffer() throws {
            if valueBuffer == "" {
                return
            }
            guard let value = Decimal(string: valueBuffer) else {
                throw MathParserError.invalidExpression
            }
            stack.append(.value(value))
            valueBuffer = ""
        }

        for (i, character) in input.enumerated() {
            // attempt to interpret - as unary minus. Otherwise, we'll interpret it as the subtraction
            // operator later down.
            if character == "-" && i + 1 < input.count && input[i + 1].isNumber {
                valueBuffer.append(character)
                continue
            }
            if character.isNumber || character == "." {
                valueBuffer.append(character)
                continue
            }

            if character == " " {
                try flushValueBuffer()
                continue
            }

            // the next character will be an operator (or throw an error), and if there's no space between
            // the previous value and the operator, we need to flush the value buffer.
            try flushValueBuffer()
            switch character {
            case "*":
                stack.append(.multiplication)
            case "/":
                stack.append(.division)
            case "^":
                stack.append(.exponentiation)
            case "+":
                stack.append(.addition)
            case "-":
                stack.append(.subtraction)
            case "(":
                stack.append(.leftParen)
            case ")":
                stack.append(.rightParen)
            default:
                // invalid character
                throw MathParserError.invalidExpression
            }
        }

        // we won't flush the last value in our buffer unless our input happens to end with a space.
        // Do so now.
        try flushValueBuffer()
        return stack
    }

    static func parseRPNStack(_ stack: [Token]) throws -> Decimal {
        var stack = stack
        var valueStack: [Decimal] = []

        func popValue() -> Decimal? {
            return valueStack.popLast()
        }

        while stack.count > 0 {
            let stackElement = stack.removeFirst()
            let value: Decimal

            switch stackElement {
            case let .value(value):
                valueStack.append(value)
                continue
            case .multiplication:
                guard let val2 = popValue(), let val1 = popValue() else {
                    throw MathParserError.invalidExpression
                }
                value = val1 * val2
            case .division:
                guard let val2 = popValue(), let val1 = popValue() else {
                    throw MathParserError.invalidExpression
                }
                value = val1 / val2
            case .exponentiation:
                guard let val2 = popValue(), let val1 = popValue() else {
                    throw MathParserError.invalidExpression
                }
                value = powDecimal(val1, val2)
            case .addition:
                guard let val2 = popValue(), let val1 = popValue() else {
                    throw MathParserError.invalidExpression
                }
                value = val1 + val2
            case .subtraction:
                guard let val2 = popValue(), let val1 = popValue() else {
                    throw MathParserError.invalidExpression
                }
                value = val1 - val2
            case .leftParen:
                // parentheses not allowed in RPN stack
                throw MathParserError.invalidExpression
            case .rightParen:
                throw MathParserError.invalidExpression
            }
            valueStack.append(value)
        }

        // if we have too many elements (or too few, if the input stack was empty) then avoid returning
        // an ambiguous value.
        if valueStack.count != 1 {
            throw MathParserError.invalidExpression
        }
        return valueStack[0]
    }

    static func parseRPN(_ input: String) throws -> Decimal {
        let stack = try tokenize(input)
        return try parseRPNStack(stack)
    }


    static func parseInfix(_ input: String) throws -> Decimal {
        // use dijkstra's shunting yard algorithm to convert the stack to RPN,
        // then parse the RPN stack to evaluate.
        var stack = try tokenize(input)
        var operationStack: [Token] = []
        var outputStack: [Token] = []

        func shuntOperation() {
            let operation = operationStack.popLast()!
            outputStack.append(operation)
        }

        let precedences = [
            Token.exponentiation: 4,
            Token.multiplication: 3,
            Token.division: 3,
            Token.addition: 2,
            Token.subtraction: 2
        ]

        while stack.count > 0 {
            let stackElement = stack.removeFirst()
            switch stackElement {
            case .value(_):
                outputStack.append(stackElement)
                continue
            case .multiplication, .exponentiation, .subtraction, .division, .addition:
                while true {
                    // try and shunt previous operations based on precedence.
                    if operationStack.count == 0 {
                        break
                    }
                    let precedence = precedences[stackElement]!
                    let previousOperation = operationStack[operationStack.count - 1]
                    // left parens could get pushed to the stack, in which case we stop.
                    if previousOperation == .leftParen {
                        break
                    }
                    let previousPrecedence = precedences[previousOperation]!

                    // strictly speaking, we should only be using <= if `operation` is left associative, but
                    // it doesn't matter for us because the only right associative operator is exponentiation,
                    // which doesn't tie for precedence with any other operator.
                    if precedence <= previousPrecedence {
                        shuntOperation()
                        // consider the next operation in line.
                        continue
                    }
                    break
                }
                // finally, add this operation to the stack.
                operationStack.append(stackElement)
            case .leftParen:
                operationStack.append(stackElement)
            case .rightParen:
                while operationStack.last != .leftParen {
                    // mismatched parentheses
                    if operationStack.isEmpty {
                        throw MathParserError.invalidExpression
                    }
                    shuntOperation()
                }
                // discard the left paren from the stack
                operationStack.removeLast()
            }
        }

        // shunt all remaining operations to the output stack at the end.
        while !operationStack.isEmpty {
            shuntOperation()
        }
        return try parseRPNStack(outputStack)
    }

    static func parseCustom(_ input: String) throws -> Decimal {
        var stack = try tokenize(input)

        // Custom notation to allow operations like + 1 2 3 4 = 1 + 2 + 3 + 4.
        //
        // Operations are right associative for the top-level operator. Associativity doesn't really
        // matter for the rest since the assignment is unambiguous and parenthesized.
        //
        // An input with n operations requires the number of inputs to be divisible by 2^n.
        //
        // Semantics by example:
        //
        // ```
        // custom: / 1 2 3 4
        // infix:  ((1 / 2) / 3) / 4
        // rpn:    1 2 / 3 / 4 /
        //
        // custom: +- 1 2 3 4 5 6 7 8
        // infix:  (((1 + 2) - (3 + 4)) - (5 + 6)) - (7 + 8)
        // rpn:    1 2 + 3 4 + - 5 6 + - 7 8 + -
        //
        // custom: +/- 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
        // infix:  (((((1 + 2) / (3 + 4)) - ((5 + 6) / (7 + 8))) - ((9 + 10) / (11 + 12))) - ((13 + 14) / (15 + 16)))
        // rpn:    1 2 + 3 4 + / 5 6 + 7 8 + / - 9 10 + 11 12 + / - 13 14 + 15 16 + / -
        // ```

        var operations: [Token] = []
        var valuesSeen: Int = 0
        var rpnStack: [Token] = []

        while stack.count > 0 {
            let stackElement = stack.removeFirst()
            switch stackElement {
            case .multiplication, .exponentiation, .subtraction, .division, .addition:
                // operation after value not allowed
                if valuesSeen > 0 {
                    throw MathParserError.invalidExpression
                }
                operations.append(stackElement)
            case .value(_):
                // value before operation not allowed
                if operations.isEmpty {
                    throw MathParserError.invalidExpression
                }
                valuesSeen += 1
                rpnStack.append(stackElement)
                // we can assume `operations` is fixed at this point due to our assert checks in both cases.

                if operations.count == 1 {
                    if valuesSeen > 1 {
                        rpnStack.append(operations[0])
                    }
                    continue
                }

                // otherwise, handle the general case number of operations.
                for (i, operation) in operations.enumerated() {
                    let v = valuesSeen
                    var n = i + 1

                    // the last operation is on the same schedule as the second to last operation, but blocked on the first occurence.
                    // This seems intuitively reasonable: the number of times the last operation occurs is the same as the number of
                    // second-level "bunches" of numbers, each of which have one occurence of the second to last operation.
                    // Except you insert the last operation inbetween every pair of those bunches, so it's actually 1 less than that.
                    if i == operations.count - 1 {
                        n -= 1
                        if v == powInt(2, n) {
                            continue
                        }
                    }

                    // intuitively, operations placed 1 index after appear half as often,
                    // with the most common (ie first) operation appearing after every two values.
                    if v % powInt(2, n) == 0 {
                        rpnStack.append(operation)
                    }
                }
            case .leftParen, .rightParen:
                // parens not allowed
                throw MathParserError.invalidExpression
            }
        }

        return try parseRPNStack(rpnStack)
    }

    // why does swift not have a builtin pow(int, int) :/
    static func powInt(_ val1: Int, _ val2: Int) -> Int {
        return Int(pow(Double(val1), Double(val2)))
    }

    static func powDecimal(_ val1: Decimal, _ val2: Decimal) -> Decimal {
        // pow(decimal, decimal) doesn't exist (for whatever reason), so we'll downcast
        // to double and perform exponentiation there, then upcast back to decimal afterwards.
        // We lost some precision this way, but I don't have another solution.
        let val1Double = Double(truncating: val1 as NSNumber)
        let val2Double = Double(truncating: val2 as NSNumber)
        let valueDouble = pow(val1Double, val2Double)
        // TODO this errors when valueDouble is infinite, eg 2 ^ 10000.
        // Apparently decimal doesn't support ±inf:
        // https://forums.swift.org/t/how-to-create-infinite-value-of-decimal/15058/2
        // We may need to restructure the calculator to return a string, or maybe returning
        // a container type instead which holds more information in the case of overflows.
        return Decimal(valueDouble)
    }
}
