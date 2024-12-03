//
//  RetrospectChatViewController.swift
//  RetsTalk
//
//  Created by KimMinSeok on 11/13/24.
//

@preconcurrency import Combine
import SwiftUI
import UIKit

final class RetrospectChatViewController: BaseKeyBoardViewController {
    private let retrospectChatManager: RetrospectChatManageable
    
    private let retrospectSubject: CurrentValueSubject<Retrospect, Never>
    private let errorSubject: PassthroughSubject<Error, Never>
    private let chatPrependingSubject: PassthroughSubject<ScrollInfo, Never>
    
    private var previousRetrospect: Retrospect?
    private var scrollToBottomNeeded: Bool
    private var isChatPrependable: Bool
    private var isChatViewDragging: Bool
    
    // MARK: View
    
    private let chatView = ChatView()
    
    // MARK: Initialization
    
    init(retrospect: Retrospect, retrospectChatManager: RetrospectChatManageable) {
        self.retrospectChatManager = retrospectChatManager
        
        retrospectSubject = CurrentValueSubject(retrospect)
        errorSubject = PassthroughSubject()
        chatPrependingSubject = PassthroughSubject<ScrollInfo, Never>()
        
        previousRetrospect = retrospect
        scrollToBottomNeeded = true
        isChatPrependable = true
        isChatViewDragging = false
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Computed property
    
    private var retrospect: Retrospect {
        retrospectSubject.value
    }
    
    // MARK: ViewController lifecycle
    
    override func loadView() {
        view = chatView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addTapGestureOfDismissingKeyboard()
    }
    
    // MARK: RetsTalk lifecycle
    
    override func setupDelegation() {
        super.setupDelegation()
        
        chatView.setChatTableViewDelegate(self)
        chatView.delegate = self
    }
    
    override func setupDataSource() {
        super.setupDataSource()
        
        chatView.setChatTableViewDataSource(self)
    }

    override func setupNavigationBar() {
        super.setupNavigationBar()
        
        title = retrospect.createdAt.formattedToKoreanStyle
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: Texts.endChattingButtonTitle,
            style: .plain,
            target: self,
            action: #selector(endRetrospectChat)
        )
    }
    
    override func setupSubscription() {
        super.setupSubscription()
        
        subscribeRetrospectManager()
        subscribeRetrospectManagerError()
        subscribeRetrospectRendering()
        subscribeRetrospectErrorHandling()
        subscribeChatPrepending()
    }
    
    // MARK: Subscription
    
    private func subscribeRetrospectManager() {
        Task {
            await retrospectChatManager.retrospectPublisher
                .receive(on: DispatchQueue.main)
                .subscribe(retrospectSubject)
                .store(in: &subscriptionSet)
        }
    }
    
    private func subscribeRetrospectManagerError() {
        Task {
            await retrospectChatManager.errorPublisher
                .receive(on: DispatchQueue.main)
                .subscribe(errorSubject)
                .store(in: &subscriptionSet)
        }
    }
    
    private func subscribeRetrospectRendering() {
        retrospectSubject
            .dropFirst()
            .sink(receiveValue: { [weak self] retrospect in
                if retrospect.chat.isEmpty {
                    self?.requestAssistantMessage()
                }
                self?.updateDataSourceDifference(to: retrospect.chat)
                self?.previousRetrospect = retrospect
                self?.updateUI()
                
                print(self?.retrospect.status ?? "상태 없음")
            })
            .store(in: &subscriptionSet)
    }
    
    private func subscribeRetrospectErrorHandling() {
        errorSubject
            .sink(receiveValue: { error in
                print(error)
            })
            .store(in: &subscriptionSet)
    }
    
    private func subscribeChatPrepending() {
        chatPrependingSubject
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.fetchPreviousChat(isInitial: false)
            }
            .store(in: &subscriptionSet)
    }
    
    // MARK: Retrospect chat manager action
    
    private func requestAssistantMessage() {
        Task {
            await retrospectChatManager.requestAssistantMessage()
        }
    }
    
    private func fetchPreviousChat(isInitial: Bool) {
        guard isInitial || isChatPrependable else { return }
        
        Task {
            scrollToBottomNeeded = isInitial
            await retrospectChatManager.fetchPreviousMessages()
        }
    }

    @objc
    private func endRetrospectChat() {
        Task {
            await retrospectChatManager.endRetrospect()
            navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: Keyboard control
    
    override func handleKeyboardWillShowEvent(using keyboardInfo: KeyboardInfo) {
        super.handleKeyboardWillShowEvent(using: keyboardInfo)
        
        chatView.updateLayoutForKeyboard(using: keyboardInfo)
    }
    
    override func handleKeyboardWillHideEvent(using keyboardInfo: KeyboardInfo) {
        super.handleKeyboardWillHideEvent(using: keyboardInfo)
        
        chatView.updateLayoutForKeyboard(using: keyboardInfo)
    }
    
    private func addTapGestureOfDismissingKeyboard() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: UI action
    
    private func updateUI() {
        if scrollToBottomNeeded {
            chatView.scrollToBottom()
        }
        switch retrospect.status {
        case .inProgress(.waitingForUserInput):
            chatView.updateRequestInProgressState(false)
        default:
            chatView.updateRequestInProgressState(true)
        }
    }
}

// MARK: - ChatViewDelegate conformance

extension RetrospectChatViewController: ChatViewDelegate {
    func sendMessage(_ chatView: ChatView, with text: String) {
        Task {
            scrollToBottomNeeded = true
            await retrospectChatManager.sendMessage(text)
        }
    }
}

// MARK: - UITableViewDataSource conformance

extension RetrospectChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        retrospect.chat.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = retrospect.chat[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.Texts.messageCellIdentifier, for: indexPath)
        cell.contentConfiguration = UIHostingConfiguration {
            MessageCell(message: message.content, isUser: message.role == .user)
        }
        cell.backgroundColor = .clear
        return cell
    }
    
    // MARK: DataSource difference managing
    
    private func updateDataSourceDifference(to updated: [Message]) {
        let source = previousRetrospect?.chat ?? []
        var newIndexPaths = [IndexPath]()
        for (index, message) in updated.enumerated() where !source.contains(message) {
            newIndexPaths.append(IndexPath(row: index, section: 0))
        }
        chatView.insertMessages(at: newIndexPaths)
        isChatPrependable = newIndexPaths.isNotEmpty
    }
}

// MARK: - UITableViewDelegate conformance

extension RetrospectChatViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < scrollView.contentSize.height * Numerics.prependingRatio {
            if isChatPrependable && !isChatViewDragging {
                scrollView.contentOffset.y = max(Numerics.maxOffsetWhilePrepending, scrollView.contentOffset.y)
            }
            chatPrependingSubject.send(
                ScrollInfo(isDragging: isChatViewDragging, contentHeight: scrollView.contentSize.height)
            )
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isChatViewDragging = true
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        isChatViewDragging = false
    }
}

// MARK: - Prepend supporting type

fileprivate extension RetrospectChatViewController {
    struct ScrollInfo: Equatable {
        let isDragging: Bool
        let contentHeight: CGFloat
        let time: Date
        
        init(isDragging: Bool, contentHeight: CGFloat, time: Date = Date()) {
            self.isDragging = isDragging
            self.contentHeight = contentHeight
            self.time = time
        }
        
        static func == (lhs: ScrollInfo, rhs: ScrollInfo) -> Bool {
            let isDragging = lhs.isDragging || rhs.isDragging
            let isContentHeightDiffInsignificant = abs(lhs.contentHeight - rhs.contentHeight) / 100 < 0
            let isTimeDiffInsignificant = abs(lhs.time.timeIntervalSince(rhs.time)) < 0.1
            return isDragging || isContentHeightDiffInsignificant || isTimeDiffInsignificant
        }
    }
}

// MARK: - Constants

fileprivate extension RetrospectChatViewController {
    enum Numerics {
        static let prependingRatio = 0.2
        static let maxOffsetWhilePrepending = 1.0
    }
    
    enum Texts {
        static let endChattingButtonTitle = "끝내기"
    }
}
