//
//  CompressorApp.swift
//  Compressor
//
//  Created by Youssef Keram on 5/29/25.
//


import SwiftUI
import StoreKit

@main
struct ImageCompressorApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    for await result in Transaction.updates {
                        do {
                            let transaction = try checkVerified(result)
                            await transaction.finish()
                        } catch {
                            // Handle unverified transaction if needed
                        }
                    }
                }
        }
    }
}

// Helper function for verification
func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
        throw NSError(domain: "transaction", code: 0)
    case .verified(let safe):
        return safe
    }
}


