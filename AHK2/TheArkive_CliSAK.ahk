﻿; ================================================================
; === cli class, easy one-time and streaming output that collects stdOut and stdErr, and allows writing to stdIn
; === huge thanks to:
; ===	user: segalion ; https://autohotkey.com/board/topic/82732-class-command-line-interface/#entry526882
; === ... who posted his version of this on 20 July 2012 - 08:43 AM.
; === his code was so clean even I could understand it, and I'm new to classes!
; === another huge thanks to:
; ===	user(s): Sweeet, sean, and maraksan_user ; https://autohotkey.com/board/topic/15455-stdouttovar/page-7#entry486617
; === ... for thier work with StdoutToVar() which inspired me, and thanks to SKAN, HotKeyIt, Sean, maz_1 for
; === StdOutStream() ; https://autohotkey.com/board/topic/96903-simplified-versions-of-seans-stdouttovar/page-2
; === ... which was another very important part of the road map to making this function work.
; === And thanks go "just me" who taught me how to understand structures, pointers, and alignment
; === of elements in a structure on a level where I can finally do this kind of code.
; === Finally, thanks to Lexikos for all the advice he gave to the above users that allowed the creation of these
; === amazing milestones.
; ===
; === Also, thanks to TheGood for coming up with a super easy and elegant way of appending large amounts of text in an
; === edit control, which pertains directly to how some code like this would be used with a GUI.
; ===
; === Thanks to @joedf for LibCon.  That library helped me understand how to read console output and was integral
; === to me being able to create mode "m" to console capture animations.
; ===
; === This class basically combines StdoutToVar() and StdOutStream() into one package, and has the added benefit of not 
; === hanging up the script/GUI as much.  I am NOT throwing shade at StdoutToVar(), StdOutStream(), or the people who created
; === them.  Those functions were amazing milestones.  Without those functions, this version, and other implementations like
; === LibCon would likely not have been possible.
; ================================================================
;	new cli(sCmd, options="")
; ================================================================
;	Parameters:
;		sCmd		(required)	= Single-line command or multi-line batch command, depending on mode: specified
;								  in options.
;
;		options		(optional)	= Zero or more of the following strings, pipe (|) delimited:
; ========================================================================================================
; ========================================================================================================
; START Options
; ========================================================================================================
; ========================================================================================================
;
;		ID:MyID					= User defined string to identify CLI sessions.
;									This is used to identify a CLI instance in callback functions.
;
;		mode:[modes]			= Modes define how the CLI instance is launched and handled.
;								  *** Specify ONLY ONE of the following ***
;								  *** If you specify moe than one you will get an error ***
;									mode "w" = Wait mode, run command, collect data, and exit (default).
;											   If "s", "b" or "w" are not specified then "w" is assumed.
;											   ** myObj.ctrlC() and myObj.ctrlBreak() will NOT function
;											   in this mode!  If a cmd/process appears to hang, usually
;											   the user will have to forcefully terminate the process 
;											   manually.  The function that runs this mode will also hang.
;									mode "s" = Streaming mode, continual collection until exit.  If you
;											   want an interactive background CLI session, use mode "s".
;
;										*** NOTE: Modes "b" and "m" are NOT interactive.  They process the
;												  batch and exit.
;
;									mode "b" = Batch mode, run multi-line command lists and capture
;											   cli prompt in a callback function.  Default: cliPromptCallback()
;									mode "m" = Monitoring mode, this launches a hidden CLI window and
;											   records text as you would actually see it.  Usually used with
;											   a callback function.  Useful for capturing animations like
;											   incrementing completion percent, or a progress bar...
;											   Progress Bar: ie.  [======>       ]
;											   These kinds of animations are not sent to STDOUT, only to
;											   the console.  That is what mode "m" is for.
;
;											   Usage: m(width,height[,modes])
;													- width : number of columns
;													- height: number of rows
;													- modes : modes for cmd.exe
;														* type "cmd /?" to see a list of valid modes
;														Ex : /Q /K, etc.
;														Use any valid combo of modes.  Default mode is "/C".
;
;													A smaller area captured performs better than capturing
;													a larger area.
;
;								  *** apped these modes as needed ***
;									mode "c" = Delay sCmd execution, and/or specify other modes without trying
;											   to cram them all into the options.
;									mode "x" = Extract StdErr in a separate pipe.  Stored in myObj.error
;											   by default.
;									mode "e" = Use a callback function for StdErr.  If the function does
;											   not exist, then StdErr is stored in myObj.error ... note
;											   that mode "e" implies mode "x".
;											   ** Default: stdErrCallback(data,ID)
;									mode "o" = Use StdOut callback function.  Default: stdOutCallback(data,ID)
;											   By default when no callback, myObj.output contains StdOut data.
;									mode "i" = Uses a callback function to capture the prompt from StdOut.
;											   Default: CliPromptCallback(prompt,ID)
;									mode "p" = Prune mode, remove prompt from StdOut data.  Mostly used with
;											   mode "i" / mode "b".  Usually mode "w" won't show the prompt.
;
;		workingDir:c:\myDir		= Working directory.  Defaults to %A_ScriptDir%.  Commands that generate
;								  files will put those files here, unless otherwise specified in the
;								  command parameters.
;
;		codepage:CP0			= Codepage (UTF-8 = CP65001 / Windows Console = CP437 / etc...)
;
;		stdOutCallback:myFunc	= Defines the stdOutCallback function.
;									Default Params: stdOutCallback(data,ID) ... used with any mode.
;
;		stdErrCallback:myFunc	= Defines the stdErrCallback function.
;									Default Params: stdErrCallback(data,ID) ... used with any mode.
;
;	 cliPromptCallback:MyFunc	= Defines the cliPromptCallback function.
;									Default Params: cliPromptCallback(prompt,ID) ... only with mode "b".
;
;		showWindow:#			= Specify 0 or 1 in place of #.  Default = 0 to hide.  1 will show.
;									This is really only useful in mode "m".  Although a callback
;									function will give you much more fleibility.  In any other mode
;									the CLI window will remain blank.
;
;		waitTimeout:300	(ms)	= The waitTimeout is internal, by default this class waits for 300ms
;								  max after sCmd execution, or until there is data in the buffer.
;								  Usually, it doesn't take that long for the buffer to have data
;								  after executing a command, but a slight pause is needed in order
;								  to make using this class more intuitive.
;
;		cmdTimeout:0 (ms)		= By default, cmtTimeout is set to 0, to wait for the command to
;								  complete indefinitely.  This mostly only applies to mode "w".
;								  If you use this class properly, you shouldn't need to use this
;								  value.  But if you find commands just aren't exiting properly,
;								  you can try using this value to force a timeout, but this is
;								  not recommended.  First try other CLI options for the command
;								  you are running, or prepend "cmd /C ..." to run the command from
;								  the CLI prompt, instead of running the console app directly.
; ===================================================================================================
; CLI class Methods and properties
; ===================================================================================================
; If you want more fine-tuned control over the CLI class, you can use these methods:
;
;		myObj.runCmd()			= Runs the command specified in sCmd parameter.  This is meant to be
;								  used with mode "c" when delayed execution is desired.
;
;		myObj.close()			= Closes all open handles and tries to end the session.  Ending
;								  sessions like this usually only succeeds when the CLI prompt
;								  is idle.  If you need to force termination then send a
;								  CTRL+C or CTRL+Break signal.  Read more below.
;
;		myObj.CtrlC()			= Sends a CTRL+C signal to the console.  Usually this cancels
;								  whatever command is running, but it depends on the command.
;								  Launch this with a button, hotkey, timer, or other event.
;
;		myObj.CtrlBreak()		= Sends a CTRL+Break signal to the console.  Usually this will
;								  cancel whatever command is running, but it depends on the command.
;								  Launch this with a button, hotkey, timer, or other event.
;
;		myObj.kill()			= Attempts to run TASKKILL on the process launched by sCmd.
;								  This is only provided as a convenience, and shouldn't be used.
;								  If this CLI class is properly used, then it is easy to terminate
;								  a process by using myObj.CtrlC() or myObj.CtrlBreak(), and then
;								  if necessary finish up with myObj.close()
;
; = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
; = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
; The following options are included as a convenience for power users.  Use with caution.
; Most CLI functionality can be handled without using the below methods / properties directly.
; = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
; = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
;
;		myObj.write(sInpug)		= Write to StdIn and send commands.  CRLF is appended automatically.
;
;		myObj.read(n=0)			= Read N bytes from the buffer
;
;		myObj.AtEOF				= returns 0 if there is data waiting to be read, otherwise 1 if empty
;
;		myObj.Length			= returns the amount of data waiting to be read.
;
;			NOTE: Whatever values you get when using myObj.AtEOF and myObj.Length are only true for
;				  the exact instant you happen to execute them.  Furthermore, just because you read
;				  the buffer, doesn't mean you are done reading it.  You can only read the buffer
;				  4,096 bytes at a time.  Also, just because there doesn't happen to be data in the
;				  buffer now doesn't mean there won't be.
;
;				  Using these methods / properties directly is very tricky.  Please use caution.
;			
; ===================================================================================================
; Please check the example script for practical appliations.
; ===================================================================================================

class cli {
    __New(sCmd, options:="") { ; start with default property init...
		this.StdOutCallback := "stdOutCallback", this.StdErrCallback := "stdErrCallback"
		this.CliPromptCallback := "cliPromptCallback", this.delay := 10
		this.waitTimeout := 300, this.cmdTimeout := 0, this.showWindow := 0
		this.codepage := "CP0", this.workingDir := A_WorkingDir, this.ID := "", this.mode := "w"
		this.output := "", this.error := "", this.cmdHistory := ""
		this.hStdInRd := 0, this.hStdOutWr := 0, this.hStdOutRd := 0, this.hStdInWr := 0, this.hStdErrRd := 0
		this.conWidth := 0, this.conHeight := 0
		
		optGrp := StrSplit(options,"|") ; next load specified properties (options param)
		Loop optGrp.Length {
			curItem := optGrp[A_Index], optItem := StrSplit(curItem,":")
			curOpt := optItem.Has(1) ? optItem[1] : "", curOptValue := optItem.Has(2) ? optItem[2] : ""
			
			If (curOpt = "codepage")
				this.codepage := (curOptValue = "") ? "CP0" : curOptValue
			Else If (curOpt = "workingDir")
				this.workingDir := curOptValue ? curOptValue : A_WorkingDir
			Else If (curOpt = "StdOutCallback")
				this.StdOutCallback := curOptValue ? curOptValue : "StdOutCallback"
			Else If (curOpt = "StdErrCallback")
				this.StdErrCallback := curOptValue ? curOptValue : "StdErrCallback"
			Else If (curOpt = "CliPromptCallback")
				this.CliPromptCallback := curOptValue ? curOptValue : "CliPromptCallback"
			Else If (curOpt = "waitTimeout")
				this.waitTimeout := curOptValue ? curOptValue : 300
			Else If (curOpt = "cmdTimeout")
				this.cmdTimeout := curOptValue ? curOptValue : 0
			Else If (curOpt = "showWindow")
				this.showWindow := curOptValue ? curOptValue : 0
			Else If (curOpt = "delay")
				this.delay := curOptValue ? curOptValue : 10
			Else If (curOpt = "ID")
				this.ID := curOptValue ? curOptValue : ""
			Else if (curOpt = "mode")
				this.mode := curOptValue ? curOptValue : "w"
		}
		
		cmdLines := this.shellCmdLines(sCmd,firstCmd,batchCmd) ; ByRef firstCmd / ByRef batchCmd
		this.firstCmd := firstCmd, this.batchCmd := batchCmd, this.lastCmd := firstCmd	; firstCmd, batchCmd, lastCmd property
		this.stream := ObjBindMethod(this,"sGet") ; register function Obj for timer (stream)
		
		cmdSwitchRegEx := "^cmd(?:\.exe)?[ ]?(((/A|/U|/Q|/D|/E:ON|/E:OFF|/F:ON|/F:OFF|/V:ON|/V:OFF|/S|/C|/K)?[ ]?)*)"
		cmdSwitchResult := RegExMatch(firstCmd,"i)" cmdSwitchRegEx,cmdSwitches), cmdSwitches := Trim(cmdSwitches1)
		cmdCmdRegEx := "^(" comspec "|cmd\.exe|cmd)"
		cmdCmdResult := RegExMatch(firstCmd,"i)" cmdCmdRegEx,cmdCmd), cmdCmd := cmdCmd1
		cmdCmdParams := Trim(StrReplace(StrReplace(firstCmd,cmdCmd,""),cmdSwitches,""))
		this.cmdSwitches := cmdSwitches, this.cmdCmd := cmdCmd, this.cmdCmdParams := cmdCmdParams
		
		If ((cmdCmd And InStr(cmdSwitches,"/K") And InStr(mode,"w")) Or (cmdCmd And !cmdSwitches) And InStr(mode,"w")) {
			MsgBox "Using " Chr(34) "cmd /K" Chr(34) " or plain " Chr(34) "cmd" Chr(34) " with mode " Chr(34) "w" Chr(34) " (the default mode) will cause the script to halt indefinitely."
			return
		}
		
		If (InStr(mode,"c") = 0) ; if not invoking "custom" mode, run command
			this.runCmd()
	}
    __Delete() {
		mode := this.mode
		If (!InStr(mode,"m"))
			this.close() ; close all handles / objects
    }
	runCmd() {
		mode := this.mode
		modeCount := 0, modeCount += InStr(mode,"w")?1:0, modeCount += InStr(mode,"s")?1:0
		modeCount += InStr(mode,"b")?1:0, modeCount += InStr(mode,"m")?1:0
		If (modeCount > 1) { ; check for mode conflicts
			MsgBox "Conflicting modes detected.  Check documentation to properly set modes."
			return
		} Else If (modeCount = 0)
			mode .= "w", this.mode := mode			; imply "w" with no primary modes selected
		If (InStr(mode,"e") And !InStr(mode,"x"))	; imply "x" with "e"
			mode .= "x", this.mode := mode
		If (InStr(mode,"(") And InStr(mode,")") And InStr(mode,"m")) { ; mode "m" !!
			s1 := InStr(mode,"("), e1 := InStr(mode,")"), mParam := SubStr(mode,s1+1,e1-s1-1), dParam := StrSplit(mParam,",")
			conWidth := dParam[1], conHeight := dParam[2], this.conWidth := conWidth, this.conHeight := conHeight
			mMode := dParam[3]?dParam[3]:"/C", this.mMode := mMode
		} Else If (InStr(mode,"m")) {
			this.conWidth := 100, this.conHeight := 10
		}
		
		firstCmd := this.firstCmd, mode := this.mode, stream := this.stream, delay := this.delay
		sDir := this.workingDir, sDirA := (sDir=A_WorkingDir Or !sDir) ? 0 : &sDir, cmdSwitches := this.cmdSwitches
		StdErrCallback := this.StdErrCallback, showWindow := this.showWindow, cmdCmd := this.cmdCmd
		
		If (!InStr(mode,"m")) { ; NOT mode "m"
			DllCall("CreatePipe","Ptr*",hStdInRd:=0,"Ptr*",hStdInWr:=0,"Uint",0,"Uint",0)		; get handle - stdIn (R/W)
			DllCall("CreatePipe","Ptr*",hStdOutRd:=0,"Ptr*",hStdOutWr:=0,"Uint",0,"Uint",0)	; get handle - stdOut (R/W)
			
			DllCall("SetHandleInformation","Ptr",hStdInRd,"Uint",1,"Uint",1)			; set flags inherit - stdIn
			DllCall("SetHandleInformation","Ptr",hStdOutWr,"Uint",1,"Uint",1)			; set flags inherit - stdOut
			If (InStr(mode,"x")) {
				DllCall("CreatePipe","Ptr*",hStdErrRd:=0,"Ptr*",hStdErrWr:=0,"Uint",0,"Uint",0) ; stdErr pipe on mode "x"
				DllCall("SetHandleInformation","Ptr",hStdErrWr,"Uint",1,"Uint",1)
			}
			
			this.hStdInRd := hStdInRd, this.hStdOutWr := hStdOutWr, this.hStdOutRd := hStdOutRd
			this.hStdInWr := hStdInWr, this.hStdErrRd := hStdErrRd
			
			if (A_PtrSize=4) {						; x86
				pi := BufferAlloc(16,0)				; PROCESS_INFORMATION structure
				; VarSetCapacity(pi, 16, 0)			; PROCESS_INFORMATION structure
				si := BufferAlloc(68,0)				; STARTUPINFO Structure
				; sisize:=VarSetCapacity(si,68,0)		; STARTUPINFO Structure
				NumPut "UInt", si.size, si, 0
				NumPut "UInt", 0x101, si, 44		; dwFlags ; 0x100 = inherit handles ; 0x1 = check wShowWindow
				
				; NumPut(si.size, si,  0, "UInt")
				; NumPut(0x101, si, 44, "UInt")		; dwFlags ; 0x100 = inherit handles ; 0x1 = check wShowWindow
				
				If (showWindow)
					NumPut "Int", 0x1, si, 48		; wShowWindow / 0x1 = show
				Else
					NumPut "Int", 0x0, si, 48		; wShowWindow / 0x0 = hide
				
				NumPut "Ptr", hStdInRd, si, 56		; stdIn handle
				NumPut "Ptr", hStdOutWr, si, 60		; stdOut handle
				
				; NumPut(hStdInRd , si, 56, "Ptr")	; stdIn handle
				; NumPut(hStdOutWr, si, 60, "Ptr")	; stdOut handle
				
				If (InStr(mode,"x"))
					NumPut "Ptr", hStdErrWr, si, 64	; direct stdErr to stdOut
				Else
					NumPut "Ptr", hStdOutWr, si, 64	; stdErr handle
			}
			Else If (A_PtrSize = 8) {				; x64
				pi := BufferAlloc(24,0)				; PROCESS_INFORMATION structure
				
				; VarSetCapacity(pi, 24, 0)			; PROCESS_INFORMATION structure
				
				si := BufferAlloc(104,0)
				
				; sisize:=VarSetCapacity(si,104,0)	; STARTUPINFO Structure
				
				NumPut "UInt", si.size, si, 0
				NumPut "UInt", 0x101, si, 60		; dwFlags ; 0x100 = inherit handles ; 0x1 = check wShowWindow
				
				; NumPut(sisize, si,  0, "UInt")
				; NumPut(0x101, si, 60, "UInt")		; dwFlags ; 0x100 = inherit handles ; 0x1 = check wShowWindow
				
				If (showWindow)
					NumPut "Int", 0x1, si, 64		; wShowWindow / 0x1 = show
					; NumPut(0x1, si, 64, "Int")		; wShowWindow / 0x1 = show
				Else
					NumPut "Int", 0x0, si, 64		; wShowWindow / 0x0 = hide
					; NumPut(0x0, si, 64, "Int")		; wShowWindow / 0x0 = hide
				
				NumPut "Ptr", hStdInRd, si, 80		; stdIn write handle
				NumPut "Ptr", hStdOutWr, si, 88		; stdOut write handle
				
				; NumPut(hStdInRd , si, 80, "Ptr")	; stdIn handle
				; NumPut(hStdOutWr, si, 88, "Ptr")	; stdOut handle
				
				If (InStr(mode,"x"))
					NumPut "Ptr", hStdErrWr, si, 96	; direct stdErr to stdOut
				Else
					NumPut "Ptr", hStdOutWr, si, 96	; stdErr handle
			}
			
			this.shell := "windows"
			s := "^((.*[ ])?adb (-a |-d |-e |-s [a-zA-Z0-9]*|-t [0-9]+|-H |-P |-L [a-z0-9:_]*)?[ ]?shell)$"
			If (RegExMatch(firstCmd,s))
				this.shell := "android"
			
			r := DllCall("CreateProcess"
				, "Uint", 0					; application name
				, "Ptr", &firstCmd			; command line str ; this should be a buffer obj <------------------------------------ ***
				, "Uint", 0					; process attributes
				, "Uint", 0					; thread attributes
				, "Int", True			 	; inherit handles - defined in si
				, "Uint", 0x00000010		; dwCreationFlags ; 0x00000010 = CREATE_NEW_CONSOLE
				, "Uint", 0					; environment
				, "Ptr", sDirA				; working Directory pointer
				, "Ptr", si.ptr				; startup info structure - contains stdIn/Out handles
				, "Ptr", pi.ptr)			; process info sttructure - contains proc/thread handles/IDs
			
			if (r) {
				pid := NumGet(pi, A_PtrSize*2, "uint")
				hProc := NumGet(pi,0), hThread := NumGet(pi,A_PtrSize)
				this.pid := pid, this.hProc := hProc, this.hThread := hThread
				If (InStr(mode,"m")) {
					atch := DllCall("AttachConsole","UInt",pid)
					hStdOutRd := DllCall("GetStdHandle", "int", -11, "ptr"), this.hStdOutRd := hStdOutRd
				}
				DllCall("CloseHandle","Ptr",hStdInRd)					; stdIn  read  handle not needed
				DllCall("CloseHandle","Ptr",hStdOutWr)					; stdOut write handle not needed
				
				this.fStdOutRd := FileOpen(hStdOutRd, "h", this.codepage)	; open StdOut file Obj
				If (InStr(mode,"x")) {
					DllCall("CloseHandle","Ptr",hStdErrWr)
					this.fStdErrRd := FileOpen(hStdErrRd, "h", this.codepage)
				}
				
				If (this.shell = "android") ; specific CLI shell fixes
					this.uWrite(this.checkShell())
				
				this.wait()				; wait for buffer to have data
				If (InStr(mode,"w")) {
					this.wGet()			; (wGet) wait mode
				} Else If (InStr(mode,"s") Or InStr(mode,"b"))
					SetTimer stream, delay		; data collection timer / default delay = 10ms
			} Else {
				if (this.output)
					this.output .= "`r`nINVALID COMMAND"
				Else
					this.output := "INVALID COMMAND"
				this.close()
			}
			If (this.cmdCmd And InStr(this.cmdSwitches,"/C") And !this.cmdCmdParams) { ; check if cmd /C with no params sent
				if (this.output)
					this.output .= "`r`nNo command sent?"
				Else
					this.output := "No command sent?"
			}
		} Else { ; mode "m" !! ; set buffer to width=200 / height=2 ... minimum 2 lines, or icky things happen
			; next line didn't work so well...
			; cmd := "cmd.exe " mMode " " chr(34) "MODE CON:COLS=" conWidth " LINES=" conHeight Chr(34) " & " firstCmd
			
			; this line worked better to launch mode "m"
			cmd := "cmd.exe " mMode " MODE CON: COLS=" conWidth " LINES=" conHeight " & " firstCmd
			runOpt := this.showWindow ? "" : "hide"
			Run cmd,,runOpt,pid
			this.pid := pid
			
			while !(result := DllCall("AttachConsole", "uint", pid)) ; retry attach console until success
				Sleep 10
			
			hwnd := DllCall("GetStdHandle", "int", -11, "ptr"), this.hStdOutRd := hwnd ; get stdOut/console handle
			SetTimer stream, delay
		}
	}
	close() { ; closes handles and may/may not kill process instance
		mode := this.mode, stream := this.stream, pid := this.pid
		If (InStr(mode,"m")) {
			SetTimer stream, 0
			DllCall("FreeConsole")
			ProcessClose pid		; if ErrorLevel = pid then close was successful, else PID never existed.
		} Else {
			StdErrCallback := this.StdErrCallback, hStdInWr := this.hStdInWr, hStdOutRd:=this.hStdOutRd, hStdErrRd := this.hStdErrRd
			hProc:=this.hProc, hThread:=this.hThread
			DllCall("CloseHandle","Ptr",hStdInWr), DllCall("CloseHandle","Ptr",hStdOutRd)	; close stdIn/stdOut handle
			DllCall("CloseHandle","Ptr",hProc), DllCall("CloseHandle","Ptr",hThread)		; close process/thread handle
			this.fStdOutRd.Close()															; close fileObj stdout handle
			If (InStr(mode,"x"))
				DllCall("CloseHandle","Ptr",hStdErrRd), this.fStdErrRd.Close() ; close stdErr handles
		}
	}
	wait() {
		mode := this.mode, delay := this.delay, waitTimeout := this.waitTimeout, ticks := A_TickCount
		Loop {												; wait for Stdout buffer to have content
			Sleep delay ; default delay = 10 ms
			curPid := ProcessExist(this.pid)						; check if process exited prematurely
			If (this.fStdOutRd.AtEOF = 0 Or !curPid)	; break when there's data or process terminates
				Break
			Else If (InStr(mode,"x") And this.fStdErrRd.AtEOF = 0)
				Break
			Else If (A_TickCount - ticks >= waitTimeout)	; default waitTimeout = 300 ms
				Break
		}
	}
	wGet() { ; wait-Get - pauses script until process exists AND buffer is empty
		ID := this.ID, delay := this.delay, mode := this.mode, cmdTimeout := this.cmdTimeout, ticks := A_TickCount
		StdOutCallback := this.StdOutCallback, StdErrCallback := this.StdErrCallback
		
		Loop {
			Sleep delay									; reduce CPU usage (default delay = 10ms)
			buffer := this.fStdOutRd.read()					; check buffer
			If (buffer) {
				If (InStr(mode,"p")) {
					lastLine := this.shellLastLine(buffer)	; looks for end of data and/or shell change
					If (lastLine)
						buffer := RegExReplace(buffer,"\Q" lastLine "\E$","")
				}
				If (InStr(mode,"o") And IsFunc(StdOutCallback)) {
					%StdOutCallback%(buffer,ID)				; run callback function
				} Else
					this.output .= buffer					; collect data in this.output
			}
			
			If (InStr(mode,"x")) {							; if "x" mode, check stdErr
				stdErr := this.fStdErrRd.read()
				If (stdErr) {
					If (InStr(mode,"e") And IsFunc(StdErrCallback))
						%StdErrCallback%(stdErr,ID)
					Else
						this.error .= stdErr
				}
			}
			
			curPid := ProcessExist(this.pid)
			If (!curPid And this.fStdOutRd.AtEOF) ; process exits AND buffer is empty
				Break
			Else If (this.fStdOutRd.AtEOF And A_TickCount - ticks >= cmdTimeout And cmdTimeout > 0)
				Break
		}
	}
	sGet() { ; stream-Get (timer) - collects until process exits AND buffer is empty
		ID := this.ID, mode := this.mode, batchCmd := this.batchCmd, stream := this.stream ; stream (timer)
		StdOutCallback := this.StdOutCallback, StdErrCallback := this.StdErrCallback
		CliPromptCallback := this.CliPromptCallback, pid := this.pid, hStdOutRd := this.hStdOutRd
		
		If (!InStr(mode,"m")) {
			buffer := this.fStdOutRd.read()						; check buffer
			If (buffer) {
				lastLine := this.shellLastLine(buffer)			; looks for end of data and/or shell change
				If (lastLine and InStr(mode,"p"))
					buffer := this.removePrompt(buffer)
					; buffer := RegExReplace(buffer,"\Q" lastLine "\E$","")
				
				If (InStr(mode,"o") And IsFunc(StdOutCallback))
					%StdOutCallback%(buffer,ID)					; run callback function, or...
				Else
					this.output .= buffer						; collect data in this.output
			}
			If (lastLine And InStr(mode,"i") And IsFunc(CliPromptCallback))
				%CliPromptCallback%(lastLine,ID)	; run callback when prompt is ready
			
			If (InStr(mode,"x")) {
				stdErr := this.fStdErrRd.read()
				If (stdErr) {
					stdErr := Trim(stdErr,OmitChars:=" \t\r\n")
					If (InStr(mode,"e") And IsFunc(StdErrCallback))
						%StdErrCallback%(stdErr,ID)
					Else
						this.error .= stdErr "`r`n`r`n"
				}
			}
			
			fullEOF := this.fStdOutRd.AtEOF
			if (InStr(mode,"x")) {
				If (this.fStdOutRd.AtEOF And this.fStdErrRd.AtEOF)
					fullEOF := true
				Else
					fullEOF := false
			}
			
			curPid := ProcessExist(this.pid)					; check if process still exists
			If (!curPid And fullEOF)				; if process exits AND buffer is empty
				SetTimer stream, 0					; stop data collection timer
			
			If (InStr(mode,"b")) {
				If (lastLine And fullEOF) {					; process should be idle when prompt appears
					If (batchCmd)
						this.write(batchCmd)				; write next command in bach, if any
					Else {
						SetTimer stream, 0
						this.close()
						If (InStr(mode,"o") And IsFunc(StdOutCallback))
							%StdOutCallback%("`r`n__Batch Finished__",ID)
					}
				}
			}
		} Else { ; mode "m" !!
			conHeight := this.conHeight, conWidth := this.conWidth
			curPid := ProcessExist(pid)
			If (curPid)
				this.mCountdown := 10
			Else
				this.mCountdown -= 1
			If (this.mCountdown) {
				lpCharacter := BufferAlloc(conWidth*conHeight*2,0)
				dwBufferCoord := BufferAlloc(4,0)
				
				; VarSetCapacity(lpCharacter,conWidth*conHeight*2,0) ; console buffer size to collect
				; VarSetCapacity(dwBufferCoord,4,0)
				
				result := DllCall("ReadConsoleOutputCharacter"
								,"UInt",hStdOutRd ; console buffer handle
								; ,"Str",lpCharacter:="" ; str buffer
								,"Ptr",lpCharacter.ptr ; str buffer
								,"UInt",conWidth * conHeight ; define console dimensions
								,"uint",Numget(dwBufferCoord,"uint") ; start point >> 0,0
								,"UInt*",lpNumberOfCharsRead:=0,"Int")
				; size := VarSetCapacity(lpCharacter,-1)
				size := lpCharacter.size
				str := ""
				Loop size/2 {
					crlf := (Mod(A_Index,conWidth)=0) ? "`r`n" : ""
					str .= Chr(NumGet(lpCharacter,(A_Index-1)*2,"UChar"))
					If (StrLen(crlf))
						str := Trim(str) crlf
				}
				str := Trim(str,OmitChars:=" `t`r`n")
				
				lastLine := this.shellLastLine(str)
				If (lastLine and InStr(mode,"p"))
					str := this.removePrompt(str)
				
				If (!InStr(mode,"o"))
					this.output := str
				Else If (IsFunc(StdOutCallback))
					%StdOutCallback%(str,ID)
				
				If (lastLine) {
					If (batchCmd)
						this.write(batchCmd)
					Else {
						SetTimer stream, 0
						this.close()
						If (InStr(mode,"o") And IsFunc(StdOutCallback))
							%StdOutCallback%("`r`n__Batch Finished__",ID)
					}
				}
			} Else {
				this.close()
				SetTimer stream, 0
			}
		}
	}
	write(sInput:="") {
		sInput := Trim(sInput,OmitChars:="`r`n")
		If (sInput = "")
			Return
		
		mode := this.mode, ID := this.ID, delay := this.delay, stream := this.stream, pid := this.pid
		cmdLines := this.shellCmdLines(sInput,firstCmd,batchCmd) ; ByRef firstCmd / ByRef batchCmd
		this.batchCmd := batchCmd, this.lastCmd := firstCmd, this.cmdHistory .= firstCmd "`r`n"
		
		androidRegEx := "^((.*[ ])?adb (-a |-d |-e |-s [a-zA-Z0-9]*|-t [0-9]+|-H |-P |-L [a-z0-9:_]*)?[ ]?shell)$"
		If (RegExMatch(firstCmd,androidRegEx)) ; check shell change on-the-fly
			this.shell := "android"
		
		If (InStr(mode,"m")) {
			DetectHiddenWindows 1
			ControlSend "", sInput "`r`n", "ahk_pid " pid		; this might not work so well
			DetectHiddenWindows 0
		}
		Else
			f := FileOpen(this.hStdInWr, "h", this.codepage), f.Write(firstCmd "`r`n"), f.Close(), f := "" ; send cmd
		
		If (this.shell = "android") ; check shell
			this.uWrite(this.checkShell()) ; ADB - appends missing prompt after data complete
	}
	uWrite(sInput:="") {
		sInput := Trim(sInput,OmitChars:="`r`n")
		If (sInput != "")
            f := FileOpen(this.hStdInWr, "h", this.codepage), f.Write(sInput "`r`n"), f.close(), f := ""
	}
	read(chars:="") {
		if (this.fStdOutRd.AtEOF=0)
			return chars=""?this.fStdOutRd.Read():this.fStdOutRd.Read(chars)
	}
	ctrlBreak() {
		If (InStr(this.mode,"m")) {
			stream := this.stream
			DllCall("FreeConsole")					; CTRL+Break and CTRL+C will not work without:
			SetTimer stream, 0						; dwCreationFlags : 0x00000010 = CREATE_NEW_CONSOLE
		}											; STARTUPINFO: dwFlags: 
		pid := this.pid								; 		0x100 = inherit handles, and...
		DetectHiddenWindows 1						; 		0x1   = check wShowWindow, and...
		ControlSend "^{CtrlBreak}",, "ahk_pid " pid	; STARTUPINFO: wShowWindow: 0x0 = hide or 0x1 = show
		DetectHiddenWindows 0
		If (InStr(this.mode,"m"))					; Window must exist for CTRL signals to work
			result := this.ReattachConsole()		; Original creation flag 0x08000000 (no window) overrides ...
	}												; ... dwFlags, thus CTRL signals won't work.
	ctrlC() {
		If (InStr(this.mode,"m")) {
			stream := this.stream
			DllCall("FreeConsole")
			SetTimer stream, 0
		}
		pid := this.pid
		DetectHiddenWindows 1
		ControlSend "^c",, "ahk_pid " pid
		DetectHiddenWindows 0
		If (InStr(this.mode,"m"))
			result := this.ReattachConsole()
	}
	KeySequence(sInput) {
		If (InStr(this.mode,"m")) {			; assume custom sequence is a CTRL signal ...
			stream := this.stream			; ... therefore detach console first, or script will exit.
			DllCall("FreeConsole")
			SetTimer stream, 0
		}
		pid := this.pid
		DetectHiddenWindows 1
		ControlSend sInput,, "ahk_pid " pid
		DetectHiddenWindows 0
		If (InStr(this.mode,"m"))
			result := this.ReattachConsole()
	}
	DetachConsole() {
		DllCall("FreeConsole")
	}
	ReattachConsole() {
		pid := this.pid, delay := this.delay, stream := this.stream
		curPid := ProcessExist(pid)
		If (curPid) {
			while !(result := DllCall("AttachConsole", "uint", pid)) ; retry attach console until success
				Sleep 10
			
			hwnd := DllCall("GetStdHandle", "int", -11, "ptr"), this.hStdOutRd := hwnd ; get stdOut/console handle
			SetTimer stream, delay
			
			return "success" ; process exists and was reattached
		} else
			Return "fail" ; process no longer exists
	}
	kill() {	; not as important now that ctrlBreak() works, but still handy
		pid := this.pid
		Run comspec " /C TASKKILL /F /T /PID " pid,,"hide"
		this.close()
	}
	shellLastLine(str) { ; catching windows prompt, or "end of data" string
		If (!str)
			return ""
		winRegEx := "[\r\n]*([A-Z]\:\\[^/?<>:*|" Chr(34) "]*>)$" ; orig: "[\n]?([A-Z]\:\\[^/?<>:*|``]*>)$"
		netshRegEx := "[\r\n]*(netsh[ a-z0-9]*\>)$"
		telnetRegEx := "[\r\n]*(\QMicrosoft Telnet>\E)$"
		androidRegEx := "[\r\n]*([\-_a-zA-Z0-9]*\:[^\r\n]* \>)$"
		
		If (RegExMatch(str,netshRegEx,match)) {
			this.shell := "netsh"
			result := match.Count() ? match.Value(1) : ""
		} Else If (RegExMatch(str,telnetRegEx,match)) {
			this.shell := "telnet"
			result := match.Count() ? match.Value(1) : ""
		} Else If (RegExMatch(str,winRegEx,match)) {
			this.shell := "windows"
			result := match.Count() ? match.Value(1) : ""
		} Else If (RegExMatch(str,androidRegEx,match)) {
			this.shell := "android"
			result := match.Count() ? match.Value(1) : ""
		} Else
			result := ""
		
		return result
	}
	removePrompt(str) {
		str := RegExReplace(str,"(\r\n|\r|\n)?\Q" lastLine "\E$","")
		oneMore := this.shellLastLine(str)
		While (oneMore) {
			str := RegExReplace(str,"(\r\n|\r|\n)?\Q" oneMore "\E$","")
			oneMore := this.shellLastLine(str)
		}
		return str
	}
	checkShell() {
		If (this.shell = "android")
			return "echo " Chr(34) "$HOSTNAME:$PWD >" Chr(34)
		Else
			return ""
	}
	shellCmdLines(str, ByRef firstCmd, ByRef batchCmd) {
		firstCmd := "", batchCmd := "", str := Trim(str,OmitChars:=" `t`r`n"), i := 0
		Loop Parse str, "`n", "`r"
		{
			If (A_LoopField != "") {
				i++
				If (A_Index = 1)
					firstCmd := A_LoopField
				Else
					batchCmd .= A_LoopField "`r`n"
			}
		}
		return i
	}
	AtEOF() {
		return this.fStdOutRd.AtEOF
	}
	Length() {
		return this.fStdOutRd.Length
	}
}
