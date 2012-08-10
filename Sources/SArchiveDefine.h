/*
 *  SArchiveDefine.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright © 2012 Jean-Daniel Dupas. All rights reserved.
 */

#if !defined(__SARCHIVE_DEFINE_H__)
#define __SARCHIVE_DEFINE_H__ 1

// MARK: Clang Macros
#ifndef __has_builtin
  #define __has_builtin(x) __has_builtin ## x
#endif

#ifndef __has_attribute
  #define __has_attribute(x) __has_attribute ## x
#endif

#ifndef __has_feature
  #define __has_feature(x) __has_feature ## x
#endif

#ifndef __has_extension
  #define __has_extension(x) __has_feature(x)
#endif

#ifndef __has_include
  #define __has_include(x) 0
#endif

#ifndef __has_include_next
  #define __has_include_next(x) 0
#endif

#ifndef __has_warning
  #define __has_warning(x) 0
#endif

// MARK: Visibility
#if defined(_WIN32)
  #define SARCHIVE_HIDDEN

  #if defined(SARCHIVE_STATIC_LIBRARY)
      #define SARCHIVE_VISIBLE
  #else
    #if defined(SARCHIVEKIT_DLL_EXPORT)
      #define SARCHIVE_VISIBLE __declspec(dllexport)
    #else
      #define SARCHIVE_VISIBLE __declspec(dllimport)
    #endif
  #endif
#endif

#if !defined(SARCHIVE_VISIBLE)
  #define SARCHIVE_VISIBLE __attribute__((__visibility__("default")))
#endif

#if !defined(SARCHIVE_HIDDEN)
  #define SARCHIVE_HIDDEN __attribute__((__visibility__("hidden")))
#endif

#if !defined(SARCHIVE_EXTERN)
  #if defined(__cplusplus)
    #define SARCHIVE_EXTERN extern "C"
  #else
    #define SARCHIVE_EXTERN extern
  #endif
#endif

/* SARCHIVE_EXPORT SARCHIVE_PRIVATE should be used on
 extern variables and functions declarations */
#if !defined(SARCHIVE_EXPORT)
  #define SARCHIVE_EXPORT SARCHIVE_EXTERN SARCHIVE_VISIBLE
#endif

#if !defined(SARCHIVE_PRIVATE)
  #define SARCHIVE_PRIVATE SARCHIVE_EXTERN SARCHIVE_HIDDEN
#endif

// MARK: Inline
#if defined(__cplusplus) && !defined(__inline__)
  #define __inline__ inline
#endif

#if !defined(SARCHIVE_INLINE)
  #if !defined(__NO_INLINE__)
    #if defined(_MSC_VER)
      #define SARCHIVE_INLINE __forceinline static
    #else
      #define SARCHIVE_INLINE __inline__ __attribute__((__always_inline__)) static
    #endif
  #else
    #define SARCHIVE_INLINE __inline__ static
  #endif /* No inline */
#endif

// MARK: Attributes
#if !defined(SARCHIVE_NORETURN)
  #if defined(_MSC_VER)
    #define SARCHIVE_NORETURN __declspec(noreturn)
  #else
    #define SARCHIVE_NORETURN __attribute__((__noreturn__))
  #endif
#endif

#if !defined(SARCHIVE_DEPRECATED)
  #if defined(_MSC_VER)
    #define SARCHIVE_DEPRECATED(msg) __declspec(deprecated(msg))
  #elif defined(__clang__)
    #define SARCHIVE_DEPRECATED(msg) __attribute__((__deprecated__(msg)))
  #else
    #define SARCHIVE_DEPRECATED(msg) __attribute__((__deprecated__))
  #endif
#endif

#if !defined(SARCHIVE_UNUSED)
  #if defined(_MSC_VER)
    #define SARCHIVE_UNUSED
  #else
    #define SARCHIVE_UNUSED __attribute__((__unused__))
  #endif
#endif

#if !defined(SARCHIVE_REQUIRES_NIL_TERMINATION)
  #if defined(_MSC_VER)
    #define SARCHIVE_REQUIRES_NIL_TERMINATION
  #elif defined(__APPLE_CC__) && (__APPLE_CC__ >= 5549)
    #define SARCHIVE_REQUIRES_NIL_TERMINATION __attribute__((__sentinel__(0,1)))
  #else
    #define SARCHIVE_REQUIRES_NIL_TERMINATION __attribute__((__sentinel__))
  #endif
#endif

#if !defined(SARCHIVE_REQUIRED_ARGS)
  #if defined(_MSC_VER)
    #define SARCHIVE_REQUIRED_ARGS(idx, ...)
  #else
    #define SARCHIVE_REQUIRED_ARGS(idx, ...) __attribute__((__nonnull__(idx, ##__VA_ARGS__)))
  #endif
#endif

#if !defined(SARCHIVE_FORMAT)
  #if defined(_MSC_VER)
    #define SARCHIVE_FORMAT(fmtarg, firstvararg)
  #else
    #define SARCHIVE_FORMAT(fmtarg, firstvararg) __attribute__((__format__ (__printf__, fmtarg, firstvararg)))
  #endif
#endif

#if !defined(SARCHIVE_CF_FORMAT)
  #if defined(__clang__)
    #define SARCHIVE_CF_FORMAT(i, j) __attribute__((__format__(__CFString__, i, j)))
  #else
    #define SARCHIVE_CF_FORMAT(i, j)
  #endif
#endif

#if !defined(SARCHIVE_NS_FORMAT)
  #if defined(__clang__)
    #define SARCHIVE_NS_FORMAT(i, j) __attribute__((__format__(__NSString__, i, j)))
  #else
    #define SARCHIVE_NS_FORMAT(i, j)
  #endif
#endif

// MARK: -
// MARK: Static Analyzer
#ifndef CF_CONSUMED
  #if __has_attribute(__cf_consumed__)
    #define CF_CONSUMED __attribute__((__cf_consumed__))
  #else
    #define CF_CONSUMED
  #endif
#endif

#ifndef CF_RETURNS_RETAINED
  #if __has_attribute(__cf_returns_retained__)
    #define CF_RETURNS_RETAINED __attribute__((__cf_returns_retained__))
  #else
    #define CF_RETURNS_RETAINED
  #endif
#endif

#ifndef CF_RETURNS_NOT_RETAINED
	#if __has_attribute(__cf_returns_not_retained__)
		#define CF_RETURNS_NOT_RETAINED __attribute__((__cf_returns_not_retained__))
	#else
		#define CF_RETURNS_NOT_RETAINED
	#endif
#endif


#if defined(__OBJC__)

/* SARCHIVE_OBJC_EXPORT and SARCHIVE_OBJC_PRIVATE can be used
 to define ObjC classes visibility. */
#if !defined(SARCHIVE_OBJC_PRIVATE)
  #if __LP64__
    #define SARCHIVE_OBJC_PRIVATE SARCHIVE_HIDDEN
  #else
    #define SARCHIVE_OBJC_PRIVATE
  #endif /* 64 bits runtime */
#endif

#if !defined(SARCHIVE_OBJC_EXPORT)
  #if __LP64__
    #define SARCHIVE_OBJC_EXPORT SARCHIVE_VISIBLE
  #else
    #define SARCHIVE_OBJC_EXPORT
  #endif /* 64 bits runtime */
#endif

// MARK: Static Analyzer
#ifndef SARCHIVE_UNUSED_IVAR
  #if __has_extension(__attribute_objc_ivar_unused__)
    #define SARCHIVE_UNUSED_IVAR __attribute__((__unused__))
  #else
    #define SARCHIVE_UNUSED_IVAR
  #endif
#endif

#ifndef NS_CONSUMED
  #if __has_attribute(__ns_consumed__)
    #define NS_CONSUMED __attribute__((__ns_consumed__))
  #else
    #define NS_CONSUMED
  #endif
#endif

#ifndef NS_CONSUMES_SELF
  #if __has_attribute(__ns_consumes_self__)
    #define NS_CONSUMES_SELF __attribute__((__ns_consumes_self__))
  #else
    #define NS_CONSUMES_SELF
  #endif
#endif

#ifndef NS_RETURNS_RETAINED
  #if __has_attribute(__ns_returns_retained__)
    #define NS_RETURNS_RETAINED __attribute__((__ns_returns_retained__))
  #else
    #define NS_RETURNS_RETAINED
  #endif
#endif

#ifndef NS_RETURNS_NOT_RETAINED
  #if __has_attribute(__ns_returns_not_retained__)
    #define NS_RETURNS_NOT_RETAINED __attribute__((__ns_returns_not_retained__))
  #else
    #define NS_RETURNS_NOT_RETAINED
  #endif
#endif

#ifndef NS_RETURNS_AUTORELEASED
  #if __has_attribute(__ns_returns_autoreleased__)
    #define NS_RETURNS_AUTORELEASED __attribute__((__ns_returns_autoreleased__))
  #else
    #define NS_RETURNS_AUTORELEASED
  #endif
#endif

/* Method Family */
#ifndef NS_METHOD_FAMILY
  /* supported families are: none, alloc, copy, init, mutableCopy, and new. */
  #if __has_attribute(__ns_returns_autoreleased__)
    #define NS_METHOD_FAMILY(family) __attribute__((objc_method_family(family)))
  #else
    #define NS_METHOD_FAMILY(arg)
  #endif
#endif

// gracefully degrade
#if !__has_feature(__objc_instancetype__)
  #define instancetype id
#endif

#endif /* ObjC */


#endif /* __SARCHIVE_DEFINE_H__ */
