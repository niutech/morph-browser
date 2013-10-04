/*
 * Copyright 2013 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import QtWebKit 3.1
import QtWebKit.experimental 1.0
import Ubuntu.Components 0.1
import Ubuntu.Components.Extras.Browser 0.1
import Ubuntu.Components.Popups 0.1

WebView {
    id: _webview

    signal newTabRequested(url url)

    property real devicePixelRatio: 1.0
    onDevicePixelRatioChanged: {
        // Do not make this patch to QtWebKit a hard requirement.
        if (experimental.hasOwnProperty('devicePixelRatio')) {
            experimental.devicePixelRatio = devicePixelRatio
        }
    }

    interactive: !selection.visible
    maximumFlickVelocity: height * 5

    /**
     * Client overridable function called before the default treatment of a
     *  valid navigation request. This function can stop the navigation request
     *  if it sets the 'action' field of the request to IgnoreRequest.
     *
     */
    function navigationRequestedDelegate(request) { }

    UserAgent {
        id: userAgent
    }
    experimental.userAgent: userAgent.defaultUA
    onNavigationRequested: {
        request.action = WebView.AcceptRequest;

        navigationRequestedDelegate (request);
        if (request.action === WebView.IgnoreRequest)
            return;

        _webview.experimental.userAgent = userAgent.getUAString(request.url)
    }

    experimental.preferences.navigatorQtObjectEnabled: true
    experimental.userScripts: [Qt.resolvedUrl("hyperlinks.js"),
                               Qt.resolvedUrl("selection.js")]
    experimental.onMessageReceived: {
        var data = null
        try {
            data = JSON.parse(message.data)
        } catch (error) {
            console.debug('DEBUG:', message.data)
            return
        }
        if ('event' in data) {
            if (data.event === 'longpress') {
                if (('img' in data) || ('href' in data)) {
                    contextualData.clear()
                    if ('img' in data) {
                        contextualData.img = data.img
                    }
                    if ('href' in data) {
                        contextualData.href = data.href
                        contextualData.title = data.title
                    }
                    contextualRectangle.position(data)
                    PopupUtils.open(contextualPopover, contextualRectangle)
                    return
                }
            }
            if ((data.event === 'longpress') || (data.event === 'selectionadjusted')) {
                selection.clearData()
                selection.createData()
                if ('html' in data) {
                    selection.mimedata.html = data.html
                }
                // FIXME: push the text and image data in the order
                // they appear in the selected block.
                if ('text' in data) {
                    selection.mimedata.text = data.text
                }
                if ('images' in data) {
                    // TODO: download and cache the images locally
                    // (grab them from the webview’s cache, if possible),
                    // and forward local URLs.
                    selection.mimedata.urls = data.images
                }
                selection.show(data.left, data.top, data.width, data.height)
            } else if (data.event === 'newtab') {
                newTabRequested(data.url)
            }
        }
    }

    experimental.itemSelector: ItemSelector {}

    property alias selection: selection
    property ActionList selectionActions
    Selection {
        id: selection

        anchors.fill: parent
        visible: false

        property Item __popover: null
        property var mimedata: null

        Component {
            id: selectionPopover
            ActionSelectionPopover {
                grabDismissAreaEvents: false
                actions: selectionActions
            }
        }

        function createData() {
            if (mimedata === null) {
                mimedata = Clipboard.newData()
            }
        }

        function clearData() {
            if (mimedata !== null) {
                delete mimedata
                mimedata = null
            }
        }

        function actionTriggered() {
            selection.visible = false
        }

        function __showPopover() {
            __popover = PopupUtils.open(selectionPopover, selection.rect)
            var actions = __popover.actions.actions
            for (var i in actions) {
                actions[i].onTriggered.connect(actionTriggered)
            }
        }

        function show(x, y, width, height) {
            var scale = _webview.experimental.test.contentsScale * _webview.experimental.test.devicePixelRatio
            rect.x = x * scale + _webview.contentX
            rect.y = y * scale + _webview.contentY
            rect.width = width * scale
            rect.height = height * scale
            visible = true
            __showPopover()
        }

        onVisibleChanged: {
            if (!visible && (__popover != null)) {
                PopupUtils.close(__popover)
                __popover = null
            }
        }

        onResized: {
            var message = new Object
            message.query = 'adjustselection'
            var rect = selection.rect
            var scale = _webview.experimental.test.contentsScale * _webview.experimental.test.devicePixelRatio
            message.left = (rect.x - _webview.contentX) / scale
            message.right = (rect.x + rect.width - _webview.contentX) / scale
            message.top = (rect.y - _webview.contentY) / scale
            message.bottom = (rect.y + rect.height - _webview.contentY) / scale
            _webview.experimental.postMessage(JSON.stringify(message))
        }

        function copy() {
            Clipboard.push(mimedata)
            clearData()
        }
    }

    Item {
        id: contextualRectangle

        visible: false

        function position(data) {
            var scale = _webview.experimental.test.contentsScale * _webview.experimental.test.devicePixelRatio
            x = data.left * scale
            y = data.top * scale
            width = data.width * scale
            height = data.height * scale
        }
    }
    property QtObject contextualData: QtObject {
        property url href
        property string title
        property url img

        function clear() {
            href = ''
            title = ''
            img = ''
        }
    }

    property ActionList contextualActions
    Component {
        id: contextualPopover
        ActionSelectionPopover {
            actions: contextualActions
        }
    }

    Scrollbar {
        parent: _webview.parent
        flickableItem: _webview
        align: Qt.AlignTrailing
    }

    Scrollbar {
        parent: _webview.parent
        flickableItem: _webview
        align: Qt.AlignBottom
    }

    WebviewThumbnailer {
        id: thumbnailer
        webview: _webview
        targetSize: Qt.size(units.gu(12), units.gu(12))
        property url thumbnailSource: "image://webthumbnail/" + _webview.url
        onThumbnailRendered: {
            if (url == _webview.url) {
                _webview.thumbnail = thumbnailer.thumbnailSource
            }
        }
    }
    property url thumbnail: (url && thumbnailer.thumbnailExists()) ? thumbnailer.thumbnailSource : ""
    onLoadingChanged: {
        if (loadRequest.status === WebView.LoadSucceededStatus) {
            if (!thumbnailer.thumbnailExists()) {
                thumbnailer.renderThumbnail()
            }
        }
    }
}
