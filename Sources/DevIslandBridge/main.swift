import Foundation
import DevIslandCore
import Darwin

// This observer must never decide permissions, print JSON, or block Claude on a failure.
if CommandLine.arguments.contains("--version") {
    print("Dev Island Bridge 0.3.0")
    exit(0)
}
if CommandLine.arguments.contains("--claude-hook") {
    let deadline = DispatchWorkItem { exit(0) }
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.8, execute: deadline)
    do {
        // Bounded streaming read: plans may be large, but are never required by this observer.
        var data = Data()
        while let chunk = try FileHandle.standardInput.read(upToCount: 65536), !chunk.isEmpty {
            data.append(chunk)
            if data.count > 2 * 1024 * 1024 { exit(0) }
        }
        if let event = try ClaudeAdapter.decode(data, source: ProcessIdentity.discoverSource()) {
            try EventQueue.enqueue(event, paths: .init())
        }
    } catch { /* Fail open, including malformed input and an unavailable application. */ }
    deadline.cancel()
}
exit(0)
