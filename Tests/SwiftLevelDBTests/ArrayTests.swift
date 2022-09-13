import XCTest
@testable import SwiftLevelDB

final class ArrayTests: TestsBase {
    
    override func asyncSetup() async {
        await super.asyncSetup()
    }
    
    override func asyncTearDown() async {
        await super.asyncTearDown()
    }
    
    func isOddNumber(_ number: Int) async -> Bool {
        return number % 2 == 1
    }
    
    func testAsyncFilter() async {
        let numbers = [1, 4, 10, 3, 2, 7, 9]
        let oddNumbers = await numbers.asyncFilter { number in
            return await isOddNumber(number)
        }
        XCTAssertEqual(oddNumbers.count, 4)
    }
    
    func getStringFrom(number: Int) async -> String? {
        if number > 0 {
            return "\(number)"
        } else {
            return nil
        }
    }
    
    func testAsyncCompactMap() async {
        let numbers = [1, 4, 10, 3, -2, 7, 9]
        let stringNumbers: [String] = await numbers.asyncCompactMap { number in
            return await getStringFrom(number: number)
        }
        XCTAssertEqual(stringNumbers.count, 6)
        XCTAssertEqual(stringNumbers[0], "1")
    }
    
    func testInsertionSort() async {
        var numbers = [1, 4, 10, 3, -2, 7, 9]
        print(numbers)
        await numbers.insertionSort { $0 < $1 }
        XCTAssertEqual(numbers[0], -2)
        XCTAssertEqual(numbers[1], 1)
        print(numbers)
        await numbers.insertionSort { $0 > $1 }
        print(numbers)
        XCTAssertEqual(numbers[0], 10)
        XCTAssertEqual(numbers[1], 9)
    }
}
