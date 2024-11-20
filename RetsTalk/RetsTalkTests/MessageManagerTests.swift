//
//  MessageManagerTests.swift
//  RetsTalk
//
//  Created by KimMinSeok on 11/20/24.
//

import XCTest

final class MessageManagerTests: XCTestCase {
    private var messageManager: MessageManageable?
    private var testableMessages: [Message] = [
        Message(role: .user, content: "수능 공부를 했습니다.", createdAt: Date() + 3),
        Message(role: .user, content: "오늘은 공부를 했어요", createdAt: Date() + 5),
        Message(role: .user, content: "무슨 과목을 하셨나요?", createdAt: Date() + 2),
        Message(role: .assistant, content: "오늘은 무엇을 하셨나요?", createdAt: Date() + 6),
        Message(role: .assistant, content: "무슨 공부를 하셨나요?", createdAt: Date() + 4),
        Message(role: .user, content: "Hello", createdAt: Date()),
        Message(role: .user, content: "영어를 했어요", createdAt: Date() + 1),
    ]
    
    // MARK: Set up
    
    override func setUp() {
        super.setUp()
                
        messageManager = MessageManager(
            retrospectID: UUID(),
            messageManagerListener: MockRetrospectManager(),
            persistent: MockMessageStore(messages: testableMessages)
        )
    }
    
    // MARK: Test
    
    func test_fetchMessage_메시지를_불러올_수_있는가() async throws {
        let messageManager = try XCTUnwrap(messageManager)
        
        try await messageManager.fetchMessages(offset: 0, amount: 2)
        
        XCTAssertEqual(messageManager.messages.count, 2)
    }
    
    func test_fetchMessage_많은_메시지를_불러오는가() async throws {
        let messageManager = try XCTUnwrap(messageManager)
        
        try await messageManager.fetchMessages(offset: 0, amount: 5)
        
        XCTAssertEqual(messageManager.messages.count, 5)
    }
    
    func test_fetchMessage_가지고_있는_부분보다_많은_메시지를_요청하면_최대까지만_불러오는가() async throws {
        let messageManager = try XCTUnwrap(messageManager)
        
        try await messageManager.fetchMessages(offset: 0, amount: 10)
        
        XCTAssertEqual(messageManager.messages.count, 7)
    }
    
    func test_fetchMessage_데이터를_추가로_불러올_수_있는가() async throws {
        let messageManager = try XCTUnwrap(messageManager)
        
        try await messageManager.fetchMessages(offset: 0, amount: 2)
        try await messageManager.fetchMessages(offset: 2, amount: 2)
        
        XCTAssertEqual(messageManager.messages.count, 4)
    }
    
    func test_fetchMessage_데이터를_순서대로_불러오는가() async throws {
        let messageManager = try XCTUnwrap(messageManager)
        
        try await messageManager.fetchMessages(offset: 0, amount: 2)
        
        XCTAssertEqual(messageManager.messages.first?.content, testableMessages[3].content)
        XCTAssertEqual(messageManager.messages.last?.content, testableMessages[1].content)
    }
}
