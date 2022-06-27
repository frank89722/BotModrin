//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/27.
//

import Foundation

extension String {

    private static let dateFormatLong: DateFormatter = {
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US")
        dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        return dateFormat
    }()

    
    private static let dateFormatShort: DateFormatter = {
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US")
        dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormat
    }()

    
    private static let dateFormatHTTP: DateFormatter = {
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US")
        dateFormat.dateFormat = "E, dd MMM yyyy HH:mm:ss zzzz"
        return dateFormat
    }()

    
    var date: Date {
        if let returnDate = String.dateFormatLong.date(from: self) {
            return returnDate
        } else {
            return String.dateFormatShort.date(from: self)!
        }
    }

    
    var httpDate: Date {
        return String.dateFormatHTTP.date(from: self)!
    }

}
