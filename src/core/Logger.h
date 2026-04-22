// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett
#pragma once

#include <QLoggingCategory>
#include <QString>

Q_DECLARE_LOGGING_CATEGORY(zapApp)
Q_DECLARE_LOGGING_CATEGORY(zapCore)
Q_DECLARE_LOGGING_CATEGORY(zapNet)

namespace zaparoo
{

struct Config;

// Installs a dual-sink qInstallMessageHandler: human-readable lines on stderr
// and JSONL to the platform log file. Call install() once from main() before
// any Qt objects are created. Call applyConfig() once after loadConfig() to
// apply the debug-logging flag from the TOML config. ZAPAROO_DEBUG=1 env var
// enables debug output immediately at install() time.
class Logger
{
  public:
    static void install();
    static void applyConfig(const Config& config);

    // Test-only: install with an explicit log file path and restore defaults.
    static void installAt(const QString& logFilePath);
    static void shutdownForTests();

    Logger() = delete;
};

} // namespace zaparoo
