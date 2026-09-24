import Foundation

struct AgentSelfDiagnosisEvidence: Hashable {
    let path: String
    let revision: String
    let line: Int
    let excerpt: String
    let matchedConcepts: [String]
}

struct AgentSelfDiagnosisReport: Hashable {
    let repositoryPath: String
    let repositoryRevision: String
    let repositoryVersion: String?
    let runningVersion: String
    let targetRevision: String
    let targetVersion: String?
    let workingTreeDirty: Bool
    let sourceVersionAligned: Bool
    let inspectedFiles: [String]
    let evidence: [AgentSelfDiagnosisEvidence]
    let observedFailure: String
    let proximateCause: String
    let rootCause: String
    let confidence: String
    let alternatives: [String]
    let selectedStrategy: String
    let proposal: String
    let mutationStarted: Bool
    let stopReason: String
    let limitations: [String]

    var rendered: String {
        let evidenceText = evidence.prefix(8).map {
            "- \($0.path):\($0.line) [\($0.matchedConcepts.joined(separator: ", "))]\n  \($0.excerpt)"
        }.joined(separator: "\n")

        let filesText = inspectedFiles.prefix(12).map { "- " + $0 }.joined(separator: "\n")
        let alternativesText = alternatives.enumerated().map {
            "\($0.offset + 1). \($0.element)"
        }.joined(separator: "\n")
        let limitationsText = limitations.map { "- " + $0 }.joined(separator: "\n")

        return """
        A. Failure Reconstruction
        \(observedFailure)

        B. Root Cause
        Proximate Cause: \(proximateCause)
        Architectural Root Cause: \(rootCause)
        Confidence: \(confidence)

        C. Repository / Architecture Inspected
        Repository: \(repositoryPath)
        Repository HEAD: \(repositoryRevision)
        Repository VERSION: \(repositoryVersion ?? "unknown")
        Running app VERSION: \(runningVersion)
        Historical target: \(targetVersion ?? "current") @ \(targetRevision)
        Working tree dirty: \(workingTreeDirty ? "yes" : "no")
        Version aligned with running app: \(sourceVersionAligned ? "yes" : "no")

        \(filesText)

        D. Evidence
        \(evidenceText.isEmpty ? "No bounded source evidence was found." : evidenceText)

        E. Existing Capability Assessment
        The diagnosis inspected whether public web research and source reading have direct network transports independent of GUI/browser control, and whether mission planning can chain browser workflow ahead of research.

        F. Alternatives
        \(alternativesText)

        G. Decision
        \(selectedStrategy)

        H. Development Proposal
        \(proposal)

        I. Mutation Started?
        \(mutationStarted ? "yes" : "no")

        J. Stop Reason
        \(stopReason)

        K. Remaining Limitations
        \(limitationsText)
        """
    }
}

/// Read-only self-diagnosis over KRALİ's own committed repository history.
/// It never writes files, creates branches, commits, pushes, merges, or changes
/// runtime permissions. All source evidence is read from git object data.
struct AgentSelfDiagnosisExecutor {
    private let fileManager = FileManager.default

    func diagnose(
        request: String,
        repository: AgentDeveloperRepository,
        runningVersion: String
    ) -> AgentSelfDiagnosisReport {
        let root = URL(fileURLWithPath: repository.path, isDirectory: true)
        let head = git(["rev-parse", "HEAD"], at: root)?.trimmed ?? "unknown"
        let branch = git(["rev-parse", "--abbrev-ref", "HEAD"], at: root)?.trimmed
        let status = git(["status", "--porcelain"], at: root)?.trimmed ?? ""
        let repositoryVersion = gitShow(revision: head, path: "VERSION", at: root)?.trimmed
            ?? readText(root.appendingPathComponent("VERSION"))?.trimmed

        let requestedVersions = versionTokens(in: request)
        let historicalVersion = requestedVersions.first {
            $0 != runningVersion && $0 != repositoryVersion
        } ?? requestedVersions.first { $0 != runningVersion }

        let historicalRevision = historicalVersion.flatMap {
            revision(forVersion: $0, at: root)
        }

        let targetRevision = historicalRevision ?? head
        let targetVersion = historicalRevision == nil ? repositoryVersion : historicalVersion

        let terms = diagnosisTerms(from: request)
        let candidates = rankedSourceFiles(
            revision: targetRevision,
            terms: terms,
            at: root
        )

        let evidence = candidates.prefix(12).compactMap {
            evidenceItem(
                path: $0.path,
                revision: targetRevision,
                terms: terms,
                at: root
            )
        }

        let inspectedFiles = candidates.prefix(12).map(\.path)
        let combined = inspectedFiles.compactMap {
            gitShow(revision: targetRevision, path: $0, at: root)
        }.joined(separator: "\n")

        let normalizedCombined = normalize(combined)
        let hasDirectResearchTransport =
            normalizedCombined.contains("agentwebresearchservice") &&
            normalizedCombined.contains("urlsession") &&
            normalizedCombined.contains("session.data")

        let hasDirectSourceReader =
            normalizedCombined.contains("agentwebsourcereader") &&
            normalizedCombined.contains("urlsession") &&
            normalizedCombined.contains("readsource")

        let hasBrowserWorkflowChain =
            normalizedCombined.contains("if browserworkflow") &&
            normalizedCombined.contains("capabilityid: \"browser.control\"") &&
            normalizedCombined.contains("if research") &&
            normalizedCombined.contains("capabilityid: \"research.web\"") &&
            normalizedCombined.contains("latestdatastep")

        let observedFailure =
            "The supplied failure evidence says public web research had research.web available, browser.control unavailable, an empty source/evidence result, and a task graph that placed browser control before web research."

        let proximateCause: String
        let rootCause: String
        let confidence: String

        if hasBrowserWorkflowChain && hasDirectResearchTransport {
            proximateCause =
                "The historical mission construction path classified the web target as an interactive browser workflow and advanced latestDataStep to browser.control before appending research.web, so the research step inherited the browser step as a dependency."

            rootCause =
                "Planning conflated two different capabilities: public network research/source reading and interactive GUI browser control. Feasibility was not enforced at the semantic dependency boundary, allowing an unavailable interactive capability to become a prerequisite for a capability that already had its own direct network transport."

            confidence = hasDirectSourceReader ? "HIGH" : "MEDIUM"
        } else if hasDirectResearchTransport {
            proximateCause =
                "The repository proves research.web has a direct network path, while the supplied failure graph still required browser control first."

            rootCause =
                "The failure is most consistent with a planner/dependency construction error rather than a missing browser implementation. More historical planner evidence is needed to identify the exact branch that introduced the dependency."

            confidence = "MEDIUM"
        } else {
            proximateCause =
                "The failure graph contains an unavailable prerequisite before the research step."

            rootCause =
                "The bounded repository scan did not collect enough transport/planner evidence to prove whether the dependency was semantically necessary."

            confidence = "LOW"
        }

        let alternatives = [
            "Semantic separation: classify public information retrieval as research.web/source-read by default, and select browser.control only for explicit interactive browser goals. Advantage: general and simple dependency graph. Risk: ambiguous web requests need careful intent tests. Architectural impact: mission normalization/planning. Testability: high.",
            "Feasibility repair: after mission generation, validate every dependency against the active execution profile and remove/rewire a paused or unavailable interactive prerequisite when a downstream read-only capability can independently satisfy the objective. Advantage: protects model-generated plans. Risk: unsafe rewiring if capability substitutability is guessed. Architectural impact: semantic feasibility verifier. Testability: high with graph fixtures.",
            "Research-first fallback: preserve the original plan but allow direct research.web + source reader to satisfy public-read outcomes before escalating to browser control. Advantage: minimal behavior change. Risk: leaves an unnecessarily confused plan and can hide planner defects. Architectural impact: outcome/fallback layer. Testability: medium."
        ]

        let selectedStrategy =
            "Prefer semantic separation plus an explicit feasibility/profile verifier. Do not implement browser.control merely to satisfy a dependency that public research does not inherently require."

        let proposal =
            """
            Problem: public URL research can be blocked by an interactive browser prerequisite even when research.web/source reading are independently available.
            Evidence: use the cited historical planner excerpts together with direct URLSession transports in web research/source reading.
            Root Cause: semantic capability conflation + missing dependency feasibility enforcement.
            Existing Architecture: research service, source reader, semantic mission planner/normalizer, task graph compiler, execution profile and capability-gap resolver.
            Allowed Scope: mission planning/normalization, dependency feasibility/profile validation, and behavioral tests only. Do not add computer-control authority.
            Expected Behavior: public research runs through research.web/source reader without a paused browser node; genuinely interactive browser goals remain browser-controlled and paused in Development / Research Mode.
            Verification Contract: public URL research must not be blocked by browser.control; explicit click/form/navigation intent must still select browser semantics; paused capabilities must never create fake success or learning gaps; snippets must not be claimed as read pages.
            Behavioral Benchmark: rerun the same public franchise URL research plus negative interactive-browser fixtures.
            Rollback Condition: revert if interactive browser intent is silently converted to static research or if evidence provenance weakens.
            """

        var limitations: [String] = []
        if historicalRevision == nil && historicalVersion != nil {
            limitations.append("Requested historical version \(historicalVersion!) could not be resolved from local git history; diagnosis used repository HEAD.")
        }
        if repositoryVersion != runningVersion {
            limitations.append("Repository VERSION does not match the running app VERSION; source identity is not safe for mutation decisions.")
        } else {
            limitations.append("VERSION alignment is verified, but the running app does not yet embed an exact source commit SHA; exact binary-to-commit provenance remains unproven.")
        }
        if !status.isEmpty {
            limitations.append("Developer repository working tree has local changes; evidence was intentionally read from committed git objects at \(targetRevision), not from uncommitted files.")
        }
        if evidence.isEmpty {
            limitations.append("No bounded source evidence matched strongly enough; do not promote this diagnosis to a mutation task.")
        }
        if let branch, !branch.isEmpty {
            limitations.append("Repository branch observed read-only: \(branch).")
        }

        return AgentSelfDiagnosisReport(
            repositoryPath: repository.path,
            repositoryRevision: head,
            repositoryVersion: repositoryVersion,
            runningVersion: runningVersion,
            targetRevision: targetRevision,
            targetVersion: targetVersion,
            workingTreeDirty: !status.isEmpty,
            sourceVersionAligned: repositoryVersion == runningVersion,
            inspectedFiles: inspectedFiles,
            evidence: evidence,
            observedFailure: observedFailure,
            proximateCause: proximateCause,
            rootCause: rootCause,
            confidence: confidence,
            alternatives: alternatives,
            selectedStrategy: selectedStrategy,
            proposal: proposal,
            mutationStarted: false,
            stopReason: "Read-only diagnosis is complete. A bounded registered developer task and explicit user review are still required before any mutation.",
            limitations: limitations
        )
    }

    private func rankedSourceFiles(
        revision: String,
        terms: [String],
        at root: URL
    ) -> [(path: String, score: Int)] {
        let boundedTerms = Array(terms.prefix(24))
        var arguments = ["grep", "-n", "-I", "-i"]

        for term in boundedTerms {
            arguments += ["-e", term]
        }

        arguments += [
            revision,
            "--",
            "*.swift",
            "*.mjs",
            "*.js",
            "*.command",
            "*.json",
            "*.yml",
            "*.yaml",
            "*.md"
        ]

        guard let matches = git(
            arguments,
            at: root,
            acceptedExitCodes: [0, 1]
        ) else { return [] }

        var scores: [String: Int] = [:]

        for row in matches.split(separator: "\n") {
            let parts = row.split(
                separator: ":",
                maxSplits: 3,
                omittingEmptySubsequences: false
            )

            guard parts.count >= 4 else { continue }
            let path = String(parts[1])
            guard isInspectableSource(path) else { continue }

            let line = normalize(String(parts[3]))
            var score = 1

            for term in boundedTerms where line.contains(normalize(term)) {
                score += term.contains(".") ? 4 : 1
            }

            if line.contains("research.web") { score += 6 }
            if line.contains("browser.control") { score += 6 }
            if line.contains("dependson") || line.contains("dependency") { score += 3 }
            if line.contains("urlsession") { score += 3 }
            if line.contains("capability") { score += 2 }

            scores[path, default: 0] += score
        }

        return scores.map { ($0.key, $0.value) }.sorted {
            if $0.1 == $1.1 { return $0.0 < $1.0 }
            return $0.1 > $1.1
        }
    }

    private func evidenceItem(
        path: String,
        revision: String,
        terms: [String],
        at root: URL
    ) -> AgentSelfDiagnosisEvidence? {
        guard let content = gitShow(
            revision: revision,
            path: path,
            at: root
        ) else { return nil }

        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return nil }

        var bestIndex = 0
        var bestScore = 0
        var bestMatches: [String] = []

        for (index, line) in lines.enumerated() {
            let normalizedLine = normalize(line)
            let matches = terms.filter {
                normalizedLine.contains(normalize($0))
            }
            var score = matches.count
            if normalizedLine.contains("research.web") { score += 4 }
            if normalizedLine.contains("browser.control") { score += 4 }
            if normalizedLine.contains("dependson") { score += 2 }
            if normalizedLine.contains("urlsession") { score += 2 }

            if score > bestScore {
                bestScore = score
                bestIndex = index
                bestMatches = matches
            }
        }

        guard bestScore > 0 else { return nil }

        let start = max(0, bestIndex - 4)
        let end = min(lines.count, bestIndex + 5)
        let excerpt = lines[start..<end]
            .enumerated()
            .map { offset, line in
                "\(start + offset + 1): " + line
            }
            .joined(separator: "\n")

        return AgentSelfDiagnosisEvidence(
            path: path,
            revision: revision,
            line: bestIndex + 1,
            excerpt: String(excerpt.prefix(1400)),
            matchedConcepts: Array(Set(bestMatches)).sorted()
        )
    }

    private func diagnosisTerms(from request: String) -> [String] {
        var terms: Set<String> = [
            "research.web",
            "browser.control",
            "semantic",
            "mission",
            "capability",
            "task graph",
            "dependsOn",
            "dependency",
            "execution profile",
            "URLSession",
            "source reader",
            "evidence",
            "fallback",
            "capability gap",
            "web research"
        ]

        let stop: Set<String> = [
            "icin", "için", "olan", "olarak", "bunu", "bunun", "gorev", "görev",
            "kendi", "kullanici", "kullanıcı", "sonra", "once", "önce", "yapma",
            "etme", "veya", "ile", "ama", "degil", "değil", "gereken", "gerekli"
        ]

        let rawTokens = request
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._")).inverted)
            .filter { $0.count >= 5 }

        for token in rawTokens {
            let n = normalize(token)
            if !stop.contains(n), terms.count < 32 {
                terms.insert(token)
            }
        }

        return Array(terms)
    }

    private func versionTokens(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)\bv?(\d+\.\d+\.\d+)\b"#
        ) else { return [] }

        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var values: [String] = []

        for match in regex.matches(in: text, range: range) {
            guard match.numberOfRanges > 1 else { continue }
            let value = ns.substring(with: match.range(at: 1))
            if !values.contains(value) {
                values.append(value)
            }
        }

        return values
    }

    private func revision(
        forVersion version: String,
        at root: URL
    ) -> String? {
        let focused = git(
            ["log", "--all", "-S", version, "--format=%H", "--", "VERSION"],
            at: root
        ) ?? ""

        let fallback = git(
            ["log", "--all", "--format=%H", "--", "VERSION"],
            at: root
        ) ?? ""

        var candidates: [String] = []
        for sha in (focused + "\n" + fallback)
            .split(separator: "\n")
            .map(String.init) {
            if !candidates.contains(sha) {
                candidates.append(sha)
            }
            if candidates.count >= 60 { break }
        }

        for sha in candidates {
            if gitShow(revision: sha, path: "VERSION", at: root)?.trimmed == version {
                return sha
            }
        }

        return nil
    }

    private func isInspectableSource(_ path: String) -> Bool {
        let lower = path.lowercased()

        if lower.hasPrefix(".git/") ||
           lower.contains("/.build/") ||
           lower.contains("/deriveddata/") ||
           lower.hasPrefix("mentor/history/") {
            return false
        }

        let allowed = [
            ".swift", ".mjs", ".js", ".command", ".json",
            ".yml", ".yaml", ".md"
        ]

        return allowed.contains { lower.hasSuffix($0) }
    }

    private func gitShow(
        revision: String,
        path: String,
        at root: URL
    ) -> String? {
        git(["show", revision + ":" + path], at: root)
    }

    private func git(
        _ arguments: [String],
        at root: URL,
        acceptedExitCodes: Set<Int32> = [0]
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path] + arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Drain stdout while git is running. Waiting first can deadlock on
            // large source objects when the pipe buffer fills.
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard acceptedExitCodes.contains(process.terminationStatus) else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func readText(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    private func occurrenceCount(
        of needle: String,
        in haystack: String
    ) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex

        while let range = haystack.range(
            of: needle,
            options: [],
            range: searchRange
        ) {
            count += 1
            searchRange = range.upperBound..<haystack.endIndex
            if count >= 8 { break }
        }

        return count
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "tr_TR")
            )
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
