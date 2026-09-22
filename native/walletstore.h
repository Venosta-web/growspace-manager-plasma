#pragma once

#include <QObject>
#include <QString>

namespace KWallet {
class Wallet;
}

class WalletStore : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString url READ url NOTIFY credentialsChanged)
    Q_PROPERTY(QString token READ token NOTIFY credentialsChanged)
    Q_PROPERTY(bool hasCredentials READ hasCredentials NOTIFY credentialsChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY stateChanged)

public:
    explicit WalletStore(QObject *parent = nullptr);
    ~WalletStore() override;

    QString url() const;
    QString token() const;
    bool hasCredentials() const;
    bool ready() const;
    bool busy() const;
    QString errorString() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void saveCredentials(const QString &url, const QString &token);
    Q_INVOKABLE void clearCredentials();

Q_SIGNALS:
    void credentialsChanged();
    void stateChanged();
    void loadFinished(bool success);
    void saveFinished(bool success);
    void clearFinished(bool success);

private:
    enum class Operation {
        None,
        Load,
        Save,
        Clear,
    };

    void beginOperation(Operation operation);
    void ensureWallet();
    void performPendingOperation();
    void performLoad();
    void performSave();
    void performClear();
    bool ensureFolder(bool create);
    void finish(bool success);
    void setError(const QString &message);
    void clearError();

    static QString folderName();
    static QString entryName();

    KWallet::Wallet *m_wallet = nullptr;
    Operation m_pendingOperation = Operation::None;
    QString m_pendingUrl;
    QString m_pendingToken;

    QString m_url;
    QString m_token;
    QString m_errorString;

    bool m_ready = false;
    bool m_busy = false;
    bool m_opening = false;
};
