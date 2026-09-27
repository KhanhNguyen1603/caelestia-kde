#pragma once

#include <qqmlengine.h>

#include "blobshape.hpp"

class BlobInvertedRect : public BlobShape {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal borderLeft READ borderLeft WRITE setBorderLeft NOTIFY borderLeftChanged)
    Q_PROPERTY(qreal borderRight READ borderRight WRITE setBorderRight NOTIFY borderRightChanged)
    Q_PROPERTY(qreal borderTop READ borderTop WRITE setBorderTop NOTIFY borderTopChanged)
    Q_PROPERTY(qreal borderBottom READ borderBottom WRITE setBorderBottom NOTIFY borderBottomChanged)
    Q_PROPERTY(qreal radiusTop READ radiusTop WRITE setRadiusTop NOTIFY radiusTopChanged)
    Q_PROPERTY(qreal radiusBottom READ radiusBottom WRITE setRadiusBottom NOTIFY radiusBottomChanged)

public:
    explicit BlobInvertedRect(QQuickItem* parent = nullptr);
    ~BlobInvertedRect() override;

    qreal radiusTop() const { return m_radiusTop >= 0 ? m_radiusTop : radius(); }

    void setRadiusTop(qreal v);

    qreal radiusBottom() const { return m_radiusBottom >= 0 ? m_radiusBottom : radius(); }

    void setRadiusBottom(qreal v);

    qreal borderLeft() const { return m_borderLeft; }

    void setBorderLeft(qreal v);

    qreal borderRight() const { return m_borderRight; }

    void setBorderRight(qreal v);

    qreal borderTop() const { return m_borderTop; }

    void setBorderTop(qreal v);

    qreal borderBottom() const { return m_borderBottom; }

    void setBorderBottom(qreal v);

signals:
    void borderLeftChanged();
    void borderRightChanged();
    void borderTopChanged();
    void borderBottomChanged();
    void radiusTopChanged();
    void radiusBottomChanged();

protected:
    bool isInvertedRect() const override { return true; }

    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

    void registerWithGroup() override;
    void unregisterFromGroup() override;

private:
    qreal m_borderLeft = 0;
    qreal m_borderRight = 0;
    qreal m_borderTop = 0;
    qreal m_borderBottom = 0;
    qreal m_radiusTop = -1;
    qreal m_radiusBottom = -1;
};
