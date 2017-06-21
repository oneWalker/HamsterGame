    .386
     .model flat,stdcall 
     option casemap:none 
;include定义
include windows.inc
include gdi32.inc
includelib gdi32.lib
include user32.inc
includelib user32.lib
include kernel32.inc
includelib kernel32.lib
 
;equ等值定义
IDT_TIMER equ 1
IDT_SHOWM equ 2
BACK_WIDTH equ 630
BACK_HEIGHT equ 490

 IDI_MAIN_ICON      equ             101
 IDB_BACK           equ             102
 IDB_KICK           equ             104
 IDB_SM_KICK       equ              105
 IDD_SCORE          equ             106
 IDC_KICKDOWN      equ              107
 IDC_CURSOR2       equ              108
 IDC_KICKUP        equ              108
 IDR_WAVE1         equ              109
 IDR_WAVE2        equ               110
 IDC_PTIME        equ               1001
IDC_HITTIME       equ              1002
IDC_SHOWTIME      equ              1003
IDC_HITRATE      equ               1004
IDC_SCORE        equ               1005

;数据段
       .data
gMCount dd 0;出现的次数
gHitCount dd 0;击中次数
gTimerS dd 30 ;游戏时间：30s
gHitted dd 0;表示是否被击中
gGameStart dd 0;表示当前是否正在游戏
gMTime dd 1300;表示地鼠出现的时长
       .data?
gLastX dd ?;出现的X坐标
gLastY dd ?;出现的Y坐标
hDcDuck dd ?;鸭子的DC
hBmpDuck dd ?
hDcHit dd ?;被击中的鸭子DC
hBmpHit dd ?

hInstance dd ?
hWinMain dd ?
hDcBack dd  ?;保存背景图片
hBmpBack dd ?

hWinDlg dd ?;对话框句柄
szMsgBox db 256 dup(?);保存格式化文本信息
hCursorMain dd ?  ;窗口主光标
hCursorDown dd ?  ;按下锤子的光标

       .const
szClasName db 'shrewmouse',0
szCaptionMain db 'little game',0
szText db 'some games make life better',0
szDlgTmFmt db '%d second',0
szDlgFmt db '%d',0
szDlgScrFmt db '%d/%d',0
lOffset dd 35
aOffset dd 70
tOffset dd 105
szScoreFmt db 'hit rate:%d/%d',0
szTimeFmt db  'rest time:%d second',0

;代码段
     .code
;创建背景图片
_CreateBack proc 
  local @hDC,@hBmpBack 
  invoke GetDC,hWinMain   ;获得主窗口的hDC作为参考hDC 
  mov @hDC,eax 
  invoke CreateCompatibleDC,@hDC  ;创建背景hDC 
  mov hDcBack,eax 
  invoke CreateCompatibleBitmap,@hDC,BACK_WIDTH,BACK_HEIGHT ;创建位图绘图区域
  mov hBmpBack,eax 
  invoke ReleaseDC,hWinMain,@hDC  ;释放参考hDC 
  invoke LoadBitmap,hInstance,IDB_BACK ;加载位图
  mov @hBmpBack,eax 
  invoke SelectObject,hDcBack,eax
  ;填充颜色背景
  invoke CreatePatternBrush,@hBmpBack 
  push eax 
  invoke SelectObject,hDcBack,eax 
  invoke PatBlt,hDcBack,0,0,BACK_WIDTH,BACK_HEIGHT,PATCOPY 
  pop eax 
  invoke DeleteObject,eax 
  ;释放资源
  invoke DeleteObject,@hBmpBack 
  ret 
_CreateBack endp 
;释放背景图片资源
_DeleteBack proc
      invoke DeleteDC,hDcBack
	  invoke DeleteObject,hBmpBack
	  ret
_DeleteBack endp

;对话框回调函数
_ProcDlgMain proc uses ebx edi esi hWnd,wMsg,wParam,lParam 
  mov eax,wMsg 
  .if eax == WM_CLOSE 
   invoke EndDialog,hWnd,NULL 
  .elseif eax == WM_INITDIALOG 
   invoke LoadIcon,hInstance,IDI_MAIN_ICON 
   invoke SendMessage,hWnd,WM_SETICON,ICON_BIG,eax 
   mov eax,hWnd 
   mov hWinDlg,eax
  
  ;加载游戏数据
   invoke wsprintf,addr szMsgBox,addr szDlgTmFmt,gTimerS 
   invoke SetDlgItemText,hWnd,IDC_PTIME,addr szMsgBox 
   invoke wsprintf,addr szMsgBox,addr szDlgFmt,gHitCount 
   invoke SetDlgItemText,hWnd,IDC_HITTIME,addr szMsgBox 
   invoke SetDlgItemText,hWnd,IDC_SCORE,addr szMsgBox 
   invoke wsprintf,addr szMsgBox,addr szDlgFmt,gMCount 
   invoke SetDlgItemText,hWnd,IDC_SHOWTIME,addr szMsgBox 
   invoke wsprintf,addr szMsgBox,addr szDlgScrFmt,gHitCount,gMCount 
   invoke SetDlgItemText,hWnd,IDC_HITRATE,addr szMsgBox 
  .elseif eax == WM_COMMAND 
   mov eax,wParam 
   .if ax == IDCANCEL 
    invoke EndDialog,hWnd,NULL 
    invoke  DestroyWindow,hWinMain 
    invoke  PostQuitMessage,NULL 
   .elseif ax == IDOK 
 ;初始化数据
	   mov eax,1 
       mov gGameStart,eax 
       mov eax,30 
       mov gTimerS,eax 
       mov eax,0 
       mov gHitCount,eax 
       mov gMCount,eax 
       mov gHitted,eax 
       mov eax,1300 
       mov gMTime,eax
	   
       invoke EndDialog,hWnd,NULL 
   .endif 
  .else 
   mov eax,FALSE
   ret 
  .endif 
  mov eax,TRUE 
  ret 
_ProcDlgMain  endp
;弹出对话框
_ShowDialog proc 
       invoke DialogBoxParam,hInstance,IDD_SCORE,\ 
       hWinMain,offset _ProcDlgMain,NULL 
       ret 
_ShowDialog endp
;first和second之间的函数且需要修改
iRand  proc uses ecx edx first, second 
     invoke GetTickCount ; 取得随机数种子，当然，可用别的方法代替
 
     mov ecx, 23         
     mul ecx            
     add eax, 7        
     mov ecx, second     
     sub ecx, first      
 
     inc ecx            
 
     xor edx, edx         
     div ecx             
     add edx, first     
     mov eax, edx        
     ret 
iRand  endp

;创建鸭子图片
_CreateDuck proc 
  local @hDC,@hBmpDuck,@hBmpHit 
  invoke GetDC,hWinMain 
  mov @hDC,eax 
  invoke CreateCompatibleDC,@hDC 
  mov hDcDuck,eax 
  invoke CreateCompatibleDC,@hDC 
  mov hDcHit,eax 
  invoke CreateCompatibleBitmap,@hDC,70,70 
  mov hBmpDuck,eax
  invoke CreateCompatibleBitmap,@hDC,70,70 
  mov hBmpHit,eax 
  invoke ReleaseDC,hWinMain,@hDC 
  invoke LoadBitmap,hInstance,IDB_KICK
  mov @hBmpDuck,eax 
  invoke LoadBitmap,hInstance,IDB_SM_KICK 
  mov @hBmpHit,eax 
  invoke SelectObject,hDcDuck,hBmpDuck 
  invoke SelectObject,hDcHit,hBmpHit
  ;填充鸭子图形
 
  invoke CreatePatternBrush,@hBmpDuck
  push eax 
  invoke SelectObject,hDcDuck,eax 
  invoke PatBlt,hDcDuck,0,0,70,70,PATCOPY 
  pop eax 
  invoke DeleteObject,eax  ;填充被击中的鸭子图形
  invoke CreatePatternBrush,@hBmpHit 
  push eax 
  invoke SelectObject,hDcHit,eax 
  invoke PatBlt,hDcHit,0,0,70,70,PATCOPY 
  pop eax 
  invoke DeleteObject,eax 
   
  invoke DeleteObject,@hBmpDuck 
  invoke DeleteObject,@hBmpHit 
  ret 
_CreateDuck endp
;释放鸭子资源
_DeleteDuck proc
      invoke DeleteDC,hDcDuck
	  invoke DeleteDC,hDcHit
	  invoke DeleteObject,hBmpDuck
	  invoke DeleteObject,hBmpHit
	  ret
_DeleteDuck endp
;初始化操作
_Init proc
      invoke _CreateBack
	  invoke _CreateDuck
	  invoke SetTimer,hWinMain,IDT_TIMER,1000,NULL;游戏时间计算时间
	  invoke SetTimer,hWinMain,IDT_SHOWM ,1300,NULL;被打击物显示时间
	  
	  ret
_Init endp
;在指定的坐标绘制鸭子
_ProcDrawDuck proc _x,_y 
  local @mX,@mY,@hBmpBack 

  mov eax,_x 
  mul aOffset 
  add eax,lOffset 
  mov @mX,eax 
  mov eax,_y 
  mul aOffset 
  add eax,tOffset 
  mov @mY,eax 
  
  ;清空背景图像
  invoke LoadBitmap,hInstance,IDB_BACK 
  mov @hBmpBack,eax 
  invoke CreatePatternBrush,@hBmpBack 
  push eax 
  invoke SelectObject,hDcBack,eax 
  invoke PatBlt,hDcBack,0,0,BACK_WIDTH,BACK_HEIGHT,PATCOPY 
  pop eax 
  invoke DeleteObject,eax
  ;画上鸭子
 
  .if gHitted == 0 
   invoke BitBlt,hDcBack,@mX,@mY,70,70,hDcDuck,0,0,SRCCOPY
   .else 
   invoke BitBlt,hDcBack,@mX,@mY,70,70,hDcHit,0,0,SRCCOPY 
  .endif 
  ;画上文字描述
   invoke wsprintf,addr szMsgBox,addr szTimeFmt,gTimerS 
  invoke TextOut,hDcBack,10,10,addr szMsgBox,eax 
  invoke wsprintf,addr szMsgBox,addr szScoreFmt,gHitCount,gMCount 
  invoke TextOut,hDcBack,10,50,addr szMsgBox,eax
  ret 
_ProcDrawDuck endp

;判断是否被打中
_CheckHit proc _mX,_mY 
  local @pX,@pY,@pW,@pH 
  .if gHitted == 1 
   ret   ;已经击中了当前鸭子，不能继续击中
 
  .else 
   ;获得鸭子区域
 
   mov eax,gLastX 
   mul aOffset 
   add eax,lOffset 
   mov @pX,eax 
   add eax,aOffset 
   mov @pW,eax 
   mov eax,gLastY 
   mul aOffset 
   add eax,tOffset 
   mov @pY,eax 
   add eax,aOffset 
   mov @pH,eax 
 ;判断坐标范围
 
   mov eax,_mX 
   .if eax > @pX && eax < @pW 
    mov eax,_mY 
    .if eax > @pY && eax < @pH 
     mov eax,1 
     mov gHitted,eax 
     inc gHitCount
;窗口过程
	 invoke _ProcDrawDuck,gLastX,gLastY 
     invoke InvalidateRect,hWinMain,NULL,FALSE	  
   .endif
   .endif
   ret 
  .endif 
_CheckHit endp 

_GameEnd proc
       mov eax,0
	   mov gGameStart,eax
	   mov gTimerS,30
	   call _ShowDialog
	   ret
_GameEnd endp
_ProcWinMain proc uses ebx edi esi hWnd,uMsg,wParam,lParam
         local @stPs:PAINTSTRUCT
		 local @stRect:RECT
		 local @hDc ;窗口句柄
		 local @mX,@mY
		 mov eax,uMsg
		 
		 .if eax == WM_PAINT
		 invoke BeginPaint,hWnd,addr @stPs
		 mov @hDc,eax
		 
		 mov eax,@stPs.rcPaint.right ;计算绘图区域
         sub eax,@stPs.rcPaint.left 
         mov ecx,@stPs.rcPaint.bottom 
         sub ecx,@stPs.rcPaint.top 
         invoke BitBlt,@hDc,@stPs.rcPaint.left,@stPs.rcPaint.top,eax,ecx,\ 
         hDcBack,@stPs.rcPaint.left,@stPs.rcPaint.top,SRCCOPY 
 
 
         invoke EndPaint,hWnd,addr @stPs
		 .elseif eax == WM_CREATE 
          mov  eax,hWnd 
          mov  hWinMain,eax 
          call  _Init	
		  call _ShowDialog
		 invoke _ProcDrawDuck,1,2
		
		 .elseif eax== WM_CLOSE
		 
		 invoke  _DeleteBack 
		  
		 invoke _DeleteDuck;释放鸭子图片
		 
		 invoke DestroyWindow,hWinMain ;销毁被关闭的窗口
		 invoke PostQuitMessage,NULL ;用于投递退出程序的消息
		 .elseif eax == WM_LBUTTONDOWN    
		 invoke SetClassLong,hWnd,GCL_HCURSOR,hCursorDown    
		 mov eax,lParam    
		 movzx eax,ax    
		 mov @mX,eax    
		 mov eax,lParam    
		 shr eax,16    
		 mov @mY,eax    
		 invoke _CheckHit,@mX,@mY
		 
		 .elseif eax == WM_LBUTTONUP    
		 invoke SetClassLong,hWnd,GCL_HCURSOR,hCursorMain 
		
		.elseif eax == WM_TIMER    
		mov eax,wParam
		.if eax == IDT_SHOWM     
		mov eax,gGameStart     
		.if eax != 0   ;游戏开始标记
         mov ecx,0     
	    mov gHitted,ecx      
		invoke iRand,0,6      
		mov gLastX,eax      
		invoke iRand,0,2      
		mov gLastY,eax      
		inc gMCount      
		sub gMTime,25      
		invoke _ProcDrawDuck,gLastX,gLastY      
		invoke InvalidateRect,hWnd,NULL,FALSE      
		invoke SetTimer,hWinMain,IDT_SHOWM,gMTime,NULL     
		.endif    
		.elseif eax == IDT_TIMER     
		mov eax,gGameStart     
		.if eax != 0   ;判断游戏时间
         mov eax,gTimerS      
		 .if eax > 0       
		 dec gTimerS      
		 .else       
		 call _GameEnd      
		 .endif     
		.endif 
		
	  .endif 
	  
		.else 
		      invoke DefWindowProc,hWnd,uMsg,wParam,lParam
			  ret
		 .endif 
	     xor eax,eax   
	     ret
_ProcWinMain endp
;WinMain函数
_WinMain proc
        local @stWndClass: WNDCLASSEX
		local @stMsg:MSG
		invoke GetModuleHandle,NULL
		mov hInstance,eax
		invoke LoadCursor,hInstance,IDC_KICKUP 
        mov hCursorMain,eax 
		push hInstance 
		invoke LoadCursor,hInstance,IDC_KICKDOWN   
		mov hCursorDown,eax   
		mov @stWndClass.hCursor,eax   
		push hInstance 
        invoke RtlZeroMemory,addr @stWndClass,sizeof @stWndClass 
;注册窗口类
       pop @stWndClass.hInstance 
       push hCursorMain 
       pop  @stWndClass.hCursor
	   invoke LoadIcon,hInstance,IDI_MAIN_ICON 
       mov @stWndClass.hIcon,eax
	   pop @stWndClass.hInstance
	   mov @stWndClass.cbSize,sizeof WNDCLASSEX
	   mov @stWndClass.style,CS_HREDRAW or CS_VREDRAW
	   mov @stWndClass.lpfnWndProc,offset _ProcWinMain
	   mov @stWndClass.hbrBackground,COLOR_WINDOW+1
	   mov @stWndClass.lpszClassName,offset szClasName
	   invoke RegisterClassEx,addr @stWndClass
;建立并显示窗口
       invoke CreateWindowEx,WS_EX_CLIENTEDGE,\
	          offset szClasName,offset szCaptionMain,\
			  WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU,\
			  100,100,560,350,\
			  NULL,NULL,hInstance,NULL
       mov hWinMain,eax
	   invoke ShowWindow,hWinMain,SW_SHOWNORMAL
	   invoke UpdateWindow,hWinMain
;消息循环
     .while TRUE
	 invoke GetMessage,addr @stMsg,NULL,0,0
	 .break .if eax == 0
	 invoke TranslateMessage,addr @stMsg
	 invoke DispatchMessage,addr @stMsg
	 .endw
	 ret
_WinMain endp
;结束当前进行的游戏

;程序真正的入口
start:
       call _WinMain
	   invoke ExitProcess,NULL
	   end start