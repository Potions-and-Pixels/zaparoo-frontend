// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett

#include "Config.h"
#include "Logger.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QTemporaryDir>
#include <QTest>

using namespace zaparoo;

// NOLINTBEGIN(readability-convert-member-functions-to-static)
class TstLogger : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    QString m_logPath;

    QList<QJsonObject> readLines()
    {
        QFile f(m_logPath);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        {
            return {};
        }
        QList<QJsonObject> out;
        while (!f.atEnd())
        {
            const QByteArray line = f.readLine();
            if (line.trimmed().isEmpty())
            {
                continue;
            }
            QJsonParseError err{};
            const auto doc = QJsonDocument::fromJson(line, &err);
            if (err.error != QJsonParseError::NoError)
            {
                continue;
            }
            out.append(doc.object());
        }
        return out;
    }

  private slots:
    void init()
    {
        QVERIFY(m_dir.isValid());
        m_logPath = m_dir.filePath("launcher.log");
        QFile::remove(m_logPath);
        QFile::remove(m_logPath + QStringLiteral(".1"));
        QFile::remove(m_logPath + QStringLiteral(".2"));
        qunsetenv("ZAPAROO_DEBUG");
        Logger::installAt(m_logPath);
    }

    void cleanup()
    {
        Logger::shutdownForTests();
    }

    void writes_jsonl_line_with_expected_fields()
    {
        qCInfo(zapCore) << "hello from test";
        const auto lines = readLines();
        QCOMPARE(lines.size(), 1);
        const auto& o = lines.first();
        QCOMPARE(o.value("level").toString(), QStringLiteral("info"));
        QCOMPARE(o.value("category").toString(), QStringLiteral("zap.core"));
        QVERIFY(o.value("message").toString().contains("hello from test"));
        QVERIFY(o.contains("time"));
        const auto t = o.value("time").toString();
        static const QRegularExpression re(R"(^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$)");
        QVERIFY(re.match(t).hasMatch());
    }

    void level_mapping()
    {
        qCInfo(zapCore) << "i";
        qCWarning(zapCore) << "w";
        qCCritical(zapCore) << "e";
        const auto lines = readLines();
        QCOMPARE(lines.size(), 3);
        QCOMPARE(lines[0].value("level").toString(), QStringLiteral("info"));
        QCOMPARE(lines[1].value("level").toString(), QStringLiteral("warn"));
        QCOMPARE(lines[2].value("level").toString(), QStringLiteral("error"));
    }

    void debug_filtered_by_default()
    {
        qCDebug(zapCore) << "noisy";
        QCOMPARE(readLines().size(), 0);
    }

    void debug_enabled_via_applyConfig()
    {
        Config c;
        c.debugLogging = true;
        Logger::applyConfig(c);
        qCDebug(zapCore) << "noisy";
        const auto lines = readLines();
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines.first().value("level").toString(), QStringLiteral("debug"));
    }

    void debug_disabled_after_applyConfig()
    {
        Config c;
        c.debugLogging = true;
        Logger::applyConfig(c);
        qCDebug(zapCore) << "on";
        QCOMPARE(readLines().size(), 1);

        c.debugLogging = false;
        Logger::applyConfig(c);
        qCDebug(zapCore) << "off";
        QCOMPARE(readLines().size(), 1);
    }

    void env_var_wins_over_config_false()
    {
        Logger::shutdownForTests();
        qputenv("ZAPAROO_DEBUG", "1");
        Logger::installAt(m_logPath);
        Config c;
        c.debugLogging = false;
        Logger::applyConfig(c);
        qCDebug(zapCore) << "env-wins";
        const auto lines = readLines();
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines.first().value("level").toString(), QStringLiteral("debug"));
    }

    void debug_enabled_via_env_var()
    {
        Logger::shutdownForTests();
        qputenv("ZAPAROO_DEBUG", "1");
        Logger::installAt(m_logPath);
        qCDebug(zapCore) << "env-debug";
        const auto lines = readLines();
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines.first().value("level").toString(), QStringLiteral("debug"));
    }

    void unwritable_path_falls_back_to_stderr_only()
    {
        Logger::shutdownForTests();
        const QString roDir = m_dir.filePath("readonly");
        QDir().mkdir(roDir);
        QFile::setPermissions(roDir, QFileDevice::ReadOwner | QFileDevice::ExeOwner);
        const QString badPath = roDir + QStringLiteral("/launcher.log");
        Logger::installAt(badPath);
        qCInfo(zapCore) << "still alive";
        QVERIFY(!QFile::exists(badPath));
        QFile::setPermissions(roDir, QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                                         QFileDevice::ExeOwner);
    }

    void bare_qwarning_uses_default_category()
    {
        qWarning() << "bare-warn";
        bool found = false;
        for (const auto& o : readLines())
        {
            if (o.value("category").toString() == QLatin1String("default") &&
                o.value("message").toString().contains(QLatin1String("bare-warn")))
            {
                found = true;
            }
        }
        QVERIFY(found);
    }

    void rotation_triggers_at_threshold()
    {
        // 64 KB payload × 20 lines ≈ 1.28 MB; rotation fires after the first
        // line that pushes the file over 1 MB.
        const QString big(qsizetype{64} * 1024, QLatin1Char('x'));
        for (int i = 0; i < 20; ++i)
        {
            qCInfo(zapCore).noquote() << big;
        }
        QVERIFY(QFile::exists(m_logPath));
        QVERIFY(QFile::exists(m_logPath + QStringLiteral(".1")));
        QVERIFY(QFileInfo(m_logPath + QStringLiteral(".1")).size() > 0);
    }

    void rotation_keeps_at_most_two_backups()
    {
        const QString big(qsizetype{64} * 1024, QLatin1Char('x'));
        for (int i = 0; i < 60; ++i)
        {
            qCInfo(zapCore).noquote() << big;
        }
        QVERIFY(QFile::exists(m_logPath));
        QVERIFY(QFile::exists(m_logPath + QStringLiteral(".1")));
        QVERIFY(QFile::exists(m_logPath + QStringLiteral(".2")));
        QVERIFY(!QFile::exists(m_logPath + QStringLiteral(".3")));
    }

    void embedded_newlines_preserved()
    {
        qCInfo(zapCore).noquote() << "line1\nline2";
        const auto lines = readLines();
        QCOMPARE(lines.size(), 1);
        QVERIFY(lines.first().value("message").toString().contains('\n'));
    }

    void file_and_line_fields_basenamed()
    {
        qCInfo(zapCore) << "x";
        const auto lines = readLines();
        QCOMPARE(lines.size(), 1);
        const auto file = lines.first().value("file").toString();
        QVERIFY(!file.contains('/'));
        QVERIFY(file.endsWith(QStringLiteral(".cpp")));
        QVERIFY(lines.first().value("line").toInt() > 0);
    }
};
// NOLINTEND(readability-convert-member-functions-to-static)

QTEST_GUILESS_MAIN(TstLogger)
#include "tst_logger.moc"
