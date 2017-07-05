 ; include for some of the windows messages defines
!include "winmessages.nsh"
!include "EnvVarUpdate.nsh"

!define PRODUCT_NAME "mbeddr"
!define PRODUCT_VERSION "1.0"
!define PRODUCT_PUBLISHER "mbeddr"
!define PRODUCT_WEB_SITE "http://www.mbeddr.com"

!include "MUI2.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "img\mbeddr.ico"
!define MUI_UNICON "img\mbeddr.ico"


; Welcome page
!define MUI_WELCOMEFINISHPAGE_BITMAP "img\welcome.bmp"
!insertmacro MUI_PAGE_WELCOME
; License page
!insertmacro MUI_PAGE_LICENSE "files\allLicenses.txt"
; Components page
!insertmacro MUI_PAGE_COMPONENTS
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "img\welcome.bmp"
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; MUI end ------

; Env variables fo all users
!define env_hklm 'HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'
!define dot_env_var 'GRAPHVIZ_DOT'
!define cbmc_env_var 'CBMC_CMD'

RequestExecutionLevel admin

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "Setup.exe"
InstallDir "$PROGRAMFILES\mbeddr"
ShowInstDetails show
ShowUnInstDetails show



Section "!mbeddr" SEC_MBEDDR
  SectionIn RO
  SetOutPath "$INSTDIR"
  SetOverwrite ifnewer

  FILE /r ".\files\mbeddr\*"
  
  CreateDirectory "$SMPROGRAMS\mbeddr"
  CreateShortCut "$SMPROGRAMS\mbeddr\mbeddr.lnk" "$INSTDIR\bin\mbeddr.bat" "" "$INSTDIR\mbeddr.ico" 0 SW_SHOWMAXIMIZED
  CreateShortCut "$DESKTOP\mbeddr.lnk" "$INSTDIR\bin\mbeddr.bat" "" "$INSTDIR\mbeddr.ico" 0 SW_SHOWMAXIMIZED

SectionEnd

SectionGroup "3rd party" SEC_3rdParty
  Section  "MinGW - downloaded" SEC_MINGW
    SetOutPath "$TEMP\mbeddr-install"
    SetOverwrite ifnewer
    
    NSISdl::download http://downloads.sourceforge.net/project/mingw/Installer/mingw-get/mingw-get-0.6.2-beta-20131004-1/mingw-get-0.6.2-mingw32-beta-20131004-1-bin.zip?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fmingw%2Ffiles%2FInstaller%2Fmingw-get%2Fmingw-get-0.6.2-beta-20131004-1%2F&ts=1431084060&use_mirror=heanet mingw-get.zip
    Pop $R0 ;Get the return value
      StrCmp $R0 "success" +3
        MessageBox MB_OK "Download failed: $R0"
        Quit
    ; unzip to c:/mingw
    CreateDirectory "c:\mingw"
    SetOutPath "c:\mingw"
    InitPluginsDir
    ; Call plug-in. Push filename to ZIP first, and the dest. folder last.
    nsisunz::UnzipToLog "$TEMP\mbeddr-install\mingw-get.zip" "c:\mingw"
   ; Always check result on stack
   Pop $0
   StrCmp $0 "success" ok
      DetailPrint "$0" ;print error message to log
   ok:

    ; install make (msys), gcc, gdb, mingw-make, unix-essentials (rm, ...)
    nsExec::ExecToLog '"c:\mingw\bin\mingw-get.exe" install "gcc=4.8.1-4" "mingw32-make=3.82.90-2" "gdb=7.6.1-1" msys msys-coreutils msys-make'

    ; modify the path variable
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "c:\mingw\bin"
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "C:\mingw\msys\1.0\bin"
  SectionEnd

  Section "CBMC" SEC_CBMC
    CreateDirectory "$INSTDIR\cbmc"
    SetOutPath "$INSTDIR\cbmc"
    SetOverwrite ifnewer
    FILE /r ".\files\3rd-party\cbmc\*"

    ; set variable
    WriteRegExpandStr ${env_hklm} ${cbmc_env_var} '$INSTDIR\cbmc\cbmc.exe'
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\cbmc"
  SectionEnd

  Section "GraphViz" SEC_GRAPHVIZ
    SetOutPath "$INSTDIR"
    SetOverwrite ifnewer
    FILE /r ".\files\3rd-party\graphviz\*"
    
    ; set variable
    WriteRegExpandStr ${env_hklm} ${dot_env_var} '"$INSTDIR\graphviz-2.38\bin\dot.exe"'
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\graphviz-2.38\bin\"
  SectionEnd

  Section -AdditionalIcons
    WriteIniStr "$INSTDIR\${PRODUCT_NAME}.url" "InternetShortcut" "URL" "${PRODUCT_WEB_SITE}"
    CreateShortCut "$SMPROGRAMS\mbeddr\Website.lnk" "$INSTDIR\${PRODUCT_NAME}.url"
    CreateShortCut "$SMPROGRAMS\mbeddr\Uninstall.lnk" "$INSTDIR\uninst.exe"
  SectionEnd
SectionGroupEnd

Section -Post
  ; notify windows about env var changes
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=250
  WriteUninstaller "$INSTDIR\uninst.exe"
SectionEnd


;------------------------------------------------------------------------------------------------
; - UNINSTALLER -
;------------------------------------------------------------------------------------------------

Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "mbeddr was removed successfully"
FunctionEnd

Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Would you like to remove mbeddr? Dependent components such as MinGW are not removed" IDYES +2
  Abort
FunctionEnd

Section Uninstall
  Delete "$INSTDIR\${PRODUCT_NAME}.url"
  Delete "$INSTDIR\uninst.exe"


  Delete "$SMPROGRAMS\mbeddr\Uninstall.lnk"
  Delete "$SMPROGRAMS\mbeddr\Website.lnk"
  Delete "$DESKTOP\mbeddr.lnk"
  Delete "$SMPROGRAMS\mbeddr\mbeddr.lnk"

  RMDir "$SMPROGRAMS\mbeddr"
  RMDir /r "$INSTDIR"

  ; remove entries from the path
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\cbmc"
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\graphviz-2.38\bin\"

  ; remove env variable reg keys
  DeleteRegValue ${env_hklm} ${dot_env_var}
  DeleteRegValue ${env_hklm} ${cbmc_env_var}
  
  ; notify windows about env var changes
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=250
  
  SetAutoClose true
SectionEnd

; Section descriptions - have to be at the end
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_MBEDDR} "mbeddr core components"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_3rdParty} "3rd party tools required by mbeddr"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_MINGW} "MinGW - Minimalist GNU for Windows. CAUTION: Requires internet connection $\n(http://www.mingw.org/)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CBMC} "CBMC - Bounded Model Checking for Software $\n(http://www.cprover.org/cbmc/)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_GRAPHVIZ} "GraphViz - Graph Visualization Software $\n(http://www.graphviz.org/)"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

