//
//  ConfigService.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import Foundation
import os.log

private struct ConfigFile: Codable {
    var keyboards: [Keyboard]
}

struct ConfigService {
    private let configURL: URL
    private let logger = Logger(subsystem: "de.stevio.KezboardSwitcher", category: "ConfigService")

    init(configURL: URL? = nil) {
        if let url = configURL {
            self.configURL = url
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.configURL = home
                .appendingPathComponent(".config")
                .appendingPathComponent("KezboardSwitcher")
                .appendingPathComponent("config.json")
        }
    }

    func load() -> [Keyboard] {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            logger.debug("Config file not found, returning empty list")
            return []
        }
        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(ConfigFile.self, from: data)
            logger.debug("Loaded \(config.keyboards.count) keyboard(s) from config")
            return config.keyboards
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription)")
            backUpCorruptConfig()
            return []
        }
    }

    /// Moves an unreadable config file aside to `config.json.bak` so the next
    /// save cannot silently destroy the user's data. An older backup is replaced.
    private func backUpCorruptConfig() {
        let backupURL = configURL.appendingPathExtension("bak")
        do {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.moveItem(at: configURL, to: backupURL)
            logger.error("Moved corrupt config to \(backupURL.path)")
        } catch {
            logger.error("Failed to back up corrupt config: \(error.localizedDescription)")
        }
    }

    func save(keyboards: [Keyboard]) throws {
        let dir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let config = ConfigFile(keyboards: keyboards)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
        logger.debug("Saved \(keyboards.count) keyboard(s) to config")
    }
}
