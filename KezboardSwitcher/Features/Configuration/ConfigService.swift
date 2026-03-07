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
            return []
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
