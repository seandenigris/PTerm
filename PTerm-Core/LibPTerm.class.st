Class {
	#name : #LibPTerm,
	#superclass : #FFILibrary,
	#classInstVars : [
		'instance'
	],
	#category : #'PTerm-Core'
}

{ #category : #'C-constants' }
LibPTerm class >> F_GETFL [
	^3
]

{ #category : #'C-constants' }
LibPTerm class >> F_SETFL [
	^4
]

{ #category : #'C-constants' }
LibPTerm class >> O_NONBLOCK [
	Smalltalk os isMacOS ifTrue: [ ^4 ].
	^4000
]

{ #category : #'C-constants' }
LibPTerm class >> O_RDWR [
	^2
]

{ #category : #'C-constants' }
LibPTerm class >> SIGKILL [
	^ 9
]

{ #category : #'C-constants' }
LibPTerm class >> ST_WINSIZE [
	^8
]

{ #category : #'C-constants' }
LibPTerm class >> TIOCGWINSZ [
	Smalltalk os isMacOS ifTrue: [ ^1074295912 ].
	^21523
]

{ #category : #'C-constants' }
LibPTerm class >> TIOCSWINSZ [
	Smalltalk os isMacOS ifTrue: [ ^2148037735 ].
	^21524
]

{ #category : #lib }
LibPTerm class >> closept: fd [
	^ self ffiCall: #(int close(int fd)) module: LibC
]

{ #category : #compilation }
LibPTerm class >> compile [
	|cmd arch st fp libfile ofile|
	fp := self mksource.
	ofile := fp parent / 'libpterm.o'.
	libfile := fp parent / 'libpterm.flib'.
	arch := Smalltalk vm wordSize = 8 ifTrue: [ '-m64' ] ifFalse: [ '-m32' ].
	cmd := 'gcc -c -fpic ', arch, ' "', fp pathString, '" -o "', ofile pathString, '"'.
	Transcript show: 'Building: ', cmd; cr.
	st := LibC system: cmd.
	st = 0 ifFalse: [ ^self error:'LibC Cannot create object file' ].
	cmd := 'gcc -shared ', arch, ' -o "',libfile pathString,'" "', ofile pathString, '"'.
	Transcript show: 'Building: ', cmd; cr.
	st := LibC system: cmd. 
	st = 0 ifFalse: [ ^self error:'LibC Cannot create shared file' ].
	fp exists ifTrue:[ fp delete ].
	ofile asFileReference delete
]

{ #category : #'instance creation' }
LibPTerm class >> exec: command [
	^ LibC uniqueInstance system: command
]

{ #category : #'accessing platform' }
LibPTerm class >> ffiLibraryName [
	^ (FileLocator imageDirectory / 'libpterm.flib') pathString
]

{ #category : #lib }
LibPTerm class >> fileActionAddDup: pointer fd: fd newFd: fd2 [ 
	^self ffiCall: #(int posix_spawn_file_actions_adddup2( void* pointer, int fd, int fd2)) module: LibC.
]

{ #category : #lib }
LibPTerm class >> fileActionAddOpen: pointer fd: fd fileName: name flag: flag mode: mode [ 
	^self ffiCall: #(int posix_spawn_file_actions_addopen( void* pointer, int fd, char* name, int flag, int mode )) module: LibC.
]

{ #category : #lib }
LibPTerm class >> fileActionInit: pointer [
	^self ffiCall: #(int posix_spawn_file_actions_init( void* pointer )) module: LibC.
]

{ #category : #lib }
LibPTerm class >> fileActionSettingFor: fname [
	|st ptr|
	ptr := ExternalAddress allocate: self sizeOfFileAction.
	st := self fileActionInit: ptr.
	st = 0 ifFalse:[^ self error:'Error posix_spawn_file_actions_init'].
	st := self fileActionAddOpen: ptr fd: 0  fileName: fname flag: self O_RDWR mode: 0644. 
	st = 0 ifFalse: [ ^ self error:'Error posix_spawn_file_actions_open' ].
	"st := self fileActionAddDup: ptr fd: 0  newFd: 0.
	st = 0 ifFalse: [ ^self error: 'Error posix_spawn_file_action_dup2' ]."
	st := self fileActionAddDup: ptr fd: 0  newFd: 1.
	st = 0 ifFalse: [ ^self error: 'Error posix_spawn_file_action_dup2' ].
	st := self fileActionAddDup: ptr fd: 0  newFd: 2.
	st = 0 ifFalse: [ ^self error: 'Error posix_spawn_file_action_dup2' ].
	^ ptr
]

{ #category : #lib }
LibPTerm class >> fnctl: fd action: action flag: flag [
 	^ self ffiCall: #(int fcntl(int fd, int action, int flag)) module: LibC 
]

{ #category : #writing }
LibPTerm class >> getReadWriteBufferOf: size [
	^(FFIExternalArray externalNewType: 'char' size: size) getHandle
]

{ #category : #lib }
LibPTerm class >> grantpt: fd [
	^ self ffiCall: #(int grantpt(int fd)) module: LibC
]

{ #category : #lib }
LibPTerm class >> ioct: fd cmd: cmd arg: arg [
	^ self ffiCall: #(int ioctl(int fd, ulong cmd, void* arg)) module: LibC
]

{ #category : #accessing }
LibPTerm class >> kill: pid signal: sig [
	^ self ffiCall: #(int kill(int pid, int sig)) module: LibC
]

{ #category : #accessing }
LibPTerm class >> master [
	|fd st|
	fd := self openpt: (self O_RDWR bitOr: self O_NONBLOCK).
	fd < 0 ifTrue:[^self error:'Error on on posix_openpt()'].
	st := self grantpt: fd.
	st ~= 0 ifTrue: [ self closept: fd. ^ self error: 'Error on grantpt()' ].
	st := self unlockpt: fd.
	st ~= 0 ifTrue: [ self closept: fd. ^ self error: 'Error on unlockpt()' ].
	^fd
	
]

{ #category : #compilation }
LibPTerm class >> mksource [
	|file|
	file := FileLocator imageDirectory / 'libpterm.c'.
	file exists ifTrue:[ file delete ].
	file writeStreamDo: [ :str | str nextPutAll: self source ].
	^file
]

{ #category : #lib }
LibPTerm class >> open: name mode: flag [
	^ self ffiCall: #(int open(char* name, int flag)) module: LibC
]

{ #category : #lib }
LibPTerm class >> openpt: flag [
	^ self ffiCall: #(int posix_openpt(int flag)) module: LibC
]

{ #category : #lib }
LibPTerm class >> posixSpawn:pid  process: cmd fileAction: ptr fileAttr:fattr argv: args env: envs [
	^ self ffiCall:#( int posix_spawnp(int* pid, char* cmd, void* ptr, void* fattr, void* args, void* envs ))  module: LibC  
]

{ #category : #lib }
LibPTerm class >> print: text [
	^ self ffiCall: #(void printf(char* text)) module: LibC
]

{ #category : #lib }
LibPTerm class >> ptsname: fd [
	^ self ffiCall: #(char* ptsname(int fd)) module: LibC
]

{ #category : #lib }
LibPTerm class >> read: fd buffer: buff size: size [
	^self ffiCall: #(int read(int fd, char* buff, int size)) module: LibC 
]

{ #category : #initialization }
LibPTerm class >> setNonBlocking: fd [
	|flag st|
	flag := self fnctl: fd action: self F_GETFL flag:0.
	flag := flag bitOr: self O_NONBLOCK.
	st := self fnctl: fd action: self F_SETFL flag: flag.
	st = 0 ifFalse:[^self error: 'Cannot set nonblocking'].
	^st
]

{ #category : #'C-constants' }
LibPTerm class >> sizeOfFileAction [
	"we fix it to 80 for now"
	^80
]

{ #category : #compilation }
LibPTerm class >> source [
	^ '
#define _GNU_SOURCE 
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <string.h>
pid_t pterm_spawn_tty(int master, char** args, char** envs)
{
    // get file name
    char* fname = ptsname(master);
    int fds = open(fname, O_RDWR);
    pid_t pid = fork();
    if(pid == 0)
    {
        // child
        close(master);
        close(0);
        close(1);
        close(2);
        dup(fds);
        dup(fds);
        dup(fds);
        close(fds);
        setsid();
        ioctl(0, TIOCSCTTY, 1);
        execve(args[0], &args[0], envs);
        // when we have problem
        exit(1);
    }
    return pid;
}
int tty_set_winsize(int fdm, int rows, int cols)
{ 
	struct winsize win = {0, 0, 0, 0};
	if (ioctl(fdm, TIOCGWINSZ, &win) != 0)
	{
		if (errno != EINVAL)
		{
			return -1;
		}
		memset(&win, 0, sizeof(win));
	}
	if (rows >= 0)
		win.ws_row = rows;
	if (cols >= 0)
		win.ws_col = cols;

	if (ioctl(fdm, TIOCSWINSZ, (char *)&win) != 0)
		return -1;
	return 0;
}
'
]

{ #category : #lib }
LibPTerm class >> stringArrayOf: anArray [
	|xarray|
	anArray  ifNil: [ ^nil ].
	xarray := FFIExternalArray externalNewType: 'char*' size: anArray size + 1. 
	anArray withIndexDo: [ :v :i| xarray at:i put: (ExternalAddress fromString: v) ]. 
	xarray at:anArray size + 1 put: (ExternalAddress  fromAddress: 0).
	^ xarray 
]

{ #category : #lib }
LibPTerm class >> ttySpawn: fd argv: argv envs:envs [
	[ ^ self xspawn: fd argv: argv  envs: envs ] on: Error do: [ 
		"try tho compile it"
		self compile.
		^self xspawn: fd argv: argv  envs: envs
	] 
]

{ #category : #lib }
LibPTerm class >> ttyWinSize: fd rows:rows cols:cols [
	^ self ffiCall: #(int tty_set_winsize(int fd, int rows, int cols)) 
]

{ #category : #lib }
LibPTerm class >> unlockpt: fd [
	^ self ffiCall: #(int unlockpt(int fd)) module: LibC
]

{ #category : #lib }
LibPTerm class >> waitpid: pid status: buf noHang: v [
	^ self ffiCall: #(int waitpid(int pid, int * buf, int v)) module: LibC
]

{ #category : #writing }
LibPTerm class >> write: fd buffer: buff size: size [
	^self ffiCall: #(int write(int fd, char* buff, int size)) module: LibC 
]

{ #category : #lib }
LibPTerm class >> xspawn: fd argv: argv envs:envs [
	^ self ffiCall: #(int pterm_spawn_tty(int fd, void* argv, void* envs)) 
]
