#include "walletstore.h"

#include <KWallet>

#include <QMap>

using KWallet::Wallet;

WalletStore::WalletStore(QObject *parent)
    : QObject(parent)
{
}

WalletStore::~WalletStore()
{
    delete m_wallet;
}

QString WalletStore::url() const
{
    return m_url;
}

QString WalletStore::token() const
{
    return m_token;
}

bool WalletStore::hasCredentials() const
{
    return !m_url.trimmed().isEmpty() && !m_token.trimmed().isEmpty();
}

bool WalletStore::ready() const
{
    return m_ready;
}

bool WalletStore::busy() const
{
    return m_busy;
}

QString WalletStore::errorString() const
{
    return m_errorString;
}

QString WalletStore::folderName()
{
    return QStringLiteral("Growspace Manager Plasma");
}

QString WalletStore::entryName()
{
    return QStringLiteral("homeassistant");
}

void WalletStore::load()
{
    beginOperation(Operation::Load);
}

void WalletStore::saveCredentials(const QString &url, const QString &token)
{
    m_pendingUrl = url.trimmed();
    m_pendingToken = token.trimmed();

    if (m_pendingUrl.isEmpty() || m_pendingToken.isEmpty()) {
        m_pendingOperation = Operation::Save;
        setError(QStringLiteral("Home Assistant URL and access token are required."));
        finish(false);
        return;
    }

    beginOperation(Operation::Save);
}

void WalletStore::clearCredentials()
{
    beginOperation(Operation::Clear);
}

void WalletStore::beginOperation(Operation operation)
{
    m_pendingOperation = operation;
    m_busy = true;
    clearError();
    Q_EMIT stateChanged();
    ensureWallet();
}

void WalletStore::ensureWallet()
{
    if (m_wallet && m_wallet->isOpen()) {
        m_ready = true;
        performPendingOperation();
        return;
    }

    if (m_opening) {
        return;
    }

    if (!Wallet::isEnabled()) {
        setError(QStringLiteral("KWallet is disabled."));
        finish(false);
        return;
    }

    delete m_wallet;
    m_wallet = Wallet::openWallet(Wallet::NetworkWallet(), 0, Wallet::Asynchronous);

    if (!m_wallet) {
        setError(QStringLiteral("KWallet could not be opened."));
        finish(false);
        return;
    }

    m_opening = true;

    connect(m_wallet, &Wallet::walletOpened, this, [this](bool success) {
        m_opening = false;

        if (!success || !m_wallet || !m_wallet->isOpen()) {
            setError(QStringLiteral("KWallet access was denied or the wallet could not be unlocked."));
            finish(false);
            return;
        }

        m_ready = true;
        Q_EMIT stateChanged();
        performPendingOperation();
    });

    connect(m_wallet, &Wallet::walletClosed, this, [this]() {
        m_ready = false;
        m_opening = false;
        m_url.clear();
        m_token.clear();
        Q_EMIT credentialsChanged();
        Q_EMIT stateChanged();
    });

    connect(m_wallet, &Wallet::folderUpdated, this, [this](const QString &folder) {
        if (folder == folderName() && !m_busy) {
            load();
        }
    });
}

bool WalletStore::ensureFolder(bool create)
{
    if (!m_wallet || !m_wallet->isOpen()) {
        setError(QStringLiteral("KWallet is not open."));
        return false;
    }

    if (!m_wallet->hasFolder(folderName())) {
        if (!create) {
            return false;
        }

        if (!m_wallet->createFolder(folderName())) {
            setError(QStringLiteral("Could not create the Growspace Manager folder in KWallet."));
            return false;
        }
    }

    if (!m_wallet->setFolder(folderName())) {
        setError(QStringLiteral("Could not select the Growspace Manager folder in KWallet."));
        return false;
    }

    return true;
}

void WalletStore::performPendingOperation()
{
    switch (m_pendingOperation) {
    case Operation::Load:
        performLoad();
        break;
    case Operation::Save:
        performSave();
        break;
    case Operation::Clear:
        performClear();
        break;
    case Operation::None:
        m_busy = false;
        Q_EMIT stateChanged();
        break;
    }
}

void WalletStore::performLoad()
{
    if (!ensureFolder(false)) {
        if (m_errorString.isEmpty()) {
            m_url.clear();
            m_token.clear();
            Q_EMIT credentialsChanged();
            finish(true);
        } else {
            finish(false);
        }
        return;
    }

    if (!m_wallet->hasEntry(entryName())) {
        m_url.clear();
        m_token.clear();
        Q_EMIT credentialsChanged();
        finish(true);
        return;
    }

    QMap<QString, QString> values;
    if (m_wallet->readMap(entryName(), values) != 0) {
        setError(QStringLiteral("Could not read Home Assistant credentials from KWallet."));
        finish(false);
        return;
    }

    m_url = values.value(QStringLiteral("url")).trimmed();
    m_token = values.value(QStringLiteral("access_token")).trimmed();

    Q_EMIT credentialsChanged();
    finish(true);
}

void WalletStore::performSave()
{
    if (!ensureFolder(true)) {
        finish(false);
        return;
    }

    QMap<QString, QString> values;
    values.insert(QStringLiteral("url"), m_pendingUrl);
    values.insert(QStringLiteral("access_token"), m_pendingToken);

    if (m_wallet->writeMap(entryName(), values) != 0) {
        setError(QStringLiteral("Could not write Home Assistant credentials to KWallet."));
        finish(false);
        return;
    }

    m_url = m_pendingUrl;
    m_token = m_pendingToken;
    Q_EMIT credentialsChanged();
    finish(true);
}

void WalletStore::performClear()
{
    if (!ensureFolder(false)) {
        if (m_errorString.isEmpty()) {
            m_url.clear();
            m_token.clear();
            Q_EMIT credentialsChanged();
            finish(true);
        } else {
            finish(false);
        }
        return;
    }

    if (m_wallet->hasEntry(entryName()) && m_wallet->removeEntry(entryName()) != 0) {
        setError(QStringLiteral("Could not remove Home Assistant credentials from KWallet."));
        finish(false);
        return;
    }

    m_url.clear();
    m_token.clear();
    Q_EMIT credentialsChanged();
    finish(true);
}

void WalletStore::finish(bool success)
{
    const Operation completed = m_pendingOperation;
    m_pendingOperation = Operation::None;
    m_busy = false;

    if (!success) {
        m_ready = m_wallet && m_wallet->isOpen();
    }

    Q_EMIT stateChanged();

    switch (completed) {
    case Operation::Load:
        Q_EMIT loadFinished(success);
        break;
    case Operation::Save:
        Q_EMIT saveFinished(success);
        break;
    case Operation::Clear:
        Q_EMIT clearFinished(success);
        break;
    case Operation::None:
        break;
    }
}

void WalletStore::setError(const QString &message)
{
    m_errorString = message;
    Q_EMIT stateChanged();
}

void WalletStore::clearError()
{
    if (m_errorString.isEmpty()) {
        return;
    }

    m_errorString.clear();
    Q_EMIT stateChanged();
}
