﻿; wiz 快速搜索，支持拼音首字母

global gConfig := {}
gConfig.closeAfterOpen := false

; 常量
global WIN_ME_TITLE := "wiz 快捷搜索"
global WIN_WIZ_TITLE := "ahk_class WizNoteMainFrame"
; 变量
MyListView :=
global gDocs := []
global gSearchType := "doc"
global gSearchKeys := { tag: "#", folder: "@", acc: "*" }
global gSearchData := {}  ; 缓存
clearSearchData()
; TODO
global gDocsFiltered := []

; 运行
global wiz := new Wiz()
global wizAcc := new WizAcc()
TCMatchOn(A_ScriptDir "\lib\tcmatch.dll")
InitGui()
Menu, Tray, icon, %A_ScriptDir%\wizQuickSearch.ico

WinWaitClose, ahk_exe Wiz.exe
ExitApp

; 注册调用热键
;#IfWinActive, ahk_class WizNoteMainFrame
    ;^p::
    #q::
        try {
            gDocs := wiz.getAllDocs(0)
        } catch e {
            msgbox 请重新启动
            ExitApp
        }
        
        Gui, Show, xCenter yCenter, % WIN_ME_TITLE
        GuiControl, Focus, Edit1
        GuiControl, , Edit1,
        ;SwitchIME2()

    return
; #IfWinActive

InitGui() {
    WIDTH := 550
    
    Gui, Add, Edit, r1 w%WIDTH% gSearchChange
    Gui, Add, ListView, xm r20 w%WIDTH% vMyListView gMyListView, 标题|标签|docIndex
    Gui, Add, Button, Hidden Default w0 h0, OK
    GUi, Add, StatusBar, ,

    COLUMN1_WIDTH := 360
    LV_ModifyCol(1, COLUMN1_WIDTH)
    LV_ModifyCol(2, WIDTH - COLUMN1_WIDTH - 21)
    LV_ModifyCol(3, 0)

    Hotkey, IfWinActive, % WIN_ME_TITLE
        Hotkey, ~up, FocusListView
        Hotkey, ~down, FocusListView
        Hotkey, ~left, FocusEdit
        Hotkey, ~right, FocusEdit
        Hotkey, ~BS, FocusEdit
        Hotkey, ^enter, SendDocuments
    Hotkey, IfWinActive
}

GuiEscape:
GuiClose:
    Gui, Cancel
    clearSearchData()
return

clearSearchData() {
    gSearchData := { tag: [], folder: [], acc: [] }
}

FocusListView:
    GuiControl, Focus, MyListView
return

FocusEdit:
    GuiControl, Focus, Edit1
return

SendDocuments:
    sendDocuments()
return

;~ #if NotFocusListView()
    ;~ ~up::
    ;~ ~down::
        ;~ GuiControl, Focus, MyListView
    ;~ return
;~ #if

;~ NotFocusListView() {
    ;~ IfWinActive, % A_ScriptName
    ;~ {
        ;~ ControlGetFocus, FocusedControl, A
        ;~ if FocusedControl <> MyListView
            ;~ return true
    ;~ }
    ;~ return false
;~ }

SearchChange:
    searchBreak := True
    SetTimer, SearchBreakSub, -200
return

SearchBreakSub:
    GuiControlGet, searchWord, , Edit1
    LV_Delete()
    searchBreak := False
    gDocsFiltered := []

    searchDoc(searchWord)
return

MyListView:
    if A_GuiEvent = DoubleClick
    {
        openSelectedDoc(A_EventInfo)
    }
return

ButtonOK:
    Gosub, FocusListView
    rowNum := LV_GetNext(0, "Focused")
    openSelectedDoc(rowNum)
return

SetStatusBar() {
    size := gDocsFiltered.Length()

    SB_SetText("共找到 " . size . " 条")
}

getData(type) {
    if (type == "tag") {
        data := wiz.getAllTags()
    } else if (type == "acc") {
        data := wizAcc.getLeftTreeItems()
    } else if (type == "folder") {
        data := wiz.getFolders()
    } else {
        data := wiz.getAllDocs(0)
    }

    return data
}

searchDoc(searchWord) { ; 搜索文档标题
    global searchBreak

    ; 判断搜索的类型
    gSearchType := ""
    allItems := []
    for searchType, searchKey in gSearchKeys
    {
        if (searchKey and InStr(searchWord, searchKey) == 1) {
            gSearchType := searchType
            searchWord := LTrim(searchWord, searchKey)
            if not gSearchData[searchType].Length()
                gSearchData[searchType] := getData(searchType)
            allItems := gSearchData[searchType]
            break
        }
    }

    if (!gSearchType) {
        gSearchType := "doc"
        allItems := gDocs
    }

    ; 如果是 doc 类型，先搜索标题
    addSearchResult(allItems, searchWord)

    ; 如果是 doc 类型，再搜索 tag
    if (gSearchType == "doc") {
        addSearchResult(allItems, searchWord, true)
    }

    ; TODO total 不准确，有延迟
    SetStatusBar()
}

addSearchResult(allItems, searchWord, isSearchTag:=False) {
    global searchBreak

    index := isSearchTag ? 100 : 1
    for i, info in allItems
    {
        displayTitle := info.displayTitle ? info.displayTitle : info.title
        if (isSearchTag) {
            searchTitle := info.tagText ? info.tagText : displayTitle
        } else {
            searchTitle := info.search ? info.search : displayTitle 
        }
        
        if TCMatch(searchTitle, searchWord)
        {
            LV_Add((index == 1 ? "Focus Select" : ""), displayTitle, info.tagText, i)

            index++
            gDocsFiltered.Push(info)
        }
        if searchBreak
            break
    }
}

openSelectedDoc(rowNum) {
    if (rowNum == 0) {
        return
    }
    
    LV_GetText(index, rowNum, 3)
    data := gSearchData[gSearchType]

    if (gSearchType == "doc") {
        doc := gDocsFiltered[rowNum]
        wiz.openDoc(doc.guid)
    } else if (gSearchType == "tag") {
        wiz.openTag(data[index])
    }else if (gSearchType == "folder") {
        wiz.openFolder(data[index])
    } else if (gSearchType == "acc") {
        wizAcc.clickSelected(data[index])
    }

    WinActivate, % WIN_WIZ_TITLE
    
    if (gConfig.closeAfterOpen)
        Gui, Cancel
}

sendDocuments() {
    if (gSearchType == "doc") {
        if (gDocsFiltered.Length())
            wiz.sendDocuments(gDocsFiltered)
        else
            wiz.newDocument()
        WinActivate, % WIN_WIZ_TITLE
    }
}

searchOther() { ; 搜索文件夹、标签

}

clearTip:
    ToolTip
return


#Include <Utils>
#Include <wizLib>
#Include <wizAcc>
#Include <tcmatch>