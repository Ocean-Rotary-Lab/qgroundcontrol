#pragma once

#include <QtCore/QUrl>
#include <QtQmlIntegration/QtQmlIntegration>
#include <QtQuick3D/QQuick3DGeometry>

class RobotStlGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QUrl defaultSource READ defaultSource CONSTANT)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(bool colored READ colored NOTIFY coloredChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit RobotStlGeometry(QQuick3DObject *parent = nullptr);

    QUrl source() const { return _source; }
    void setSource(const QUrl &source);
    QUrl defaultSource() const;
    bool loaded() const { return _loaded; }
    bool colored() const { return _colored; }
    QString errorString() const { return _errorString; }

signals:
    void sourceChanged();
    void loadedChanged();
    void coloredChanged();
    void errorStringChanged();

private:
    void _loadMesh();
    void _setLoaded(bool loaded);
    void _setColored(bool colored);
    void _setErrorString(const QString &errorString);

    QUrl _source;
    QString _errorString;
    bool _loaded = false;
    bool _colored = false;
};
