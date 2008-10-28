#ifndef _INCLUDES_H
#define _INCLUDES_H
/* 
   Unix SMB/CIFS implementation.
   Machine customisation and include handling
   Copyright (C) Andrew Tridgell 1994-1998
   Copyright (C) 2002 by Martin Pool <mbp@samba.org>
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#ifndef NO_CONFIG_H /* for some tests */
#include "config.h"
#endif

#ifndef __cplusplus
#define class #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
/* allow to build with newer heimdal releases */
/* #define private #error DONT_USE_CPLUSPLUS_RESERVED_NAMES */
#define public #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
#define protected #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
#define template #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
#define this #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
#define new #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
#define delete #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
#define friend #error DONT_USE_CPLUSPLUS_RESERVED_NAMES
#endif

//#include "local.h"

#ifdef AIX
#define DEFAULT_PRINTING PRINT_AIX
#define PRINTCAP_NAME "/etc/qconfig"
#endif

#ifdef HPUX
#define DEFAULT_PRINTING PRINT_HPUX
#endif

#ifdef QNX
#define DEFAULT_PRINTING PRINT_QNX
#endif

#ifdef SUNOS4
/* on SUNOS4 termios.h conflicts with sys/ioctl.h */
#undef HAVE_TERMIOS_H
#endif

#if (__GNUC__ >= 3 ) && (__GNUC_MINOR__ >= 1 )
/** Use gcc attribute to check printf fns.  a1 is the 1-based index of
 * the parameter containing the format, and a2 the index of the first
 * argument. Note that some gcc 2.x versions don't handle this
 * properly **/
#define PRINTF_ATTRIBUTE(a1, a2) __attribute__ ((format (__printf__, a1, a2)))
#else
#define PRINTF_ATTRIBUTE(a1, a2)
#endif

#if defined(__GNUC__) && !defined(__cplusplus)
/** gcc attribute used on function parameters so that it does not emit
 * warnings about them being unused. **/
#  define UNUSED(param) param __attribute__ ((unused))
#else
#  define UNUSED(param) param
/** Feel free to add definitions for other compilers here. */
#endif

#ifdef RELIANTUNIX
/*
 * <unistd.h> has to be included before any other to get
 * large file support on Reliant UNIX. Yes, it's broken :-).
 */
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#endif /* RELIANTUNIX */

#include <sys/types.h>

#ifdef TIME_WITH_SYS_TIME
#include <sys/time.h>
#include <time.h>
#else
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#else
#include <time.h>
#endif
#endif

#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <stdio.h>
#include <stddef.h>

#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_SYS_SOCKET_H
#include <sys/socket.h>
#endif

#ifdef HAVE_UNIXSOCKET
#include <sys/un.h>
#endif

#ifdef HAVE_SYS_SYSCALL_H
#include <sys/syscall.h>
#elif HAVE_SYSCALL_H
#include <syscall.h>
#endif

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif

#ifdef HAVE_MEMORY_H
#include <memory.h>
#endif

#ifdef HAVE_MALLOC_H
#include <malloc.h>
#endif

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#else
#ifdef HAVE_SYS_FCNTL_H
#include <sys/fcntl.h>
#endif
#endif

#include <sys/stat.h>

#ifdef HAVE_LIMITS_H
#include <limits.h>
#endif

#ifdef HAVE_SYS_IOCTL_H
#include <sys/ioctl.h>
#endif

#ifdef HAVE_SYS_FILIO_H
#include <sys/filio.h>
#endif

#include <signal.h>

#ifdef HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif
#ifdef HAVE_CTYPE_H
#include <ctype.h>
#endif
#ifdef HAVE_GRP_H
#include <grp.h>
#endif
#ifdef HAVE_SYS_PRIV_H
#include <sys/priv.h>
#endif
#ifdef HAVE_SYS_ID_H
#include <sys/id.h>
#endif

#include <errno.h>

#ifdef HAVE_UTIME_H
#include <utime.h>
#endif

#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

#ifdef HAVE_SYS_MODE_H
/* apparently AIX needs this for S_ISLNK */
#ifndef S_ISLNK
#include <sys/mode.h>
#endif
#endif

#ifdef HAVE_GLOB_H
#include <glob.h>
#endif

#include <pwd.h>

#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#ifdef HAVE_SYSLOG_H
#include <syslog.h>
#else
#ifdef HAVE_SYS_SYSLOG_H
#include <sys/syslog.h>
#endif
#endif

#include <sys/file.h>

#ifdef HAVE_NETINET_TCP_H
#include <netinet/tcp.h>
#endif

/*
 * The next three defines are needed to access the IPTOS_* options
 * on some systems.
 */

#ifdef HAVE_NETINET_IN_SYSTM_H
#include <netinet/in_systm.h>
#endif

#ifdef HAVE_NETINET_IN_IP_H
#include <netinet/in_ip.h>
#endif

#ifdef HAVE_NETINET_IP_H
#include <netinet/ip.h>
#endif

#if defined(HAVE_TERMIOS_H)
/* POSIX terminal handling. */
#include <termios.h>
#elif defined(HAVE_TERMIO_H)
/* Older SYSV terminal handling - don't use if we can avoid it. */
#include <termio.h>
#elif defined(HAVE_SYS_TERMIO_H)
/* Older SYSV terminal handling - don't use if we can avoid it. */
#include <sys/termio.h>
#endif

#if HAVE_DIRENT_H
# include <dirent.h>
# define NAMLEN(dirent) strlen((dirent)->d_name)
#else
# define dirent direct
# define NAMLEN(dirent) (dirent)->d_namlen
# if HAVE_SYS_NDIR_H
#  include <sys/ndir.h>
# endif
# if HAVE_SYS_DIR_H
#  include <sys/dir.h>
# endif
# if HAVE_NDIR_H
#  include <ndir.h>
# endif
#endif

#ifdef HAVE_SYS_MMAN_H
#include <sys/mman.h>
#endif

#ifdef HAVE_NET_IF_H
#include <net/if.h>
#endif


#ifdef HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif

#ifdef HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif

#ifdef HAVE_SYS_ACL_H
#include <sys/acl.h>
#endif

#ifdef HAVE_SYS_FS_S5PARAM_H 
#include <sys/fs/s5param.h>
#endif

#if defined (HAVE_SYS_FILSYS_H) && !defined (_CRAY)
#include <sys/filsys.h> 
#endif

#ifdef HAVE_SYS_STATFS_H
# include <sys/statfs.h>
#endif

#ifdef HAVE_DUSTAT_H              
#include <sys/dustat.h>
#endif

#ifdef HAVE_SYS_STATVFS_H          
#include <sys/statvfs.h>
#endif

#ifdef HAVE_SHADOW_H
/*
 * HP-UX 11.X has TCP_NODELAY and TCP_MAXSEG defined in <netinet/tcp.h> which
 * was included above.  However <rpc/rpc.h> includes <sys/xti.h> which defines
 * them again without checking if they already exsist.  This generates
 * two "Redefinition of macro" warnings for every single .c file that is
 * compiled.
 */
#if defined(HPUX) && defined(TCP_NODELAY)
#undef TCP_NODELAY
#endif
#if defined(HPUX) && defined(TCP_MAXSEG)
#undef TCP_MAXSEG
#endif
#include <shadow.h>
#endif

#ifdef HAVE_GETPWANAM
#include <sys/label.h>
#include <sys/audit.h>
#include <pwdadj.h>
#endif

#ifdef HAVE_SYS_SECURITY_H
#include <sys/security.h>
#include <prot.h>
#define PASSWORD_LENGTH 16
#endif  /* HAVE_SYS_SECURITY_H */

#ifdef HAVE_STROPTS_H
#include <stropts.h>
#endif

#ifdef HAVE_POLL_H
#include <poll.h>
#endif

#ifdef HAVE_EXECINFO_H
#include <execinfo.h>
#endif

#ifdef HAVE_SYS_CAPABILITY_H

#if defined(BROKEN_REDHAT_7_SYSTEM_HEADERS) && !defined(_I386_STATFS_H) && !defined(_PPC_STATFS_H)
#define _I386_STATFS_H
#define _PPC_STATFS_H
#define BROKEN_REDHAT_7_STATFS_WORKAROUND
#endif

#include <sys/capability.h>

#ifdef BROKEN_REDHAT_7_STATFS_WORKAROUND
#undef _I386_STATFS_H
#undef _PPC_STATFS_H
#undef BROKEN_REDHAT_7_STATFS_WORKAROUND
#endif

#endif

#if defined(HAVE_RPC_RPC_H)
/*
 * Check for AUTH_ERROR define conflict with rpc/rpc.h in prot.h.
 */
#if defined(HAVE_SYS_SECURITY_H) && defined(HAVE_RPC_AUTH_ERROR_CONFLICT)
#undef AUTH_ERROR
#endif
/*
 * HP-UX 11.X has TCP_NODELAY and TCP_MAXSEG defined in <netinet/tcp.h> which
 * was included above.  However <rpc/rpc.h> includes <sys/xti.h> which defines
 * them again without checking if they already exsist.  This generates
 * two "Redefinition of macro" warnings for every single .c file that is
 * compiled.
 */
#if defined(HPUX) && defined(TCP_NODELAY)
#undef TCP_NODELAY
#endif
#if defined(HPUX) && defined(TCP_MAXSEG)
#undef TCP_MAXSEG
#endif
#include <rpc/rpc.h>
#endif

#if defined(HAVE_YP_GET_DEFAULT_DOMAIN) && defined(HAVE_SETNETGRENT) && defined(HAVE_ENDNETGRENT) && defined(HAVE_GETNETGRENT)
#define HAVE_NETGROUP 1
#endif

#if defined (HAVE_NETGROUP)
#if defined(HAVE_RPCSVC_YP_PROT_H)
/*
 * HP-UX 11.X has TCP_NODELAY and TCP_MAXSEG defined in <netinet/tcp.h> which
 * was included above.  However <rpc/rpc.h> includes <sys/xti.h> which defines
 * them again without checking if they already exsist.  This generates
 * two "Redefinition of macro" warnings for every single .c file that is
 * compiled.
 */
#if defined(HPUX) && defined(TCP_NODELAY)
#undef TCP_NODELAY
#endif
#if defined(HPUX) && defined(TCP_MAXSEG)
#undef TCP_MAXSEG
#endif
#include <rpcsvc/yp_prot.h>
#endif
#if defined(HAVE_RPCSVC_YPCLNT_H)
#include <rpcsvc/ypclnt.h>
#endif
#endif /* HAVE_NETGROUP */

#if defined(HAVE_SYS_IPC_H)
#include <sys/ipc.h>
#endif /* HAVE_SYS_IPC_H */

#if defined(HAVE_SYS_SHM_H)
#include <sys/shm.h>
#endif /* HAVE_SYS_SHM_H */

#ifdef HAVE_NATIVE_ICONV
#ifdef HAVE_ICONV
#include <iconv.h>
#endif
#ifdef HAVE_GICONV
#include <giconv.h>
#endif
#ifdef HAVE_BICONV
#include <biconv.h>
#endif
#endif

#if HAVE_KRB5_H
#include <krb5.h>
#else
#undef HAVE_KRB5
#endif

#if HAVE_LBER_H
#include <lber.h>
#ifndef LBER_USE_DER
#define LBER_USE_DER 0x01
#endif
#endif

#if HAVE_LDAP_H
#include <ldap.h>
#ifndef LDAP_CONST
#define LDAP_CONST const
#endif
#ifndef LDAP_OPT_SUCCESS
#define LDAP_OPT_SUCCESS 0
#endif
#else
#undef HAVE_LDAP
#endif

#if HAVE_GSSAPI_H
#include <gssapi.h>
#elif HAVE_GSSAPI_GSSAPI_H
#include <gssapi/gssapi.h>
#elif HAVE_GSSAPI_GSSAPI_GENERIC_H
#include <gssapi/gssapi_generic.h>
#endif

#if HAVE_COM_ERR_H
#include <com_err.h>
#endif

#if HAVE_SYS_ATTRIBUTES_H
#include <sys/attributes.h>
#endif

/* mutually exclusive (SuSE 8.2) */
#if HAVE_ATTR_XATTR_H
#include <attr/xattr.h>
#elif HAVE_SYS_XATTR_H
#include <sys/xattr.h>
#endif

#ifdef HAVE_SYS_EXTATTR_H
#include <sys/extattr.h>
#endif

#ifdef HAVE_SYS_UIO_H
#include <sys/uio.h>
#endif

#if HAVE_LOCALE_H
#include <locale.h>
#endif

#if HAVE_LANGINFO_H
#include <langinfo.h>
#endif

#if defined(HAVE_AIO_H) && defined(WITH_AIO)
#include <aio.h>
#endif

/* skip valgrind headers on 64bit AMD boxes */
#ifndef HAVE_64BIT_LINUX
/* Special macros that are no-ops except when run under Valgrind on
 * x86.  They've moved a little bit from valgrind 1.0.4 to 1.9.4 */
#if HAVE_VALGRIND_MEMCHECK_H
        /* memcheck.h includes valgrind.h */
#include <valgrind/memcheck.h>
#elif HAVE_VALGRIND_H
#include <valgrind.h>
#endif
#endif

/* If we have --enable-developer and the valgrind header is present,
 * then we're OK to use it.  Set a macro so this logic can be done only
 * once. */
#if defined(DEVELOPER) && !defined(HAVE_64BIT_LINUX)
#if (HAVE_VALGRIND_H || HAVE_VALGRIND_VALGRIND_H)
#define VALGRIND
#endif
#endif


/* we support ADS if we want it and have krb5 and ldap libs */
#if defined(WITH_ADS) && defined(HAVE_KRB5) && defined(HAVE_LDAP)
#define HAVE_ADS
#endif

/*
 * Define VOLATILE if needed.
 */

#if defined(HAVE_VOLATILE)
#define VOLATILE volatile
#else
#define VOLATILE
#endif

#ifndef uchar
#define uchar unsigned char
#endif

#ifdef HAVE_UNSIGNED_CHAR
#define schar signed char
#else
#define schar char
#endif

/*
   Samba needs type definitions for int16, int32, uint16 and uint32.

   Normally these are signed and unsigned 16 and 32 bit integers, but
   they actually only need to be at least 16 and 32 bits
   respectively. Thus if your word size is 8 bytes just defining them
   as signed and unsigned int will work.
*/

#ifndef uint8
#define uint8 unsigned char
#endif

#if !defined(int16) && !defined(HAVE_INT16_FROM_RPC_RPC_H)
#if (SIZEOF_SHORT == 4)
#define int16 __ERROR___CANNOT_DETERMINE_TYPE_FOR_INT16;
#else /* SIZEOF_SHORT != 4 */
#define int16 short
#endif /* SIZEOF_SHORT != 4 */
#endif

/*
 * Note we duplicate the size tests in the unsigned 
 * case as int16 may be a typedef from rpc/rpc.h
 */

#if !defined(uint16) && !defined(HAVE_UINT16_FROM_RPC_RPC_H)
#if (SIZEOF_SHORT == 4)
#define uint16 __ERROR___CANNOT_DETERMINE_TYPE_FOR_INT16;
#else /* SIZEOF_SHORT != 4 */
#define uint16 unsigned short
#endif /* SIZEOF_SHORT != 4 */
#endif

#if !defined(int32) && !defined(HAVE_INT32_FROM_RPC_RPC_H)
#if (SIZEOF_INT == 4)
#define int32 int
#elif (SIZEOF_LONG == 4)
#define int32 long
#elif (SIZEOF_SHORT == 4)
#define int32 short
#else
/* uggh - no 32 bit type?? probably a CRAY. just hope this works ... */
#define int32 int
#endif
#endif

/*
 * Note we duplicate the size tests in the unsigned 
 * case as int32 may be a typedef from rpc/rpc.h
 */

#if !defined(uint32) && !defined(HAVE_UINT32_FROM_RPC_RPC_H)
#if (SIZEOF_INT == 4)
#define uint32 unsigned int
#elif (SIZEOF_LONG == 4)
#define uint32 unsigned long
#elif (SIZEOF_SHORT == 4)
#define uint32 unsigned short
#else
/* uggh - no 32 bit type?? probably a CRAY. just hope this works ... */
#define uint32 unsigned
#endif
#endif

/*
 * Types for devices, inodes and offsets.
 */

#ifndef SMB_DEV_T
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_DEV64_T)
#    define SMB_DEV_T dev64_t
#  else
#    define SMB_DEV_T dev_t
#  endif
#endif

#ifndef LARGE_SMB_DEV_T
#  if (defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_DEV64_T)) || (defined(SIZEOF_DEV_T) && (SIZEOF_DEV_T == 8))
#    define LARGE_SMB_DEV_T 1
#  endif
#endif

#ifdef LARGE_SMB_DEV_T
#define SDEV_T_VAL(p, ofs, v) (SIVAL((p),(ofs),(v)&0xFFFFFFFF), SIVAL((p),(ofs)+4,(v)>>32))
#define DEV_T_VAL(p, ofs) ((SMB_DEV_T)(((SMB_BIG_UINT)(IVAL((p),(ofs))))| (((SMB_BIG_UINT)(IVAL((p),(ofs)+4))) << 32)))
#else 
#define SDEV_T_VAL(p, ofs, v) (SIVAL((p),(ofs),v),SIVAL((p),(ofs)+4,0))
#define DEV_T_VAL(p, ofs) ((SMB_DEV_T)(IVAL((p),(ofs))))
#endif

/*
 * Setup the correctly sized inode type.
 */

#ifndef SMB_INO_T
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_INO64_T)
#    define SMB_INO_T ino64_t
#  else
#    define SMB_INO_T ino_t
#  endif
#endif

#ifndef LARGE_SMB_INO_T
#  if (defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_INO64_T)) || (defined(SIZEOF_INO_T) && (SIZEOF_INO_T == 8))
#    define LARGE_SMB_INO_T 1
#  endif
#endif

#ifdef LARGE_SMB_INO_T
#define SINO_T_VAL(p, ofs, v) (SIVAL((p),(ofs),(v)&0xFFFFFFFF), SIVAL((p),(ofs)+4,(v)>>32))
#define INO_T_VAL(p, ofs) ((SMB_INO_T)(((SMB_BIG_UINT)(IVAL(p,ofs)))| (((SMB_BIG_UINT)(IVAL(p,(ofs)+4))) << 32)))
#else 
#define SINO_T_VAL(p, ofs, v) (SIVAL(p,ofs,v),SIVAL(p,(ofs)+4,0))
#define INO_T_VAL(p, ofs) ((SMB_INO_T)(IVAL((p),(ofs))))
#endif

#ifndef SMB_OFF_T
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_OFF64_T)
#    define SMB_OFF_T off64_t
#  else
#    define SMB_OFF_T off_t
#  endif
#endif

#if defined(HAVE_LONGLONG)
#define SMB_BIG_UINT unsigned long long
#define SMB_BIG_INT long long
#define SBIG_UINT(p, ofs, v) (SIVAL(p,ofs,(v)&0xFFFFFFFF), SIVAL(p,(ofs)+4,(v)>>32))
#else
#define SMB_BIG_UINT unsigned long
#define SMB_BIG_INT long
#define SBIG_UINT(p, ofs, v) (SIVAL(p,ofs,v),SIVAL(p,(ofs)+4,0))
#endif

#define SMB_BIG_UINT_BITS (sizeof(SMB_BIG_UINT)*8)

/* this should really be a 64 bit type if possible */
#define br_off SMB_BIG_UINT

#define SMB_OFF_T_BITS (sizeof(SMB_OFF_T)*8)

/*
 * Set the define that tells us if we can do 64 bit
 * NT SMB calls.
 */

#ifndef LARGE_SMB_OFF_T
#  if (defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_OFF64_T)) || (defined(SIZEOF_OFF_T) && (SIZEOF_OFF_T == 8))
#    define LARGE_SMB_OFF_T 1
#  endif
#endif

#ifdef LARGE_SMB_OFF_T
#define SOFF_T(p, ofs, v) (SIVAL(p,ofs,(v)&0xFFFFFFFF), SIVAL(p,(ofs)+4,(v)>>32))
#define SOFF_T_R(p, ofs, v) (SIVAL(p,(ofs)+4,(v)&0xFFFFFFFF), SIVAL(p,ofs,(v)>>32))
#define IVAL_TO_SMB_OFF_T(buf,off) ((SMB_OFF_T)(( ((SMB_BIG_UINT)(IVAL((buf),(off)))) & ((SMB_BIG_UINT)0xFFFFFFFF) )))
#define IVAL2_TO_SMB_BIG_UINT(buf,off) ( (((SMB_BIG_UINT)(IVAL((buf),(off)))) & ((SMB_BIG_UINT)0xFFFFFFFF)) | \
		(( ((SMB_BIG_UINT)(IVAL((buf),(off+4)))) & ((SMB_BIG_UINT)0xFFFFFFFF) ) << 32 ) )
#else 
#define SOFF_T(p, ofs, v) (SIVAL(p,ofs,v),SIVAL(p,(ofs)+4,0))
#define SOFF_T_R(p, ofs, v) (SIVAL(p,(ofs)+4,v),SIVAL(p,ofs,0))
#define IVAL_TO_SMB_OFF_T(buf,off) ((SMB_OFF_T)(( ((uint32)(IVAL((buf),(off)))) & 0xFFFFFFFF )))
#define IVAL2_TO_SMB_BIG_UINT(buf,off) ( (((SMB_BIG_UINT)(IVAL((buf),(off)))) & ((SMB_BIG_UINT)0xFFFFFFFF)) | \
		                (( ((SMB_BIG_UINT)(IVAL((buf),(off+4)))) & ((SMB_BIG_UINT)0xFFFFFFFF) ) << 32 ) )
#endif

/*
 * Type for stat structure.
 */

#ifndef SMB_STRUCT_STAT
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_STAT64) && defined(HAVE_OFF64_T)
#    define SMB_STRUCT_STAT struct stat64
#  else
#    define SMB_STRUCT_STAT struct stat
#  endif
#endif

/*
 * Type for dirent structure.
 */

#ifndef SMB_STRUCT_DIRENT
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_STRUCT_DIRENT64)
#    define SMB_STRUCT_DIRENT struct dirent64
#  else
#    define SMB_STRUCT_DIRENT struct dirent
#  endif
#endif

/*
 * Type for DIR structure.
 */

#ifndef SMB_STRUCT_DIR
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_STRUCT_DIR64)
#    define SMB_STRUCT_DIR DIR64
#  else
#    define SMB_STRUCT_DIR DIR
#  endif
#endif

/*
 * Defines for 64 bit fcntl locks.
 */

#ifndef SMB_STRUCT_FLOCK
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_STRUCT_FLOCK64) && defined(HAVE_OFF64_T)
#    define SMB_STRUCT_FLOCK struct flock64
#  else
#    define SMB_STRUCT_FLOCK struct flock
#  endif
#endif

#ifndef SMB_F_SETLKW
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_STRUCT_FLOCK64) && defined(HAVE_OFF64_T)
#    define SMB_F_SETLKW F_SETLKW64
#  else
#    define SMB_F_SETLKW F_SETLKW
#  endif
#endif

#ifndef SMB_F_SETLK
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_STRUCT_FLOCK64) && defined(HAVE_OFF64_T)
#    define SMB_F_SETLK F_SETLK64
#  else
#    define SMB_F_SETLK F_SETLK
#  endif
#endif

#ifndef SMB_F_GETLK
#  if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_STRUCT_FLOCK64) && defined(HAVE_OFF64_T)
#    define SMB_F_GETLK F_GETLK64
#  else
#    define SMB_F_GETLK F_GETLK
#  endif
#endif

/*
 * Type for aiocb structure.
 */

#ifndef SMB_STRUCT_AIOCB
#  if defined(WITH_AIO)
#    if defined(HAVE_EXPLICIT_LARGEFILE_SUPPORT) && defined(HAVE_AIOCB64)
#      define SMB_STRUCT_AIOCB struct aiocb64
#    else
#      define SMB_STRUCT_AIOCB struct aiocb
#    endif
#  else
#    define SMB_STRUCT_AIOCB int /* AIO not being used but we still need the define.... */
#  endif
#endif

#ifndef MIN
#define MIN(a,b) ((a)<(b)?(a):(b))
#endif

#ifndef MAX
#define MAX(a,b) ((a)>(b)?(a):(b))
#endif

/* Our own pstrings and fstrings */
#include "pstring.h"

#include "tdb.h"
#include "spinlock.h"
#include "tdbutil.h"

#endif /* _INCLUDES_H */
