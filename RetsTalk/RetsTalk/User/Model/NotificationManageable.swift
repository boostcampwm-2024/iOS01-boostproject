//
//  NotificationManageable.swift
//  RetsTalk
//
//  Created by HanSeung on 11/26/24.
//

import Foundation

protocol NotificationManageable: Sendable {
    func requestNotification(_ isOn: Bool, date: Date, completion: @Sendable @escaping (Bool) -> Void)
    func checkAndRequestPermission(completion: @escaping (Bool) -> Void)
    func scheduleNotification(date: Date)
    func cancelNotification()
}