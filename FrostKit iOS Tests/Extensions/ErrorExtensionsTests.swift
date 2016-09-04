//
//  ErrorExtensionsTests.swift
//  FrostKit
//
//  Created by James Barrow on 26/02/2016.
//  Copyright © 2016-Current James Barrow - Frostlight Solutions. All rights reserved.
//

import XCTest
@testable import FrostKit

class ErrorExtensionsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testErrorWithMessage() {
        
        measure {
            
            let message = "This is a test error!"
            let error = Error.error(withMessage: message)
            XCTAssert(error.localizedDescription == message)
        }
    }

}
