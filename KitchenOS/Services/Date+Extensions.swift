//
//  Date+Extensions.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation

extension Date {
    
    var startOfWeek: Date  {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        guard let start = calendar.date(from: components) else { return self }
        return calendar.date(byAdding: .day, value: 1, to: start) ?? self
    }
    
    var weekDays: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let start = self.startOfWeek
        return (0..<7).compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day, to: start)
        }
    }
    
    func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}
