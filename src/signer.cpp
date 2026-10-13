#include "signer.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QUuid>
#include <QRandomGenerator>
#include <QTemporaryFile>

#include <algorithm>

#include <poppler-form.h>
#include <poppler-qt6.h>

namespace Signer {

namespace {

// The app-owned NSS database, next to the signatures directory.
QString databaseDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/signed/certificates");
}

// Point poppler's NSS backend at the app database, creating it first. NSS
// keeps this state for the process, so it's set once.
void ensureBackend() {
    static bool done = false;
    if (done)
        return;
    const QString dir = databaseDir();
    QDir().mkpath(dir);
    if (!QFileInfo::exists(dir + QStringLiteral("/key4.db")))
        QProcess::execute(QStringLiteral("certutil"), {QStringLiteral("-N"), QStringLiteral("-d"),
                                                       QStringLiteral("sql:") + dir, QStringLiteral("--empty-password")});
    Poppler::setNSSDir(dir);
    Poppler::setActiveCryptoSignBackend(Poppler::CryptoSignBackend::NSS);
    done = true;
}

}

QList<Certificate> certificates() {
    ensureBackend();
    QList<Certificate> out;
    const QVector<Poppler::CertificateInfo> certs = Poppler::getAvailableSigningCertificates();
    for (const Poppler::CertificateInfo &cert : certs) {
        Certificate entry;
        entry.nickname = cert.nickName();
        entry.commonName = cert.subjectInfo(Poppler::CertificateInfo::EntityInfoKey::CommonName);
        entry.organization = cert.subjectInfo(Poppler::CertificateInfo::EntityInfoKey::Organization);
        out.append(entry);
    }
    return out;
}

QString createCertificate(const QString &name, const QString &organization, QString *nickname) {
    const QString commonName = name.trimmed();
    if (commonName.isEmpty())
        return QStringLiteral("A name is needed for the certificate.");
    const QString org = organization.trimmed().isEmpty() ? commonName : organization.trimmed();

    ensureBackend();
    const QString dir = databaseDir();

    // certutil needs a seed file for key generation; the nickname is a unique
    // id (the Common Name is what viewers show).
    QString noisePath;
    QTemporaryFile noise(QStringLiteral("signed-noise-XXXXXX"));
    if (noise.open()) {
        noise.write(QUuid::createUuid().toRfc4122() + QUuid::createUuid().toRfc4122());
        noisePath = noise.fileName();
        noise.close();
    }
    if (noisePath.isEmpty())
        return QStringLiteral("couldn't create a temporary file");

    const QString nick = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QProcess process;
    process.start(QStringLiteral("certutil"), {
        QStringLiteral("-S"), QStringLiteral("-d"), QStringLiteral("sql:") + dir,
        QStringLiteral("-n"), nick, QStringLiteral("-x"), QStringLiteral("-t"), QStringLiteral("CT,,"),
        // self-signed certs all share the same issuer (themselves), so the
        // serial must differ between them
        QStringLiteral("-m"), QString::number(QRandomGenerator::global()->generate64() % 999999999),
        QStringLiteral("-s"), QStringLiteral("CN=%1, O=%2").arg(commonName, org),
        QStringLiteral("-k"), QStringLiteral("rsa"), QStringLiteral("-g"), QStringLiteral("2048"),
        QStringLiteral("-v"), QStringLiteral("1200"), QStringLiteral("-Z"), QStringLiteral("SHA256"),
        QStringLiteral("--keyUsage"), QStringLiteral("digitalSignature,nonRepudiation"),
        QStringLiteral("-z"), noisePath,
    });
    if (!process.waitForFinished(30000))
        return QStringLiteral("the certificate couldn't be created.");
    QFile::remove(noisePath);
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        const QString output = QString::fromLocal8Bit(process.readAllStandardError().trimmed());
        return QStringLiteral("the certificate couldn't be created: %1").arg(output);
    }

    if (nickname)
        *nickname = nick;
    return {};
}

QString importCertificate(const QString &path, const QString &password,
                          bool *needsPassword, QString *nickname) {
    ensureBackend();

    const QList<Certificate> before = certificates();

    // ponytail: the password goes on the command line, visible in /proc for
    // the moment the tool runs; pipe it through stdin if that ever matters.
    QProcess process;
    process.start(QStringLiteral("pk12util"), {
        QStringLiteral("-i"), path,
        QStringLiteral("-d"), QStringLiteral("sql:") + databaseDir(),
        QStringLiteral("-W"), password,
        QStringLiteral("-K"), QString(),
    });
    if (!process.waitForFinished(30000))
        return QStringLiteral("the certificate couldn't be imported.");

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (needsPassword)
            *needsPassword = password.isEmpty();
        const QString output = QString::fromLocal8Bit(process.readAllStandardError().trimmed());
        return QStringLiteral("import failed (exit %1, file %2): %3")
            .arg(process.exitCode()).arg(path, output);
    }

    // The nickname comes from the file; find what's new since the import.
    const QList<Certificate> after = certificates();
    for (const Certificate &cert : after) {
        const bool known = std::any_of(before.cbegin(), before.cend(),
                                       [&](const Certificate &c) { return c.nickname == cert.nickname; });
        if (!known) {
            if (nickname)
                *nickname = cert.nickname;
            return {};
        }
    }
    return QStringLiteral("the certificate is already in the database.");
}

Result sign(const QString &path, const QString &certNickname) {
    ensureBackend();

    std::unique_ptr<Poppler::Document> document = Poppler::Document::load(path);
    if (!document)
        return {false, false, QStringLiteral("the PDF couldn't be reopened for signing")};
    std::unique_ptr<Poppler::PDFConverter> converter = document->pdfConverter();
    if (!converter)
        return {false, false, QStringLiteral("this poppler can't sign")};

    // poppler signs to a new file; a temp sibling keeps a failure from
    // touching what's already there.
    QTemporaryFile temp(QFileInfo(path).absolutePath() + QStringLiteral("/.signed-XXXXXX.pdf"));
    temp.setAutoRemove(false);
    if (!temp.open())
        return {false, false, QStringLiteral("couldn't create a temporary file")};
    const QString tempName = temp.fileName();
    temp.close();

    // A signature field with no area and no text renders nothing: the
    // signature is in the file, not on the page. The placed stamp is the
    // visual part.
    Poppler::PDFConverter::NewSignatureData data;
    data.setCertNickname(certNickname);
    data.setPage(0);
    data.setBoundingRectangle(QRectF());
    data.setSignatureText(QStringLiteral(" "));
    data.setFontSize(10);
    data.setBorderWidth(0);
    converter->setOutputFileName(tempName);

    if (!converter->sign(data)) {
        QFile::remove(tempName);
        using SR = Poppler::PDFConverter::SigningResult;
        switch (converter->lastSigningResult()) {
        case SR::UserCancelled:
            return {false, true, QStringLiteral("signing was cancelled")};
        case SR::KeyMissing:
            return {false, false, QStringLiteral("the certificate is no longer in the database")};
        case SR::BadPassphrase:
            return {false, false, QStringLiteral("the passphrase didn't work")};
        case SR::WriteFailed:
            return {false, false, QStringLiteral("the file couldn't be written")};
        default: {
            const Poppler::ErrorString details = converter->lastSigningErrorDetails();
            if (details.type == Poppler::ErrorStringType::UserString && !details.data.toString().isEmpty())
                return {false, false, details.data.toString()};
            return {false, false, QStringLiteral("signing failed")};
        }
        }
    }

    // Swap the signed temp file into place.
    QFile::remove(path);
    if (!QFile::rename(tempName, path)) {
        QFile::remove(tempName);
        return {false, false, QStringLiteral("the signed file couldn't replace the original")};
    }
    return {true, false, {}};
}

}
