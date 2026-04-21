// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0
// SPDX-FileCopyrightText: 2026 Callan Barrett
#pragma once

#include "MediaTypes.h"
#include "ZaparooClient.h"

#include <QAbstractListModel>
#include <QQmlEngine>
#include <optional>

namespace zaparoo
{

// QAbstractListModel exposing one folder level of media.browse results.
// Navigation state is a stack of {path, selectedIndex} frames; enter()/goBack()
// push/pop the stack and fire async browse requests.
class BrowseModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentPathChanged)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY canGoBackChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

  public:
    enum Roles : int // NOLINT(performance-enum-size,cppcoreguidelines-use-enum-class)
    {
        NameRole = Qt::UserRole + 1,
        PathRole,
        TypeRole,
        FileCountRole,
        IsFolderRole
    };
    Q_ENUM(Roles)

    explicit BrowseModel(ZaparooClient* client, QObject* parent = nullptr);

    [[nodiscard]] int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    [[nodiscard]] QVariant data(const QModelIndex& index,
                                int role = Qt::DisplayRole) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

    // QML_SINGLETON factory — returns the instance set by setInstance() before engine loads.
    // PRE: setInstance() must be called before the first QML engine is constructed, or create()
    // will Q_ASSERT_X (debug) / null-deref (release).
    static BrowseModel* create(QQmlEngine* qmlEngine, QJSEngine* jsEngine);
    static void setInstance(BrowseModel* instance);

    [[nodiscard]] QString currentPath() const;
    [[nodiscard]] bool canGoBack() const;
    [[nodiscard]] bool loading() const;
    [[nodiscard]] QString errorMessage() const;

    Q_INVOKABLE void enter(int index);
    Q_INVOKABLE void goBack();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void launchAt(int index);
    Q_INVOKABLE void setSelectedIndex(int index);
    Q_INVOKABLE [[nodiscard]] QString nameAt(int index) const;
    Q_INVOKABLE [[nodiscard]] bool isFolderAt(int index) const;

  signals:
    void currentPathChanged();
    void canGoBackChanged();
    void loadingChanged();
    void errorMessageChanged();
    void countChanged();
    void indexRestored(int newIndex);

  private:
    struct Frame
    {
        QString path;
        int selectedIndex{0};
    };

    void browse(const QString& path, int restoreIndex = -1,
                const std::optional<Frame>& pushOnSuccess = std::nullopt);
    void setLoadingState(bool loading);
    void setErrorMessageState(const QString& msg);

    ZaparooClient* m_client;
    QVector<BrowseEntry> m_entries;
    QString m_currentPath;
    QVector<Frame> m_stack;
    quint64 m_seq{0};
    bool m_loading{false};
    QString m_errorMessage;
    int m_selectedIndex{0};

    static BrowseModel* s_instance; // NOLINT(cppcoreguidelines-avoid-non-const-global-variables)
};

} // namespace zaparoo
