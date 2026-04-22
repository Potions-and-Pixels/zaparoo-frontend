// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

#include "PlatformPaths.h"

#include <QDir>
#include <QStandardPaths>

namespace zaparoo
{

bool PlatformPaths::isMiSTer()
{
    return QDir("/media/fat").exists();
}

QString PlatformPaths::configFilePath()
{
    if (isMiSTer())
    {
        return QStringLiteral("/media/fat/zaparoo/launcher.toml");
    }
    const QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    return configDir + QStringLiteral("/launcher.toml");
}

QString PlatformPaths::cacheDir()
{
    if (isMiSTer())
    {
        return QStringLiteral("/media/fat/zaparoo/cache");
    }
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
}

QString PlatformPaths::logFilePath()
{
    if (isMiSTer())
    {
        return QStringLiteral("/tmp/zaparoo/launcher.log");
    }
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    return dataDir + QStringLiteral("/zaparoo/logs/launcher.log");
}

} // namespace zaparoo
