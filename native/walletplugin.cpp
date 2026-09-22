#include "walletstore.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class GrowspaceWalletPlugin final : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<WalletStore>(uri, 1, 0, "WalletStore");
    }
};

#include "walletplugin.moc"
