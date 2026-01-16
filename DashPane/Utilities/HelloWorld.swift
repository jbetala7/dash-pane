//
//  HelloWorld.swift
//  DashPane
//
//  Created for workflow testing purposes.
//  This file can be safely deleted after verification.
//

import Foundation

/// A simple hello world utility for testing the ticket-agent workflow.
///
/// This struct provides a basic greeting function used to verify
/// the complete development workflow from ticket creation to PR.
struct HelloWorld {

    /// Returns a friendly "Hello, World!" greeting message.
    ///
    /// - Returns: A string containing the classic "Hello, World!" message.
    ///
    /// Example usage:
    /// ```swift
    /// let greeting = HelloWorld.greet()
    /// print(greeting) // Prints: "Hello, World!"
    /// ```
    static func greet() -> String {
        return "Hello, World!"
    }

    /// Returns a personalized greeting message.
    ///
    /// - Parameter name: The name of the person to greet.
    /// - Returns: A personalized greeting string.
    ///
    /// Example usage:
    /// ```swift
    /// let greeting = HelloWorld.greet(name: "DashPane")
    /// print(greeting) // Prints: "Hello, DashPane!"
    /// ```
    static func greet(name: String) -> String {
        return "Hello, \(name)!"
    }
}
