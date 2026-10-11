// signature — sign PDFs and fill them in with text and dates.

#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSettings>
#include <QDir>
#include <QUrl>

#include "backend.h"
#include "pageprovider.h"
#include "portalfilepicker.h"
#include "signatures.h"
#include "textitem.h"
#include "theme.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("signature");
    app.setOrganizationName("signature");
    app.setApplicationVersion("0.1.0");

    // Matches the window to signature.desktop, so the compositor (Wayland
    // app_id) and the launcher pick up the installed icon.
    app.setDesktopFileName("signature");
    app.setWindowIcon(QIcon::fromTheme("signature"));

    QQuickStyle::setStyle("Material");
    qmlRegisterType<TextItem>("Signature", 1, 0, "TextItem");

    Theme theme;
    QSettings settings;
    PortalFilePicker picker;
    SignatureLibrary signatures;
    auto *pages = new PageProvider();
    Backend backend(&picker, pages, &signatures, &settings);

    QQmlApplicationEngine engine;
    // The engine takes ownership of the image providers.
    engine.addImageProvider("pages", pages);
    engine.addImageProvider("items", new FunctionImageProvider([&backend](const QString &id) {
        return backend.items()->image(id.toInt());
    }));
    engine.addImageProvider("preview", new FunctionImageProvider([&backend](const QString &id) {
        return backend.previewImage(id);
    }));
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    const QStringList args = app.arguments();
    if (args.size() > 1)
        backend.openUrl(QUrl::fromUserInput(args.at(1), QDir::currentPath(), QUrl::AssumeLocalFile));

    return app.exec();
}
