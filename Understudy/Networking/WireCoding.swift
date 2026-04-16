//
//  WireCoding.swift
//  Understudy
//
//  Shared JSON encoder/decoder for all wire messages. Uses ISO-8601 dates so
//  non-Apple clients (Android) can parse them without custom logic.
//

import Foundation

public enum WireCoding {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
