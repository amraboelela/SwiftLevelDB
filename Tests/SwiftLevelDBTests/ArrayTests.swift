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
    
    func testAsyncRemoveAll() async {
        let numbers = [1, 4, 10, 3, 2, 7, 9]
        let evenNumbers = await numbers.asyncRemoveAll { number in
            return await isOddNumber(number)
        }
        XCTAssertEqual(evenNumbers.count, 3)
        XCTAssertEqual(evenNumbers[0], 4)
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
}
