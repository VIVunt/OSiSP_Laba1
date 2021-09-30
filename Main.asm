format PE GUI 4.0
entry Start

  include 'fasmw17327/include/win32a.inc'

  timerCount  = 3        ;Количество шагов таймера при отскоке

section '.code' code readable executable

Start:
;Регистрация окна
  invoke GetModuleHandle, 0
  mov [wc.hInstance], eax  
  mov [hInstance], eax  
  invoke LoadIcon, 0, IDI_APPLICATION
  mov [wc.hIcon], eax       
  invoke LoadCursor, 0, IDC_ARROW
  mov [wc.hCursor], eax
  invoke RegisterClassEx, wc  
  
;Создание окна
  invoke CreateWindowEx, 0, _class, _title, WS_OVERLAPPEDWINDOW,\
      CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, NULL, NULL, [hInstance], NULL 
  mov [hMainWnd], eax
  
;Отображение окна                          
  invoke ShowWindow, [hMainWnd], SW_SHOWNOACTIVATE  
  
;Установка начальных координат картинки в центр окна
  mov eax, [centX]
  mov ecx, [bm.bmWidth]
  shr ecx, 1
  sub eax, ecx
  mov [x], eax                    
  mov eax, [centY]  
  mov ecx, [bm.bmHeight]
  shr ecx, 1
  sub eax, ecx
  mov [y], eax
  
;Обновление окна
  invoke UpdateWindow, [hMainWnd]   
                                  
;Обработка сообщений 
msg_loop:
  invoke GetMessage, msg, NULL, 0, 0
  test  eax, eax
  jz end_proc   
  invoke TranslateMessage, msg
  invoke DispatchMessage, msg
  jmp msg_loop 

;Конец программы
end_proc:
  invoke ExitProcess, [msg.wParam]

;Процедура обработки сообщений  
proc WndProc uses ebx esi edi, hwnd, wmsg, wparam, lparam    
  cmp [wmsg], WM_DESTROY
  je .wmdestroy    
  cmp [wmsg], WM_CREATE
  je .wmcreate        
  cmp [wmsg], WM_PAINT
  je .wmpaint        
  cmp [wmsg], WM_SIZE
  je .wmsize       
  cmp [wmsg], WM_LBUTTONDOWN
  je .wmlbuttondown 
  cmp [wmsg], WM_LBUTTONUP
  je .wmlbuttonup
  cmp [wmsg], WM_MOUSEMOVE
  je  .wmmousemove   
  cmp [wmsg], WM_MOUSEWHEEL
  je  .wmmousewheel   
  cmp [wmsg], WM_CHAR
  je  .wmchar        
  cmp [wmsg], WM_TIMER
  je  .wmtimer    
  
.defwndproc:
  invoke DefWindowProc, [hwnd], [wmsg], [wparam], [lparam]
  jmp .finish 
 
 ;Захват картинки при нажатии ЛКМ
  ;Захват происходит только при попадании мыши в область картинки
.wmlbuttondown:
  mov ecx, [lparam]
  and ecx, 0x0000FFFF 
  mov edx, [lparam]
  shr edx, 16
  cmp ecx, [x]
  jl  @f          
  cmp edx, [y]
  jl  @f   
  mov eax, [x]
  add eax, [bm.bmWidth] 
  cmp ecx, eax
  jg  @f      
  mov eax, [y]
  add eax, [bm.bmHeight]    
  cmp edx, eax
  jg  @f 
  mov [xm], ecx
  mov [ym], edx
  mov [draw], 1   ;Установка флага рисования
@@:
  jmp .finish   
  
;Отпуск картинки при отпуске ЛКМ   
.wmlbuttonup:   
  mov [draw], 0       ;Отпуск флага рисования
  jmp .finish
 
;Отрисовка картинки при захвате мышью  
.wmmousemove:
  cmp [wparam], MK_LBUTTON
  jz @F              ;Флаг рисовани установлен, но ЛКМ не нажата
  mov [draw], 0        ;В таком случае флаг рисования отключается
  jmp @F
@@:
  cmp [draw], 1
  jnz @F         
  invoke  BitBlt, [hDC], [x], [y], [bm.bmWidth], [bm.bmHeight], NULL, 0, 0, PATCOPY          ;Закраска картинки в старой позиции
  mov eax, [lparam]                  ;Установка новых координат
  and eax, 0x0000FFFF 
  sub eax, [xm]
  mov edx, [lparam]
  shr edx, 16          
  sub edx, [ym]
  add [x],  eax
  add [y],  edx
  add [xm], eax
  add [ym], edx
  stdcall IsGoingAbroad, [x], [y], [bm.bmWidth], [bm.bmHeight], 0, 0, [xsize], [ysize]          ;Проверка на выход за границы
  test  eax,  eax
  jz  @f
  mov [x],  edx
  mov [y],  ecx
  mov [boundside],  eax
  mov [timercount], timerCount
  invoke  SetTimer, [hwnd], 1, 20, NULL           ;Установка таймера отскока в случае выхода
@@: 
  invoke  InvalidateRect, [hwnd], NULL, 0                    
@@:
  jmp .finish  
       
;Прокрутка колеса мыши
.wmmousewheel:   
  invoke  BitBlt, [hDC], [x], [y], [bm.bmWidth], [bm.bmHeight], NULL, 0, 0, PATCOPY 
  mov eax, [wparam] 
  sar eax,  16
  mov edx,  eax
  shr edx,  16
  mov cx, 120 ; !!!чекнуть файл zmouse.h и константу mouse_wheel
  idiv cx
  movsx eax,  ax
  imul  eax,  eax,  10
  mov ecx,  [wparam]
  and ecx,  0x0000FFFF
  cmp ecx,  MK_SHIFT
  jz  .shift
  sub [y],  eax
  jmp @f
.shift:
  add [x],  eax
@@:    
  stdcall IsGoingAbroad, [x], [y], [bm.bmWidth], [bm.bmHeight], 0, 0, [xsize], [ysize]     ;Проверка на выход за границы
  test  eax,  eax
  jz  @f
  mov [x],  edx
  mov [y],  ecx
  mov [boundside],  eax
  mov [timercount], timerCount
  invoke  SetTimer, [hwnd], 1, 20, NULL                        ;Установка таймера отскока в случае выхода
@@: 
  invoke  InvalidateRect, [hwnd], NULL, 0   
  jmp .finish       
  
;Сообщения от клавиатуры
  ;!!! не реализована поддержка CapsLock
.wmchar:    
  invoke  BitBlt, [hDC], [x], [y], [bm.bmWidth], [bm.bmHeight], NULL, 0, 0, PATCOPY  
  cmp [wparam], 119      ;w
  jnz @f                                
  sub [y], 10
  jmp .wchar_end
@@:     
  cmp [wparam], 115      ;s
  jnz @f                    
  add [y], 10    
  jmp .wchar_end
@@:         
  cmp [wparam], 97       ;a
  jnz @f                    
  sub [x], 10      
  jmp .wchar_end
@@:   
  cmp [wparam], 100      ;d
  jnz .wchar_end          
  add [x], 10        
.wchar_end: 
  stdcall IsGoingAbroad, [x], [y], [bm.bmWidth], [bm.bmHeight], 0, 0, [xsize], [ysize]     ;Проверка на выход за границы
  test  eax,  eax
  jz  @f
  mov [x],  edx
  mov [y],  ecx
  mov [boundside],  eax
  mov [timercount], timerCount
  invoke  SetTimer, [hwnd], 1, 20, NULL                   ;Установка таймера отскока в случае выхода
@@:   
  invoke  InvalidateRect, [hwnd], NULL, 0  
  jmp .finish 
 
;Отрисовка      
.wmpaint: 
  invoke BeginPaint, [hwnd], pntstr    ;!!!dirty code: второе создание дескриптора экрана   
  invoke  TransparentBlt, eax, [x], [y], [bm.bmWidth], [bm.bmHeight], [hBmpDC], 0, 0, [bm.bmWidth], [bm.bmHeight], 0xFFFFFF   
  invoke EndPaint, [hwnd], pntstr   
  jmp .finish 
  
;Создание окна  
.wmcreate:      
  invoke GetDC, [hwnd], pntstr
  mov [hDC], eax
  invoke  LoadImage, NULL, _bmp, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE or LR_CREATEDIBSECTION
  mov [hBmp], eax
  invoke  CreateCompatibleDC, [hDC]
  mov [hBmpDC], eax  
  invoke  SelectObject, [hBmpDC], [hBmp]
  invoke  GetObject, [hBmp], sizeof.BITMAP, bm
  invoke  GetStockObject, GRAY_BRUSH
  mov [hBrush], eax
  invoke  SelectObject, [hDC], eax   
  invoke SetClassLong, [hwnd], GCL_HBRBACKGROUND, [hBrush]   
  jmp .finish
       
;Установка координат центра экрана при изменении размеров    
.wmsize:
  mov eax, [lparam]
  and eax, 0x0000FFFF 
  mov [xsize],  eax
  shr eax, 1
  mov [centX], eax
  mov eax, [lparam] 
  shr eax, 16   
  mov [ysize],  eax
  shr eax, 1
  mov [centY], eax
  
  stdcall IsGoingAbroad, [x], [y], [bm.bmWidth], [bm.bmHeight], 0, 0, [xsize], [ysize]       ;Проверка на выход за границы
  test  eax,  eax
  jz  @f
  mov [x],  edx
  mov [y],  ecx
  mov [boundside],  eax
  mov [timercount], timerCount
  invoke  SetTimer, [hwnd], 1, 20, NULL              ;Установка таймера отскока в случае выхода
@@:  
  jmp .finish 
 
;Сообщения таймера
.wmtimer:     
  cmp [timercount], 0            ;Проверка количество оставшихся интераций таймера
  jg  @f
  invoke  KillTimer,  [hwnd], 1 
  mov [timercount], 0
  mov [boundside],  0
  jmp .timer_end
@@:
  invoke  BitBlt, [hDC], [x], [y], [bm.bmWidth], [bm.bmHeight], NULL, 0, 0, PATCOPY 
  cmp [boundside],  1
  jnz @f
  add [y],  20
  jmp .timer_end  
@@:       
  cmp [boundside],  2
  jnz @f
  sub [x],  20   
  jmp .timer_end 
@@:  
  cmp [boundside],  3
  jnz @f
  sub [y],  20    
  jmp .timer_end 
@@:   
  add [x],  20
.timer_end:
  invoke  InvalidateRect, [hwnd], NULL, 0
  dec [timercount]    
  jmp .finish

;Закрытие окна           
.wmclose:
  invoke  DeleteObject, [hBmp]
  invoke  DeleteDC, [hBmpDC]     
  invoke  ReleaseDC, [hDC]
  invoke DestroyWindow, [hwnd]
  jmp .finish

;Разрушение окна  
.wmdestroy:
  invoke PostQuitMessage, 0
  xor eax, eax     
  
.finish:
  ret
endp 

;Процедура проверки выхода за границу
 ;Корректирует координаты при выходе за груницу   
  ;edx  - скорректированная координата x
  ;ecx  - скорректированна координата y
  ;0 - выхода нет
  ;1 - выход по Оx вверх
  ;2 - выход по Oy вправо
  ;3 - выход по Ox вниз
  ;4 - выход по Oy влево
proc  IsGoingAbroad uses  ebx  edi  esi, x, y, width, height, xstart, ystart, xend, yend
  mov eax,  [y]
  cmp eax,  [ystart]
  jnl @f
  mov edx,  [x]
  xor ecx,  ecx
  mov eax,  1
  jmp   ._end
@@:   
  mov eax,  [x]
  add eax,  [width]
  cmp eax,  [xend]
  jng @f   
  mov edx,  [xend]   
  sub edx,  [width] 
  mov ecx,  [y]  
  mov eax,  2
  jmp   ._end  
@@:   
  mov eax,  [y]
  add eax,  [height]
  cmp eax,  [yend]
  jng @f    
  mov edx,  [x]    
  mov ecx,  [yend]
  sub ecx,  [height]
  mov eax,  3
  jmp   ._end  
@@:   
  mov eax,  [x]
  cmp eax,  [xstart]
  jnl @f
  xor edx,  edx
  mov ecx,  [y]
  mov eax,  4
  jmp   ._end  
@@:  
  xor eax,  eax
._end:
  ret
endp

section '.data' data readable writeable   
     
  hMainWnd  dd  ?   
  hInstance  dd  ?  
  
  hDC dd ?    
  hBmp dd  ?             
  hBmpDC dd  ?   
  
  centX  dd  ?
  centY  dd  ?
  
  xsize dd  ?
  ysize dd  ?
  
  x dd  ?
  y dd  ?
  
  xm  dd  ?
  ym  dd  ? 
   
  draw  db  0
  
  boundside  dd  0
  
  timercount  dd  0

  _class TCHAR 'Win32', 0  
  _title TCHAR 'My Windows', 0  
    
  _bmp  TCHAR 'img.bmp', 0   
  
  wc WNDCLASSEX sizeof.WNDCLASSEX, 0, WndProc, 0, 0, NULL, NULL, NULL, COLOR_GRAYTEXT+1, NULL, _class, NULL
  
  msg MSG  
         
  pntstr  PAINTSTRUCT
  
  bm  BITMAP  
  
  hBrush  dd  ? 

section '.idata' import data readable writeable

  library kernel32, 'KERNEL32.DLL',\        
          gdi32,  'GDI32.DLL',\
          user32, 'USER32.DLL',\   
          msimg32, 'MSIMG32.DLL' 

  include 'api\kernel32.inc'   
  include 'api\gdi32.inc'  
  include 'api\user32.inc'     
   
  import msimg32,\
       TransparentBlt,'TransparentBlt'