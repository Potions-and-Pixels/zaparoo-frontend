// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

#include "Logger.h"

#include "Config.h"
#include "PlatformPaths.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QMutexLocker>
#include <QtGlobal>
#include <cstdio>
#include <memory>

Q_LOGGING_CATEGORY(zapApp, "zap.app")
Q_LOGGING_CATEGORY(zapCore, "zap.core")
Q_LOGGING_CATEGORY(zapNet, "zap.net")

namespace zaparoo
{

namespace
{

constexpr qint64 kRotateBytes = 1LL * 1024 * 1024;

struct LogState
{
    QMutex m_mutex;
    std::unique_ptr<QFile> m_logFile;
    QString m_basePath;
    bool m_operational{false};
    bool m_envDebug{false};
    bool m_warned{false};
};

LogState& state()
{
    static LogState s;
    return s;
}

const char* levelString(QtMsgType type)
{
    switch (type)
    {
    case QtDebugMsg:
        return "debug";
    case QtInfoMsg:
        return "info";
    case QtWarningMsg:
        return "warn";
    case QtCriticalMsg:
        return "error";
    case QtFatalMsg:
        return "fatal";
    }
    return "unknown";
}

char levelChar(QtMsgType type)
{
    switch (type)
    {
    case QtDebugMsg:
        return 'D';
    case QtInfoMsg:
        return 'I';
    case QtWarningMsg:
        return 'W';
    case QtCriticalMsg:
        return 'E';
    case QtFatalMsg:
        return 'F';
    }
    return '?';
}

bool parseEnvDebug()
{
    const QByteArray val = qgetenv("ZAPAROO_DEBUG");
    return !val.isEmpty() && val != "0" && val != "false";
}

void applyFilterRules(bool debug)
{
    const QLatin1StringView rules = debug
                                        ? QLatin1StringView("zap.*.debug=true\nzap.*.info=true\n")
                                        : QLatin1StringView("zap.*.debug=false\nzap.*.info=true\n");
    QLoggingCategory::setFilterRules(rules);
}

// Local time for human readability on stderr; JSONL uses UTC (buildJsonLine).
QByteArray buildHumanLine(QtMsgType type, const QString& msg)
{
    const QString timestamp = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");
    return QStringLiteral("[%1 %2] %3\n")
        .arg(timestamp)
        .arg(QLatin1Char(levelChar(type)))
        .arg(msg)
        .toLocal8Bit();
}

QByteArray buildJsonLine(QtMsgType type, const QMessageLogContext& ctx, const QString& msg)
{
    const QString time = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    const QString category =
        ctx.category != nullptr ? QString::fromLatin1(ctx.category) : QStringLiteral("default");

    QJsonObject obj;
    obj[QStringLiteral("time")] = time;
    obj[QStringLiteral("level")] = QString::fromLatin1(levelString(type));
    obj[QStringLiteral("category")] = category;
    obj[QStringLiteral("message")] = msg;
    if (ctx.file != nullptr)
    {
        obj[QStringLiteral("file")] = QFileInfo(QString::fromLatin1(ctx.file)).fileName();
    }
    if (ctx.line != 0)
    {
        obj[QStringLiteral("line")] = ctx.line;
    }

    return QJsonDocument(obj).toJson(QJsonDocument::Compact) + '\n';
}

void openLogFileLocked(LogState& s, const QString& path)
{
    s.m_basePath = path;
    QDir().mkpath(QFileInfo(path).absolutePath());
    s.m_logFile = std::make_unique<QFile>(path);
    if (!s.m_logFile->open(QIODevice::WriteOnly | QIODevice::Append))
    {
        if (!s.m_warned)
        {
            std::fprintf(stderr,
                         "[launcher] logger: cannot open '%s' (%s); file logging disabled\n",
                         path.toLocal8Bit().constData(),
                         s.m_logFile->errorString().toLocal8Bit().constData());
            s.m_warned = true;
        }
        s.m_logFile = nullptr;
        s.m_basePath.clear();
        s.m_operational = false;
        return;
    }
    s.m_operational = true;
}

void rotateLocked(LogState& s)
{
    const QString path = s.m_basePath;
    s.m_logFile->close();
    QFile::remove(path + QStringLiteral(".2"));
    QFile::rename(path + QStringLiteral(".1"), path + QStringLiteral(".2"));
    QFile::rename(path, path + QStringLiteral(".1"));
    openLogFileLocked(s, path);
}

void messageHandler(QtMsgType type, const QMessageLogContext& ctx, const QString& msg)
{
    const QByteArray humanLine = buildHumanLine(type, msg);
    const QByteArray jsonLine = buildJsonLine(type, ctx, msg);

    {
        QMutexLocker lock(&state().m_mutex);
        std::fwrite(humanLine.constData(), 1, static_cast<size_t>(humanLine.size()), stderr);
        if (state().m_operational)
        {
            state().m_logFile->write(jsonLine);
            state().m_logFile->flush();
            if (state().m_logFile->size() >= kRotateBytes)
            {
                rotateLocked(state());
            }
        }
    }

    if (type == QtFatalMsg)
    {
        abort();
    }
}

// Must be called from the main thread before any other threads exist.
void installImpl(const QString& logPath)
{
    state().m_envDebug = parseEnvDebug();
    applyFilterRules(state().m_envDebug);
    {
        QMutexLocker lock(&state().m_mutex);
        openLogFileLocked(state(), logPath);
    }
    qInstallMessageHandler(messageHandler);
}

} // namespace

void Logger::install()
{
    installImpl(PlatformPaths::logFilePath());
}

// Must be called from the main thread before any other threads exist.
void Logger::applyConfig(const Config& config)
{
    applyFilterRules(state().m_envDebug || config.debugLogging);
}

void Logger::installAt(const QString& logFilePath)
{
    installImpl(logFilePath);
}

void Logger::shutdownForTests()
{
    qInstallMessageHandler(nullptr);
    QMutexLocker lock(&state().m_mutex);
    state().m_logFile = nullptr;
    state().m_basePath.clear();
    state().m_operational = false;
    state().m_envDebug = false;
    state().m_warned = false;
}

} // namespace zaparoo
