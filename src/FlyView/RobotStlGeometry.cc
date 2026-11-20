#include "RobotStlGeometry.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QCryptographicHash>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QtEndian>
#include <QtGui/QVector3D>

#include <algorithm>
#include <bit>
#include <cmath>
#include <limits>

namespace {

constexpr quint32 kMaxTriangleCount = 1'000'000;
constexpr qsizetype kHeaderSize = 84;
constexpr qsizetype kTriangleSize = 50;
constexpr qsizetype kVertexStride = 6 * sizeof(float);
constexpr qsizetype kColoredVertexStride = 10 * sizeof(float);
constexpr qsizetype kColorHeaderSize = 7 + 32 + sizeof(quint32);

float readFloat(const uchar *data)
{
    return std::bit_cast<float>(qFromLittleEndian<quint32>(data));
}

QVector3D vertexAt(const uchar *triangle, int index)
{
    const uchar *vertex = triangle + 12 + index * 12;
    // The exported mesh uses its longer +Y axis aft and is inverted relative
    // to the robot's upright frame. The flight view uses -Z forward and +Y up.
    // Rotate the mesh 180 degrees around the body's forward axis.
    // Flipping both horizontal and vertical axes preserves triangle winding.
    return QVector3D(readFloat(vertex), -readFloat(vertex + 8), readFloat(vertex + 4));
}

} // namespace

RobotStlGeometry::RobotStlGeometry(QQuick3DObject *parent)
    : QQuick3DGeometry(parent)
{
}

QUrl RobotStlGeometry::defaultSource() const
{
    QDir directory(QCoreApplication::applicationDirPath());
    const QString relativePath = QStringLiteral("robot_visual/single_link_version/meshes/base_link.STL");
    do {
        const QFileInfo meshFile(directory.filePath(relativePath));
        if (meshFile.isFile()) {
            return QUrl::fromLocalFile(meshFile.absoluteFilePath());
        }
    } while (directory.cdUp());

    return {};
}

void RobotStlGeometry::setSource(const QUrl &source)
{
    if (_source == source) {
        return;
    }
    _source = source;
    emit sourceChanged();
    _loadMesh();
}

void RobotStlGeometry::_setLoaded(bool loaded)
{
    if (_loaded == loaded) {
        return;
    }
    _loaded = loaded;
    emit loadedChanged();
}

void RobotStlGeometry::_setColored(bool colored)
{
    if (_colored == colored) {
        return;
    }
    _colored = colored;
    emit coloredChanged();
}

void RobotStlGeometry::_setErrorString(const QString &errorString)
{
    if (_errorString == errorString) {
        return;
    }
    _errorString = errorString;
    emit errorStringChanged();
}

void RobotStlGeometry::_loadMesh()
{
    clear();
    _setLoaded(false);
    _setColored(false);
    _setErrorString({});

    if (_source.isEmpty()) {
        return;
    }
    if (!_source.isLocalFile()) {
        _setErrorString(tr("Select a local binary STL file"));
        return;
    }

    QFile file(_source.toLocalFile());
    if (!file.open(QIODevice::ReadOnly)) {
        _setErrorString(tr("Cannot open robot mesh: %1").arg(file.errorString()));
        return;
    }
    const QByteArray stl = file.readAll();
    if (stl.size() < kHeaderSize) {
        _setErrorString(tr("Robot mesh is too short"));
        return;
    }

    const auto *bytes = reinterpret_cast<const uchar *>(stl.constData());
    const quint32 triangleCount = qFromLittleEndian<quint32>(bytes + 80);
    if (triangleCount == 0 || triangleCount > kMaxTriangleCount ||
        stl.size() != kHeaderSize + qsizetype(triangleCount) * kTriangleSize) {
        _setErrorString(tr("Robot mesh must be a valid binary STL with at most one million triangles"));
        return;
    }

    // A local sidecar stores one RGB color per triangle. The hash prevents
    // applying these colors to a different or reordered STL export.
    QFile colorsFile(file.fileName() + QStringLiteral(".colors"));
    QByteArray colors;
    if (colorsFile.open(QIODevice::ReadOnly)) {
        const QByteArray candidate = colorsFile.readAll();
        if (candidate.size() == kColorHeaderSize + qsizetype(triangleCount) * 3 &&
            candidate.startsWith(QByteArrayLiteral("QGCCLR1")) &&
            candidate.mid(7, 32) == QCryptographicHash::hash(stl, QCryptographicHash::Sha256) &&
            qFromLittleEndian<quint32>(reinterpret_cast<const uchar *>(candidate.constData() + 39)) == triangleCount) {
            colors = candidate;
        }
    }
    const bool hasColors = !colors.isEmpty();
    const qsizetype vertexStride = hasColors ? kColoredVertexStride : kVertexStride;

    QVector3D minimum(std::numeric_limits<float>::max(), std::numeric_limits<float>::max(), std::numeric_limits<float>::max());
    QVector3D maximum(-std::numeric_limits<float>::max(), -std::numeric_limits<float>::max(), -std::numeric_limits<float>::max());
    for (quint32 i = 0; i < triangleCount; ++i) {
        const uchar *triangle = bytes + kHeaderSize + qsizetype(i) * kTriangleSize;
        for (int j = 0; j < 3; ++j) {
            const QVector3D point = vertexAt(triangle, j);
            minimum.setX(std::min(minimum.x(), point.x()));
            minimum.setY(std::min(minimum.y(), point.y()));
            minimum.setZ(std::min(minimum.z(), point.z()));
            maximum.setX(std::max(maximum.x(), point.x()));
            maximum.setY(std::max(maximum.y(), point.y()));
            maximum.setZ(std::max(maximum.z(), point.z()));
        }
    }

    const QVector3D extent = maximum - minimum;
    const float longestSide = std::max({extent.x(), extent.y(), extent.z()});
    if (!std::isfinite(longestSide) || longestSide <= 0.0f) {
        _setErrorString(tr("Robot mesh has invalid bounds"));
        return;
    }
    const QVector3D center = (minimum + maximum) * 0.5f;
    const float displayScale = 320.0f / longestSide;

    QByteArray vertexData;
    vertexData.resize(qsizetype(triangleCount) * 3 * vertexStride);
    float *output = reinterpret_cast<float *>(vertexData.data());
    for (quint32 i = 0; i < triangleCount; ++i) {
        const uchar *triangle = bytes + kHeaderSize + qsizetype(i) * kTriangleSize;
        const QVector3D a = vertexAt(triangle, 0);
        const QVector3D b = vertexAt(triangle, 1);
        const QVector3D c = vertexAt(triangle, 2);
        const QVector3D normal = QVector3D::crossProduct(b - a, c - a).normalized();
        const uchar *rgb = hasColors ? reinterpret_cast<const uchar *>(colors.constData() + kColorHeaderSize + qsizetype(i) * 3) : nullptr;
        for (const QVector3D &point : {a, b, c}) {
            const QVector3D scaled = (point - center) * displayScale;
            *output++ = scaled.x();
            *output++ = scaled.y();
            *output++ = scaled.z();
            *output++ = normal.x();
            *output++ = normal.y();
            *output++ = normal.z();
            if (rgb) {
                *output++ = float(rgb[0]) / 255.0f;
                *output++ = float(rgb[1]) / 255.0f;
                *output++ = float(rgb[2]) / 255.0f;
                *output++ = 1.0f;
            }
        }
    }

    setVertexData(vertexData);
    setStride(vertexStride);
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic, 0, QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic, 3 * sizeof(float), QQuick3DGeometry::Attribute::F32Type);
    if (hasColors) {
        addAttribute(QQuick3DGeometry::Attribute::ColorSemantic, 6 * sizeof(float), QQuick3DGeometry::Attribute::F32Type);
    }
    setBounds((minimum - center) * displayScale, (maximum - center) * displayScale);
    update();
    _setColored(hasColors);
    _setLoaded(true);
}
