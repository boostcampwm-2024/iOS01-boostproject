//
//  RetrospectView.swift
//  RetsTalk
//
//  Created by KimMinSeok on 11/18/24.
//

import UIKit

final class RetrospectListView: UIView {
    
    // MARK: UI components
    
    private let retrospectListTableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .backgroundMain
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.Texts.retrospectCellIdentifier)
        return tableView
    }()
    private let calendarButton: RetrospectCountButton = {
        let button = RetrospectCountButton(
            imageSystemName: Texts.calendarButtonImageName,
            title: Texts.calendarButtonTitle,
            subtitle: "2일"
        )
        return button
    }()
    private let totalCountButton: RetrospectCountButton = {
        let button = RetrospectCountButton(
            imageSystemName: Texts.totalCountButtonImageName,
            title: Texts.totalCountButtonTitle,
            subtitle: "2일"
        )
        button.setImageColor(.lightGray)
        return button
    }()
    private let createRetrospectButton = CreateRetrospectButton()
    
    // MARK: Init method
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .backgroundMain
        setupTableViewLayout()
        setupFloatingButtonLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        backgroundColor = .backgroundMain
        setupFloatingButtonLayout()
        setupTableViewLayout()
    }
    
    // MARK: Custom Method
    
    private func setupTableViewLayout() {
        addSubview(retrospectListTableView)
        retrospectListTableView.translatesAutoresizingMaskIntoConstraints = false
        
        let headerView = createHeaderView()
        retrospectListTableView.tableHeaderView = headerView
        
        NSLayoutConstraint.activate([
            retrospectListTableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            retrospectListTableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            retrospectListTableView.leftAnchor.constraint(equalTo: leftAnchor),
            retrospectListTableView.rightAnchor.constraint(equalTo: rightAnchor),
        ])
    }
    
    private func setupFloatingButtonLayout() {
        addSubview(createRetrospectButton)
        
        createRetrospectButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            createRetrospectButton.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: Metrics.buttonBottomAnchorConstant
            ),
            createRetrospectButton.centerXAnchor.constraint(
                equalTo: centerXAnchor
            ),
            createRetrospectButton.widthAnchor.constraint(
                equalToConstant: Metrics.diameter
            ),
            createRetrospectButton.heightAnchor.constraint(
                equalToConstant: Metrics.diameter
            ),
        ])
        
        sendSubviewToBack(retrospectListTableView)
        bringSubviewToFront(createRetrospectButton)
    }
    
    private func createHeaderView() -> UIView {
        let headerView = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: retrospectListTableView.frame.width,
            height: Metrics.fixedButtonAreaHeight
        ))
        
        // Add buttons to the headerView
        headerView.addSubview(calendarButton)
        headerView.addSubview(totalCountButton)
        
        calendarButton.translatesAutoresizingMaskIntoConstraints = false
        totalCountButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            calendarButton.topAnchor.constraint(
                equalTo: headerView.topAnchor
            ),
            calendarButton.leadingAnchor.constraint(
                equalTo: headerView.leadingAnchor,
                constant: Metrics.calendarButtonMargin
            ),

            totalCountButton.topAnchor.constraint(
                equalTo: headerView.topAnchor
            ),
            totalCountButton.leadingAnchor.constraint(
                equalTo: headerView.centerXAnchor,
                constant: Metrics.totalCountButtonMargin
            ),
        ])
        
        return headerView
    }

    func setTableViewDelegate(_ delegate: UITableViewDelegate & UITableViewDataSource) {
        retrospectListTableView.delegate = delegate
        retrospectListTableView.dataSource = delegate
    }
    
    func addCreateButtonAction(_ action: UIAction) {
        createRetrospectButton.addAction(action, for: .touchUpInside)
    }
    
    func addCalendarButtonAction(_ action: UIAction) {
        calendarButton.addAction(action, for: .touchUpInside)
    }
    
    func reloadData() {
        retrospectListTableView.reloadData()
    }
}

// MARK: - Constants

private extension RetrospectListView {
    enum Metrics {
        static let diameter = 80.0
        static let buttonBottomAnchorConstant = -10.0
        
        static let fixedButtonAreaHeight = 40.0
        static let calendarButtonMargin = 16.0
        static let totalCountButtonMargin = 32.0
    }
    
    enum Texts {
        static let foregroundImageName = "plus"
        
        static let calendarButtonImageName = "calendar"
        static let calendarButtonTitle = "회고 쓴 일수"
        
        static let totalCountButtonImageName = "tray.full.fill"
        static let totalCountButtonTitle = "총 회고 수"
    }
}
