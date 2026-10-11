#pragma once

#include <QHash>
#include <QImage>
#include <QList>
#include <QObject>
#include <QSettings>
#include <QSizeF>
#include <QUrl>

#include "items.h"
#include "signatures.h"

class FilePicker;
class PageProvider;

class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hasDocument READ hasDocument NOTIFY documentChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY documentChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY documentChanged)
    Q_PROPERTY(int generation READ generation NOTIFY documentChanged)
    Q_PROPERTY(qreal widestPage READ widestPage NOTIFY documentChanged)
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY noticeChanged)
    Q_PROPERTY(ItemModel *items READ items CONSTANT)
    Q_PROPERTY(SignatureLibrary *signatures READ signatures CONSTANT)
    Q_PROPERTY(QString lastSignature READ lastSignature NOTIFY lastSignatureChanged)
    Q_PROPERTY(int previewRevision READ previewRevision NOTIFY previewChanged)
    Q_PROPERTY(bool previewEmpty READ previewEmpty NOTIFY previewChanged)
    Q_PROPERTY(QString previewName READ previewName NOTIFY previewChanged)

public:
    Backend(FilePicker *picker, PageProvider *pages, SignatureLibrary *signatures,
            QSettings *settings, QObject *parent = nullptr);

    bool hasDocument() const { return !m_path.isEmpty(); }
    QString fileName() const;
    QString path() const { return m_path; }
    int pageCount() const { return m_pageSizes.size(); }
    int generation() const { return m_generation; }
    qreal widestPage() const;
    bool dirty() const { return m_items.revision() != m_savedRevision; }
    QString notice() const { return m_notice; }
    ItemModel *items() { return &m_items; }
    SignatureLibrary *signatures() const { return m_signatures; }
    QString lastSignature() const;
    int previewRevision() const { return m_previewRevision; }
    bool previewEmpty() const { return m_preview.isNull(); }
    QString previewName() const { return m_previewName; }
    QImage previewImage(const QString &which) const;

    Q_INVOKABLE qreal pageWidth(int page) const;
    Q_INVOKABLE qreal pageHeight(int page) const;

    Q_INVOKABLE void open();
    Q_INVOKABLE bool openUrl(const QUrl &url);
    Q_INVOKABLE void save();
    // Writes the signed copy; public so tests can save without a dialog.
    bool saveTo(const QString &target);

    // Placement takes the center point; returns the new item's row.
    Q_INVOKABLE int placeSignature(const QString &name, int page, qreal centerX, qreal centerY);
    Q_INVOKABLE int placeText(int page, qreal centerX, qreal centerY, const QString &text);
    Q_INVOKABLE QString today() const;
    Q_INVOKABLE void rememberSize(int row);

    Q_INVOKABLE void chooseSignatureImage();
    Q_INVOKABLE void setPreviewThreshold(qreal threshold);
    Q_INVOKABLE QString saveSignature(const QString &name);
    Q_INVOKABLE void removeSignature(const QString &name);
    Q_INVOKABLE void clearNotice();

    Q_INVOKABLE bool loadSignatureImage(const QString &path);

signals:
    void documentChanged();
    void dirtyChanged();
    void noticeChanged();
    void lastSignatureChanged();
    void previewChanged();
    void signatureImageReady();
    void saved();

private:
    void setNotice(const QString &notice);
    void updatePreview();
    qreal textSize() const;

    FilePicker *m_picker;
    PageProvider *m_pages;
    SignatureLibrary *m_signatures;
    QSettings *m_settings;
    ItemModel m_items;
    QHash<int, QString> m_signatureNames;  // image id → the signature it came from

    QString m_path;
    QList<QSizeF> m_pageSizes;
    int m_generation = 0;
    int m_savedRevision = 0;
    QString m_notice;

    QImage m_previewSource;
    QImage m_preview;
    QString m_previewName;
    qreal m_previewThreshold = .25;
    int m_previewRevision = 0;
};
