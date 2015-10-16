/*
 * Copyright 2015 Canonical Ltd.
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

import QtQuick 2.4
import QtTest 1.0
import Ubuntu.Test 1.0
import "../../../src/app/webbrowser"
import webbrowserapp.private 0.1

Item {
    id: root

    width: 800
    height: 600

    Component {
        id: bookmarksModel
        BookmarksModel {
            databasePath: ":memory:"
        }
    }

    property BookmarksFoldersViewWide view
    property var bookmarks
    property string homepage: "http://example.com/homepage"

    Component {
        id: viewComponent
        BookmarksFoldersViewWide {
            anchors.fill: parent
            homeBookmarkUrl: homepage
            model: bookmarks
        }
    }

    SignalSpy {
        id: bookmarkClickedSpy
        signalName: "bookmarkClicked"
    }

    SignalSpy {
        id: bookmarkRemovedSpy
        signalName: "bookmarkRemoved"
    }

    UbuntuTestCase {
        name: "BookmarksFoldersViewWide"
        when: windowShown

        function init() {
            bookmarks = bookmarksModel.createObject()
            view = viewComponent.createObject(root)
            populate()

            view.focus = true

            bookmarkClickedSpy.target = view
            bookmarkClickedSpy.clear()
            bookmarkRemovedSpy.target = view
            bookmarkRemovedSpy.clear()
        }

        function populate() {
            bookmarks.add("http://example.com", "Example Com", "", "")
            bookmarks.add("http://example.org/bar", "Example Org Bar", "", "Folder B")
            bookmarks.add("http://example.org/foo", "Example Org Foo", "", "Folder B")
            bookmarks.add("http://example.net/a", "Example Net A", "", "Folder A")
            bookmarks.add("http://example.net/b", "Example Net B", "", "Folder A")
        }

        function cleanup() {
            bookmarks.destroy()
            bookmarks = null

            view.destroy()
            view = null
        }

        function clickItem(item) {
            var center = centerOf(item)
            mouseClick(item, center.x, center.y)
        }

        function getListItems(name, itemName) {
            var list = findChild(view, name)
            var items = []
            if (list) {
                // ensure all the delegates are created
                list.cacheBuffer = list.count * 1000

                // In some cases the ListView might add other children to the
                // contentItem, so we filter the list of children to include
                // only actual delegates
                var children = list.contentItem.children
                for (var i = 0; i < children.length; i++) {
                    if (children[i].objectName === itemName) {
                        items.push(children[i])
                    }
                }
            }
            return items
        }

        function test_folder_list() {
            var items = getListItems("foldersList", "folderItem")
            compare(items.length, 3)
            verify(items[0].isAllBookmarksFolder)
            compare(items[0].model.folder, "")
            // named folder items should appear alphabetically sorted
            compare(items[1].model.folder, "Folder A")
            compare(items[2].model.folder, "Folder B")
        }

        function test_all_bookmarks_list() {
            var items = getListItems("bookmarksList", "bookmarkItem")
            compare(items.length, 2)
            compare(items[0].url, homepage)
            compare(items[1].title, "Example Com")
        }

        function test_navigate_folders_by_keyboard() {
            var foldersList = getListItems(view, "foldersList")
            var folders = getListItems("foldersList", "folderItem")
            verify(folders[0].isActiveFolder)

            keyClick(Qt.Key_Down)
            verify(!folders[0].isActiveFolder)
            verify(folders[1].isActiveFolder)

            // bookmarks within a folder are sorted with the first bookmarked appearing last
            var items = getListItems("bookmarksList", "bookmarkItem")
            compare(items[0].title, "Example Net B")
            compare(items[1].title, "Example Net A")
            compare(items.length, 2)

            keyClick(Qt.Key_Down)
            verify(folders[2].isActiveFolder)
            items = getListItems("bookmarksList", "bookmarkItem")
            compare(items[0].title, "Example Org Foo")
            compare(items[1].title, "Example Org Bar")
            compare(items.length, 2)

            // verify scrolling beyond bottom of list is not allowed
            keyClick(Qt.Key_Down)
            verify(folders[2].isActiveFolder)

            keyClick(Qt.Key_Up)
            verify(folders[1].isActiveFolder)
            keyClick(Qt.Key_Up)
            verify(folders[0].isActiveFolder)

            keyClick(Qt.Key_Up)
        }

        function test_switch_between_folder_and_bookmarks_by_keyboard() {
            var foldersList = findChild(view, "foldersList")
            var bookmarks = findChild(view, "bookmarksList")
            var folders = getListItems("foldersList", "folderItem")

            verify(folders[0].isActiveFolder)

            keyClick(Qt.Key_Right)
            verify(bookmarks.activeFocus)
            keyClick(Qt.Key_Right)
            verify(bookmarks.activeFocus) // verify no circular scrolling

            keyClick(Qt.Key_Left)
            verify(foldersList.activeFocus)
            keyClick(Qt.Key_Left)
            verify(foldersList.activeFocus) // verify no circular scrolling

            keyClick(Qt.Key_Down)
            verify(!folders[0].isActiveFolder)
            verify(folders[1].isActiveFolder)

            keyClick(Qt.Key_Right)
            verify(bookmarks.activeFocus)
            keyClick(Qt.Key_Right)
            verify(bookmarks.activeFocus) // verify no circular scrolling

            keyClick(Qt.Key_Left)
            verify(foldersList.activeFocus)
            keyClick(Qt.Key_Left)
            verify(foldersList.activeFocus) // verify no circular scrolling
        }

        function test_activate_bookmarks_by_keyboard() {
            keyClick(Qt.Key_Right)

            var items = getListItems("bookmarksList", "bookmarkItem")
            keyClick(Qt.Key_Return)
            compare(bookmarkClickedSpy.count, 1)
            compare(bookmarkClickedSpy.signalArguments[0][0], homepage)

            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Return)
            compare(bookmarkClickedSpy.count, 2)
            compare(bookmarkClickedSpy.signalArguments[1][0], "http://example.com")
        }

        function test_activate_bookmarks_by_mouse() {
            var items = getListItems("bookmarksList", "bookmarkItem")
            clickItem(items[0])
            compare(bookmarkClickedSpy.count, 1)
            compare(bookmarkClickedSpy.signalArguments[0][0], homepage)

            clickItem(items[1])
            compare(bookmarkClickedSpy.count, 2)
            compare(bookmarkClickedSpy.signalArguments[1][0], "http://example.com")
        }

        function test_switch_folders_by_mouse() {
            var folders = getListItems("foldersList", "folderItem")

            clickItem(folders[1])
            var items = getListItems("bookmarksList", "bookmarkItem")
            compare(items[0].title, "Example Net B")
            compare(items[1].title, "Example Net A")
            compare(items.length, 2)

            clickItem(folders[0])
            items = getListItems("bookmarksList", "bookmarkItem")
            compare(items[0].url, homepage)
            compare(items[1].title, "Example Com")
            compare(items.length, 2)
        }

        function test_remove_bookmarks_by_keyboard() {
            keyClick(Qt.Key_Right)
            var items = getListItems("bookmarksList", "bookmarkItem")

            // verify that trying to delete the homepage bookmark does not work
            keyClick(Qt.Key_Delete)
            compare(bookmarkRemovedSpy.count, 0)

            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Delete)
            compare(bookmarkRemovedSpy.count, 1)
            compare(bookmarkRemovedSpy.signalArguments[0][0], items[1].url)
        }
    }
}