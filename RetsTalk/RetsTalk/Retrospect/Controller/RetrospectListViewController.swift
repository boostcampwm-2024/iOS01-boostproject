//
//  RetrospectListViewController.swift
//  RetsTalk
//
//  Created by KimMinSeok on 11/18/24.
//

import Combine
import SwiftUI
import UIKit

final class RetrospectListViewController: BaseViewController {
    typealias Situation = RetrospectListSituation
    private typealias RetrospectDataSource = UITableViewDiffableDataSource<RetrospectSection, Retrospect>
    
    private let retrospectManager: RetrospectManageable
    private let userDefaultsManager: UserDefaultsManager
    private let userSettingManager: UserSettingManager

    private var subscriptionSet: Set<AnyCancellable>
    private var retrospectsSubject: CurrentValueSubject<SortedRetrospects, Never>
    private let errorSubject: CurrentValueSubject<Error?, Never>
    
    private var dataSource: RetrospectDataSource?

    // MARK: UI Components
    
    private let retrospectListView: RetrospectListView
    
    // MARK: Init Method
    
    init(
        retrospectManager: RetrospectManageable,
        userDefaultsManager: UserDefaultsManager
    ) {
        self.retrospectManager = retrospectManager
        self.userDefaultsManager = userDefaultsManager
        userSettingManager = UserSettingManager(userDataStorage: userDefaultsManager)

        retrospectListView = RetrospectListView()
        retrospectsSubject = CurrentValueSubject(SortedRetrospects())
        errorSubject = CurrentValueSubject(nil)
        subscriptionSet = []
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    // MARK: ViewController lifecycle method
    
    override func loadView() {
        view = retrospectListView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        addObserver()
        subscribeRetrospects()
        retrospectListView.setTableViewDelegate(self)
        setUpDataSource()
        addCreateButtondidTapAction()
        fetchInitialRetrospect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sortAndSendRetrospects()
    }
    
    // MARK: RetsTalk lifecycle method
    
    override func setupNavigationBar() {
        title = Texts.navigationTitle
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: Texts.settingButtonImageName),
            style: .plain,
            target: self,
            action: #selector(didTapSettings)
        )
        
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItem = settingsButton
        navigationItem.rightBarButtonItem?.tintColor = .black
    }

    // MARK: Regarding iCloud

    private func addObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refetchRetrospects),
            name: .coreDataImportedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(regenerateAndReplaceCoreDataManager),
            name: .iCloudSyncStateChangeNotification,
            object: nil
        )
    }

    @objc private func refetchRetrospects() {
        fetchInitialRetrospect()
    }

    @objc private func regenerateAndReplaceCoreDataManager() {
        let userData = userSettingManager.userData
        let isCloudSyncOn = userData.isCloudSyncOn
        let newCoreDataManager = CoreDataManager(
            isiCloudSynced: isCloudSyncOn,
            name: Constants.Texts.CoreDataContainerName) { _ in }
        Task {
            await retrospectManager.replaceRetrospectStorage(newCoreDataManager)
        }
    }

    // MARK: Retrospect handling
    
    private func subscribeRetrospects() {
        retrospectsSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                
                self.updateSnapshot()
                self.updateRetrospectCount()
            }
            .store(in: &subscriptionSet)
    }
    
    private func updateRetrospectCount() {
        retrospectListView.updateButtonSubtitle(
            datesCount: retrospectsSubject.value.datesCount,
            totalRetrospectCount: retrospectsSubject.value.totalCount
        )
    }
    
    private func fetchInitialRetrospect() {
        Task {
            await retrospectManager.fetchRetrospects(of: [.pinned, .inProgress, .finished])
            sortAndSendRetrospects()
        }
    }
    
    private func sortAndSendRetrospects() {
        Task {
            let sortedRetrospects = RetrospectSortingHelper.execute(await retrospectManager.retrospects)
            retrospectsSubject.send(sortedRetrospects)
        }
    }
    
    private func deleteRetrospect(_ retrospect: Retrospect) {
        presentAlert(
            for: .delete,
            actions: [
                UIAlertAction(title: "취소", style: .cancel),
                UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
                    guard let self else { return }

                    Task {
                        await self.retrospectManager.deleteRetrospect(retrospect)
                        self.sortAndSendRetrospects()
                    }
                },
            ]
        )
    }
    
    private func togglepPinRetrospect(_ retrospect: Retrospect) {
        Task {
            await self.retrospectManager.togglePinRetrospect(retrospect)
            self.sortAndSendRetrospects()
        }
    }
    
    // MARK: Action controls

    @objc private func didTapSettings() {
        let notificationManager = NotificationManager()
        let userSettingViewController = UserSettingViewController(
            userSettingManager: userSettingManager,
            notificationManager: notificationManager
        )
        navigationController?.pushViewController(userSettingViewController, animated: true)
    }
    
    private func addCreateButtondidTapAction() {
        retrospectListView.addCreateButtonAction(
            UIAction(
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    
                    Task {
                        guard let retrospectChatManager = await retrospectManager.createRetrospect() else { return }
                        
                        let retrospectChatViewController = await RetrospectChatViewController(
                            retrospect: retrospectChatManager.retrospect,
                            retrospectChatManager: retrospectChatManager
                        )
                        navigationController?.pushViewController(retrospectChatViewController, animated: true)
                    }
                })
        )
    }
}

// MARK: - UITableViewDiffableDataSource method

private extension RetrospectListViewController {
    func setUpDataSource() {
        dataSource = RetrospectDataSource(
            tableView: retrospectListView.retrospectListTableView
        ) { tableView, indexPath, retrospect in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: Constants.Texts.retrospectCellIdentifier,
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentConfiguration = UIHostingConfiguration {
                RetrospectCell(
                    summary: retrospect.summary ?? Texts.defaultSummaryText,
                    createdAt: retrospect.createdAt,
                    isPinned: retrospect.isPinned
                )
            }
            .margins(.vertical, Metrics.cellVerticalMargin)
            return cell
        }
    }
    
    func updateSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<RetrospectSection, Retrospect>()
        let sortedRetrospects = retrospectsSubject.value
        for (index, sectionTitle) in RetrospectSection.allCases.enumerated() {
            let retrospects = sortedRetrospects[index]
            if !retrospects.isEmpty {
                snapshot.appendSections([sectionTitle])
                snapshot.appendItems(retrospects, toSection: sectionTitle)
            }
        }
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UITableViewDelegate conformance

extension RetrospectListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sections = dataSource?.snapshot().sectionIdentifiers
        let headerView = SectionHeaderView(title: sections?[section].title)
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Metrics.tableViewHeaderHeight
    }
    
    // MARK: SelectRow handling
    
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        guard let sections = dataSource?.snapshot().sectionIdentifiers.map({ $0.rawValue }) else { return }
        
        let section = sections[indexPath.section]
        let retrospect = retrospectsSubject.value[section][indexPath.row]
        Task {
            guard let retrospectChatManager = await retrospectManager.retrospectChatManager(of: retrospect)
            else { return }
            
            let chattingViewController = RetrospectChatViewController(
                retrospect: retrospect,
                retrospectChatManager: retrospectChatManager
            )
            navigationController?.pushViewController(chattingViewController, animated: true)
        }
    }
    
    // MARK: SwipeAction handling
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let sections = dataSource?.snapshot().sectionIdentifiers.map({ $0.rawValue }) else { return nil }
        
        let section = sections[indexPath.section]
        let selectedRetrospect = retrospectsSubject.value[section][indexPath.row]
        let configuration = UISwipeActionsConfiguration(actions: retrospectSwipeAction(selectedRetrospect))
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    private func retrospectSwipeAction(_ retrospect: Retrospect) -> [UIContextualAction] {
        let deleteAction = UIContextualAction.actionWithSystemImage(
            named: Texts.deleteIconImageName,
            tintColor: .red,
            action: { [weak self] in
                self?.deleteRetrospect(retrospect)
            },
            completionHandler: { _ in }
        )
        guard retrospect.status == .finished else { return [deleteAction] }
        
        let pinAction = pinAction(by: retrospect)
        return [deleteAction, pinAction]
    }
    
    private func pinAction(by retrospect: Retrospect) -> UIContextualAction {
        let pinToggleAction = { [weak self] in
            guard let self = self else { return }
            
            self.togglepPinRetrospect(retrospect)
        }
        
        let pinAction = UIContextualAction.actionWithSystemImage(
            named: Texts.pinIconImageName,
            tintColor: .blazingOrange,
            action: pinToggleAction,
            completionHandler: { _ in }
        )
        let unpinAction = UIContextualAction.actionWithSystemImage(
            named: Texts.unpinIconImageName,
            tintColor: .blazingOrange,
            action: pinToggleAction,
            completionHandler: { _ in }
        )
        
        return retrospect.isPinned ? unpinAction : pinAction
    }
}

// MARK: - AlertPresentable conformance

extension RetrospectListViewController: AlertPresentable {
    enum RetrospectListSituation: AlertSituation {
        case delete
        
        var title: String {
            switch self {
            case .delete:
                "회고를 삭제하시겠습니까?"
            }
        }
        
        var message: String {
            switch self {
            case .delete:
                "삭제된 회고는 복구할 수 없습니다."
            }
        }
    }
}

// MARK: - Constants

private extension RetrospectListViewController {
    enum RetrospectSection: Int, CaseIterable, Hashable {
        case pinned
        case inProgress
        case finished
        
        var title: String {
            switch self {
            case .pinned:
                "고정됨"
            case .inProgress:
                "진행 중인 회고"
            case .finished:
                "지난 날의 회고"
            }
        }
    }
    
    enum Metrics {
        static let cellVerticalMargin = 6.0
        static let tableViewHeaderHeight = 36.0
    }
    
    enum Texts {
        static let settingButtonImageName = "gearshape"
        static let deleteIconImageName = "trash.fill"
        static let pinIconImageName = "pin.fill"
        static let unpinIconImageName = "pin.slash.fill"
        
        static let navigationTitle = "회고"
        static let defaultSummaryText = "대화를 종료해 요약을 확인하세요"
    }
}
