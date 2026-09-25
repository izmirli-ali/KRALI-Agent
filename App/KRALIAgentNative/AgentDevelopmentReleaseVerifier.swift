import Foundation

struct AgentDevelopmentReleaseVerifier {
    private let fileManager =
        FileManager.default

    private var repositoryURL: URL {
        fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Developer/KRALI-Agent",
                isDirectory: true
            )
    }

    func candidateIsIntegrated(
        branch candidateBranch: String,
        currentSourceRevision: String?
    ) -> Bool {
        guard
            let currentRevision =
                exactRevision(
                    currentSourceRevision
                ),
            let safeBranch =
                safeCandidateBranch(
                    candidateBranch
                ),
            fileManager
                .fileExists(
                    atPath:
                        repositoryURL.path
                )
        else {
            return false
        }

        guard
            let candidateRevision =
                resolveCandidateRevision(
                    branch: safeBranch
                )
        else {
            return false
        }

        return gitExitStatus(
            arguments: [
                "-C",
                repositoryURL.path,
                "merge-base",
                "--is-ancestor",
                candidateRevision,
                currentRevision
            ]
        ) == 0
    }

    private func resolveCandidateRevision(
        branch: String
    ) -> String? {
        let refs = [
            branch,
            "refs/heads/" + branch,
            "refs/remotes/origin/" +
                branch
        ]

        for ref in refs {
            guard
                let output =
                    gitOutput(
                        arguments: [
                            "-C",
                            repositoryURL.path,
                            "rev-parse",
                            "--verify",
                            ref + "^{commit}"
                        ]
                    ),
                let revision =
                    exactRevision(
                        output
                    )
            else {
                continue
            }

            return revision
        }

        return nil
    }

    private func safeCandidateBranch(
        _ raw: String
    ) -> String? {
        let branch =
            raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            branch.hasPrefix(
                "krali-dev-agent/"
            ),
            branch.count <= 120,
            !branch.contains(".."),
            !branch.contains("@{"),
            !branch.hasSuffix("."),
            !branch.hasSuffix("/")
        else {
            return nil
        }

        let allowed =
            CharacterSet(
                charactersIn:
                    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/-"
            )

        guard
            branch.unicodeScalars
                .allSatisfy({
                    allowed.contains($0)
                })
        else {
            return nil
        }

        return branch
    }

    private func exactRevision(
        _ raw: String?
    ) -> String? {
        guard let raw else {
            return nil
        }

        let value =
            raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard value.count == 40 else {
            return nil
        }

        let allowed =
            CharacterSet(
                charactersIn:
                    "0123456789abcdef"
            )

        guard
            value.unicodeScalars
                .allSatisfy({
                    allowed.contains($0)
                })
        else {
            return nil
        }

        return value
    }

    private func gitOutput(
        arguments: [String]
    ) -> String? {
        let process = Process()
        process.executableURL =
            URL(
                fileURLWithPath:
                    "/usr/bin/git"
            )
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError =
            FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard
                process.terminationStatus == 0
            else {
                return nil
            }

            let data =
                pipe.fileHandleForReading
                    .readDataToEndOfFile()

            return String(
                data: data,
                encoding: .utf8
            )
        } catch {
            return nil
        }
    }

    private func gitExitStatus(
        arguments: [String]
    ) -> Int32 {
        let process = Process()
        process.executableURL =
            URL(
                fileURLWithPath:
                    "/usr/bin/git"
            )
        process.arguments = arguments
        process.standardOutput =
            FileHandle.nullDevice
        process.standardError =
            FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
